
#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>
@import CoreLocation; 
@import ImageIO;

#import "SimpleCameraPreview.h"

@implementation SimpleCameraPreview

BOOL torchActivated = false;

- (void) setOptions:(CDVInvokedUrlCommand*)command {
    NSDictionary* config = command.arguments[0];
    @try {
        if (config[@"targetSize"] != [NSNull null] && ![config[@"targetSize"] isEqual: @"null"]) {
            NSInteger targetSize = ((NSNumber*)config[@"targetSize"]).intValue;
            AVCaptureSessionPreset calculatedPreset = [CameraSessionManager calculateResolution:targetSize];
            NSArray *calculatedPresetArray = [[[NSString stringWithFormat: @"%@", calculatedPreset] stringByReplacingOccurrencesOfString:@"AVCaptureSessionPreset" withString:@""] componentsSeparatedByString:@"x"];
            float height = [calculatedPresetArray[0] floatValue];
            float width = [calculatedPresetArray[1] floatValue];
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[NSString stringWithFormat:@"%f", (height / width)]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    } @catch(NSException *exception) {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"targetSize not well defined"] callbackId:command.callbackId];
    }
}

- (void) enable:(CDVInvokedUrlCommand*)command {
    self.onCameraEnabledHandlerId = command.callbackId;
    CDVPluginResult *pluginResult;
    if (self.sessionManager != nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera already started!"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionNotInterrupted:) name:AVCaptureSessionInterruptionEndedNotification object:nil];

    // start as transparent
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor clearColor];
    
    //required to get gps exif
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    locationManager.pausesLocationUpdatesAutomatically = NO;
    [locationManager requestWhenInUseAuthorization];
    
    // Create the session manager
    self.sessionManager = [[CameraSessionManager alloc] init];
    
    // render controller setup
    self.cameraRenderController = [[CameraRenderController alloc] init];
    self.cameraRenderController.sessionManager = self.sessionManager;
    [self _setSize:command];
    [self.viewController addChildViewController:self.cameraRenderController];
    [self.webView.superview insertSubview:self.cameraRenderController.view atIndex:0];
    self.viewController.view.backgroundColor = [UIColor blackColor];
    
    // Setup session
    self.sessionManager.delegate = self.cameraRenderController;
    
    NSMutableDictionary *setupSessionOptions = [NSMutableDictionary dictionary];
    if (command.arguments.count > 0) {
        NSDictionary* config = command.arguments[0];
        @try {
            if (config[@"targetSize"] != [NSNull null] && ![config[@"targetSize"] isEqual: @"null"]) {
                NSInteger targetSize = ((NSNumber*)config[@"targetSize"]).intValue;
                [setupSessionOptions setValue:[NSNumber numberWithInteger:targetSize] forKey:@"targetSize"];
            }
            NSString *captureDevice = config[@"captureDevice"];
            if (captureDevice && [captureDevice length] > 0) {
                [setupSessionOptions setValue:captureDevice forKey:@"captureDevice"];
            }
        } @catch(NSException *exception) {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"targetSize not well defined"] callbackId:command.callbackId];
        }
    }
    
    self.photoSettings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey : AVVideoCodecTypeJPEG}];    [self.sessionManager setupSession:@"back" completion:^(BOOL started) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
            [pluginResult setKeepCallbackAsBool:true];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        });
    } options:setupSessionOptions photoSettings:self.photoSettings];
}

- (void) sessionNotInterrupted:(NSNotification *)notification {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not interrupted"];
    [pluginResult setKeepCallbackAsBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onCameraEnabledHandlerId];
}

- (void) sessionInterrupted:(NSNotification *)notification {
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session interrupted"];
    [pluginResult setKeepCallbackAsBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onCameraEnabledHandlerId];
}

- (void) disable:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate runInBackground:^{
        if(self.sessionManager != nil) {
            for(AVCaptureInput *input in self.sessionManager.session.inputs) {
                [self.sessionManager.session removeInput:input];
            }
            for(AVCaptureOutput *output in self.sessionManager.session.outputs) {
                [self.sessionManager.session removeOutput:output];
            }
            [self.sessionManager.session stopRunning];
            self.sessionManager = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
              [self.cameraRenderController.view removeFromSuperview];
              if(self.viewController.parentViewController != nil) {
                  [self.cameraRenderController removeFromParentViewController];
              }
              self.cameraRenderController = nil;
              [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
            });
        }
        else {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"] callbackId:command.callbackId];
        }
    }];
}

