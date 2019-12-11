
#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>
@import CoreLocation; 
@import ImageIO;

#import "SimpleCameraPreview.h"

@implementation SimpleCameraPreview

-(void) pluginInitialize{
    // start as transparent
    self.webView.opaque = NO;
    self.webView.backgroundColor = [UIColor clearColor];
    //abort();
    [NSString stringWithString:nil];
}

- (void) enable:(CDVInvokedUrlCommand*)command {
    CDVPluginResult *pluginResult;
    if (self.sessionManager != nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera already started!"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }
    //required to get gps exif
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [locationManager requestWhenInUseAuthorization];
    
    // Create the session manager
    self.sessionManager = [[CameraSessionManager alloc] init];
    
    // render controller setup
    self.cameraRenderController = [[CameraRenderController alloc] init];
    self.cameraRenderController.sessionManager = self.sessionManager;
    [self setSize:command];
    [self.viewController addChildViewController:self.cameraRenderController];
    [self.webView.superview insertSubview:self.cameraRenderController.view atIndex:0];
    self.viewController.view.backgroundColor = [UIColor blackColor];
    
    // Setup session
    self.sessionManager.delegate = self.cameraRenderController;
    
    [self.sessionManager setupSession:@"back" completion:^(BOOL started) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
        });
    }];
}

- (void) disable:(CDVInvokedUrlCommand*)command {
    NSLog(@"disable");
    [self.cameraRenderController.view removeFromSuperview];
    [self.cameraRenderController removeFromParentViewController];
    self.cameraRenderController = nil;
    
    [self.commandDelegate runInBackground:^{
        CDVPluginResult *pluginResult;
        if(self.sessionManager != nil) {
            for(AVCaptureInput *input in self.sessionManager.session.inputs) {
                [self.sessionManager.session removeInput:input];
            }
            
            for(AVCaptureOutput *output in self.sessionManager.session.outputs) {
                [self.sessionManager.session removeOutput:output];
            }
            
            [self.sessionManager.session stopRunning];
            self.sessionManager = nil;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

-(void) setSize:(CDVInvokedUrlCommand*)command{
    NSDictionary* config = command.arguments[0];
    float x = ((NSNumber*)config[@"x"]).floatValue;
    float y = ((NSNumber*)config[@"y"]).floatValue + self.webView.frame.origin.y;
    float width = ((NSNumber*)config[@"width"]).floatValue;
    float height = ((NSNumber*)config[@"height"]).floatValue;
    self.cameraRenderController.view.frame = CGRectMake(x, y, width, height);
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) capture:(CDVInvokedUrlCommand*)command {
    BOOL useFlash = [[command.arguments objectAtIndex:0] boolValue];
    if (self.sessionManager != nil) 
        [self.sessionManager setFlashMode:useFlash? AVCaptureFlashModeOn: AVCaptureFlashModeOff];
    
    CDVPluginResult *pluginResult;
    if (self.cameraRenderController != NULL) {
        self.onPictureTakenHandlerId = command.callbackId;
        [self capture];
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

- (void) capture{
    AVCaptureConnection *connection = [self.sessionManager.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    [self.sessionManager.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef sampleBuffer, NSError *error) {
        if (error) {
            NSLog(@"%@", error);
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Error taking picture"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
        } else {
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:sampleBuffer];
            CFDictionaryRef metaDict = CMCopyDictionaryOfAttachments(NULL, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
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
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:uniqueFileName];
            [pluginResult setKeepCallbackAsBool:true];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
        }
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

@end