-(void) setSize:(CDVInvokedUrlCommand*)command {
    [self _setSize:command];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)_setSize:(CDVInvokedUrlCommand*)command {
    NSDictionary* config = command.arguments[0];
    float x = ((NSNumber*)config[@"x"]).floatValue;
    float y = ((NSNumber*)config[@"y"]).floatValue + self.webView.frame.origin.y;
    float width = ((NSNumber*)config[@"width"]).floatValue;
    float height = ((NSNumber*)config[@"height"]).floatValue;
    self.cameraRenderController.view.frame = CGRectMake(x, y, width, height);
}

- (void) torchSwitch:(CDVInvokedUrlCommand*)command{
    BOOL torchState = [[command.arguments objectAtIndex:0] boolValue];
    if (self.sessionManager != nil) {
        torchActivated = torchState;
        [self.sessionManager torchSwitch:torchState? 1 : 0];
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) switchCameraTo:(CDVInvokedUrlCommand*)command{
    NSString *device = [command.arguments objectAtIndex:0];
    BOOL cameraSwitched = FALSE;
    if (self.sessionManager != nil) {
        [self.sessionManager switchCameraTo: device completion:^(BOOL success) {
            if (success) {
                NSLog(@"Camera switched successfully");
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:TRUE];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                NSLog(@"Failed to switch camera");
                CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:FALSE];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        }];
    }
}

- (void) deviceHasUltraWideCamera:(CDVInvokedUrlCommand *)command{
    BOOL hasUltraWideCamera = NO;
    if (self.sessionManager != nil) {
        hasUltraWideCamera = [self.sessionManager deviceHasUltraWideCamera];
    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:hasUltraWideCamera];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) deviceHasFlash:(CDVInvokedUrlCommand*)command{
    AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                          mediaType:AVMediaTypeVideo
                                           position:AVCaptureDevicePositionBack];
    NSArray *captureDevices = [captureDeviceDiscoverySession devices];
    BOOL hasTorch = NO;
    
    for (AVCaptureDevice *device in captureDevices) {
        if ([device hasTorch]) {
            hasTorch = YES;
            break;
        }
    }
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:hasTorch];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) capture:(CDVInvokedUrlCommand*)command {
    BOOL useFlash = [[command.arguments objectAtIndex:0] boolValue];
    if (torchActivated)
        useFlash = false;
    self.photoSettings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey : AVVideoCodecTypeJPEG}];
    if (self.sessionManager != nil)
        [self.sessionManager setFlashMode:useFlash? AVCaptureFlashModeOn: AVCaptureFlashModeOff photoSettings:self.photoSettings];

    CDVPluginResult *pluginResult;
    if (self.cameraRenderController != NULL) {
        self.onPictureTakenHandlerId = command.callbackId;
        [self.sessionManager.imageOutput capturePhotoWithSettings:self.photoSettings delegate:self];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (NSDictionary *)getGPSDictionaryForLocation {
    if (!currentLocation)
        return nil;
    CLLocation *location = currentLocation;
    NSMutableDictionary *gps = [NSMutableDictionary dictionary];
    
    // GPS tag version
    [gps setObject:@"2.2.0.0" forKey:(NSString *)kCGImagePropertyGPSVersion];
    
    // Time and date must be provided as strings, not as an NSDate object
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSSSSS"];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    [gps setObject:[formatter stringFromDate:location.timestamp] forKey:(NSString *)kCGImagePropertyGPSTimeStamp];
    [formatter setDateFormat:@"yyyy:MM:dd"];
    [gps setObject:[formatter stringFromDate:location.timestamp] forKey:(NSString *)kCGImagePropertyGPSDateStamp];
    
    // Latitude
    CGFloat latitude = location.coordinate.latitude;
    if (latitude < 0) {
        latitude = -latitude;
        [gps setObject:@"S" forKey:(NSString *)kCGImagePropertyGPSLatitudeRef];
    } else {
        [gps setObject:@"N" forKey:(NSString *)kCGImagePropertyGPSLatitudeRef];
    }
    [gps setObject:[NSNumber numberWithFloat:latitude] forKey:(NSString *)kCGImagePropertyGPSLatitude];
    
    // Longitude
    CGFloat longitude = location.coordinate.longitude;
    if (longitude < 0) {
        longitude = -longitude;
        [gps setObject:@"W" forKey:(NSString *)kCGImagePropertyGPSLongitudeRef];
    } else {
        [gps setObject:@"E" forKey:(NSString *)kCGImagePropertyGPSLongitudeRef];
    }
    [gps setObject:[NSNumber numberWithFloat:longitude] forKey:(NSString *)kCGImagePropertyGPSLongitude];
    
    // Altitude
    CGFloat altitude = location.altitude;
    if (!isnan(altitude)){
        if (altitude < 0) {
            altitude = -altitude;
            [gps setObject:@"1" forKey:(NSString *)kCGImagePropertyGPSAltitudeRef];
        } else {
            [gps setObject:@"0" forKey:(NSString *)kCGImagePropertyGPSAltitudeRef];
        }
        [gps setObject:[NSNumber numberWithFloat:altitude] forKey:(NSString *)kCGImagePropertyGPSAltitude];
    }
    
    // Speed, must be converted from m/s to km/h
    if (location.speed >= 0){
        [gps setObject:@"K" forKey:(NSString *)kCGImagePropertyGPSSpeedRef];
        [gps setObject:[NSNumber numberWithFloat:location.speed*3.6] forKey:(NSString *)kCGImagePropertyGPSSpeed];
    }
    
    // Heading
    if (location.course >= 0){
        [gps setObject:@"T" forKey:(NSString *)kCGImagePropertyGPSTrackRef];
        [gps setObject:[NSNumber numberWithFloat:location.course] forKey:(NSString *)kCGImagePropertyGPSTrack];
    }
    
    return gps;
}

-(void)captureOutput:(AVCapturePhotoOutput *)captureOutput didFinishProcessingPhoto:(nonnull AVCapturePhoto *)photo error:(nullable NSError *)error {
    if (error) {
        NSLog(@"%@", error);
        NSString* errorDescription =  error.description ? error.description : @"";
        errorDescription = [@"Error taking picture: " stringByAppendingString:errorDescription];
        CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errorDescription];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
        return;
    }
    [self runBlockWithTryCatch:^{
        NSData *imageData = [photo fileDataRepresentation];
        CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
        CFDictionaryRef metaDict = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
        CFMutableDictionaryRef mutableDict = CFDictionaryCreateMutableCopy(NULL, 0, metaDict);
        NSDictionary * gpsData = [self getGPSDictionaryForLocation];
        if (gpsData)
            CFDictionarySetValue(mutableDict, kCGImagePropertyGPSDictionary, (__bridge CFDictionaryRef)gpsData);
        CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *libraryDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"NoCloud"];
        NSString* uniqueFileName = [NSString stringWithFormat:@"%@.jpg",[[NSUUID UUID] UUIDString]];
        NSString *dataPath = [@"file://" stringByAppendingString: [libraryDirectory stringByAppendingPathComponent:uniqueFileName]];
        CFStringRef UTI = CGImageSourceGetType(source);
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)  [NSURL URLWithString:dataPath], UTI, 1, NULL);
        CGImageDestinationAddImageFromSource(destination, source, 0, mutableDict);
        CGImageDestinationFinalize(destination);
        CFRelease(source);
        CFRelease(destination);
        CFRelease(metaDict);
        CFRelease(mutableDict);
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:dataPath];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
    }];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusDenied) {
        // The user denied authorization
    }
    else if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [locationManager startUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    currentLocation = [locations lastObject];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"failed to fetch current location : %@", error);
}

- (void)runBlockWithTryCatch:(void (^)(void))block {
    @try {
        block();
    } @catch (NSException *exception) {
        NSString* message = [NSString stringWithFormat:@"(%@) - %@", exception.name, exception.reason];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
    }
}

@end
