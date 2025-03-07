
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
    [self.cameraRenderController didMoveToParentViewController:self.viewController];
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
            NSString *captureDevice = config[@"lens"];
            if (captureDevice && [captureDevice length] > 0) {
                [setupSessionOptions setValue:captureDevice forKey:@"lens"];
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

- (void) enable1:(CDVInvokedUrlCommand*)command {
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
    
    // required to get gps exif
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
    [self.cameraRenderController didMoveToParentViewController:self.viewController];
    self.viewController.view.backgroundColor = [UIColor blackColor];
    
    // Setup session delegate
    self.sessionManager.delegate = self.cameraRenderController;
    
    // (Optionally, set up any options from the command here...)
    
    // Instead of calling setupSession for a normal (single-camera) mode,
    // we call switchToDualMode so that dual mode is enabled by default.
    [self switchToDualMode:command];
}


// - (void)switchMode:(CDVInvokedUrlCommand*)command {
//     NSString *mode = command.arguments[0]; // expecting @"dual" or @"normal"
//     if ([mode isEqualToString:@"dual"]) {
//         [self switchToDualMode:command];
//     } else if ([mode isEqualToString:@"normal"]) {
//         [self switchToNormalMode:command];
//     } else {
//         CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
//                                                             messageAsString:@"Invalid mode specified"];
//         [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
//     }
// }

- (void)switchMode:(CDVInvokedUrlCommand*)command {
    NSString *mode = command.arguments[0]; // expecting @"dual" or @"normal"

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([mode isEqualToString:@"dual"]) {
            if ([[DualModeManager shared] setupDualModeIn:self.webView]) {
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Dual mode enabled"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            } else {
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Failed to enable dual mode"];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        } 
    });
}

- (void)disableDualMode:(CDVInvokedUrlCommand*)command {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[DualModeManager shared] stopDualMode]; // Calls Swift function to stop preview and disable session
        
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Dual mode disabled"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    });
}

- (void)switchToDualMode:(CDVInvokedUrlCommand*)command {
    // Ensure sessionManager and sessionQueue exist.
    if (!self.sessionManager) {
        self.sessionManager = [[CameraSessionManager alloc] init];
        self.sessionManager.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    } else if (!self.sessionManager.sessionQueue) {
        self.sessionManager.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
    }
    
    dispatch_async(self.sessionManager.sessionQueue, ^{
        // Stop the current session if running.
        if (self.sessionManager.session.running) {
            [self.sessionManager.session stopRunning];
        }
        
        // Tear down current session inputs/outputs.
        [self.sessionManager deallocSession];
        // Reinitialize the sessionQueue after deallocating the session.
        self.sessionManager.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
        
        // Create a new multi-cam session (requires iOS 13+).
        if (@available(iOS 13.0, *)) {
            self.sessionManager.session = [[AVCaptureMultiCamSession alloc] init];
            // Optionally set a preset that works well for dual mode.
            if ([self.sessionManager.session canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
                [self.sessionManager.session setSessionPreset:AVCaptureSessionPresetPhoto];
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                messageAsString:@"Dual mode is not supported on this device."];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            });
            return;
        }
        
        NSError *error = nil;
        // Configure the back camera input.
        AVCaptureDevice *backCamera = [self.sessionManager cameraWithPosition:AVCaptureDevicePositionBack
                                                           captureDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera];
        AVCaptureDeviceInput *backInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (error || ![self.sessionManager.session canAddInput:backInput]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                messageAsString:@"Unable to add back camera input."];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            });
            return;
        }
        [self.sessionManager.session addInput:backInput];
        
        // Configure the front camera input.
        AVCaptureDevice *frontCamera = [self.sessionManager cameraWithPosition:AVCaptureDevicePositionFront
                                                            captureDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera];
        AVCaptureDeviceInput *frontInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        if (error || ![self.sessionManager.session canAddInput:frontInput]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                messageAsString:@"Unable to add front camera input."];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            });
            return;
        }
        [self.sessionManager.session addInput:frontInput];
        
        // Create two separate video data outputs, one for each camera.
        AVCaptureVideoDataOutput *backOutput = [[AVCaptureVideoDataOutput alloc] init];
        AVCaptureVideoDataOutput *frontOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        // Set properties on outputs.
        backOutput.alwaysDiscardsLateVideoFrames = YES;
        frontOutput.alwaysDiscardsLateVideoFrames = YES;
        NSDictionary *videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
        [backOutput setVideoSettings:videoSettings];
        [frontOutput setVideoSettings:videoSettings];
        
        // Create separate queues for each output.
        dispatch_queue_t backOutputQueue = dispatch_queue_create("backOutputQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t frontOutputQueue = dispatch_queue_create("frontOutputQueue", DISPATCH_QUEUE_SERIAL);
        
        // Instantiate left and right preview controllers on the main thread and force view loading.
        // Instantiate preview controllers on the main thread.
        __block CameraRenderController *backPreviewController;
        __block CameraRenderController *frontPreviewController;
        dispatch_sync(dispatch_get_main_queue(), ^{
            backPreviewController = [[CameraRenderController alloc] init];
            frontPreviewController = [[CameraRenderController alloc] init];
            // Force view loading.
            (void)backPreviewController.view;
            (void)frontPreviewController.view;
            backPreviewController.sessionManager = self.sessionManager;
            frontPreviewController.sessionManager = self.sessionManager;
            // **Assign the camera positions**
            backPreviewController.cameraPosition = AVCaptureDevicePositionBack;
            frontPreviewController.cameraPosition = AVCaptureDevicePositionFront;
        });

        
        // Set the sample buffer delegate for each output.
        [backOutput setSampleBufferDelegate:backPreviewController queue:backOutputQueue];
        [frontOutput setSampleBufferDelegate:frontPreviewController queue:frontOutputQueue];
        
        // Configure the output connections.
        AVCaptureConnection *backConnection = [backOutput connectionWithMediaType:AVMediaTypeVideo];
        if (backConnection.isVideoOrientationSupported) {
            backConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
        backConnection.enabled = YES;  // Explicitly enable connection
        
        AVCaptureConnection *frontConnection = [frontOutput connectionWithMediaType:AVMediaTypeVideo];
        if (frontConnection.isVideoOrientationSupported) {
            frontConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
        frontConnection.enabled = YES;  // Explicitly enable connection
        // Add outputs to the session.
        if ([self.sessionManager.session canAddOutput:backOutput]) {
            [self.sessionManager.session addOutput:backOutput];
        }
        if ([self.sessionManager.session canAddOutput:frontOutput]) {
            [self.sessionManager.session addOutput:frontOutput];
        }
        
        // Optionally, add a shared photo output.
        AVCapturePhotoOutput *photoOutput = [[AVCapturePhotoOutput alloc] init];
        if ([self.sessionManager.session canAddOutput:photoOutput]) {
            [self.sessionManager.session addOutput:photoOutput];
            self.sessionManager.imageOutput = photoOutput;
        }
        
        // Update the UI on the main thread.
        // Update the UI on the main thread.
        dispatch_async(dispatch_get_main_queue(), ^{
            // Remove the current single preview.
            [self.cameraRenderController.view removeFromSuperview];
            [self.cameraRenderController removeFromParentViewController];
            
            // Create a container view for dual previews.
            UIView *dualContainer = [[UIView alloc] initWithFrame:self.webView.superview.bounds];
            
            // Set the back camera preview (leftPreview) to fill the container.
            backPreviewController.view.frame = dualContainer.bounds;
            
            // Set the front camera preview (rightPreview) as a smaller overlay (picture in picture) in the top left.
            CGFloat pipWidth = dualContainer.bounds.size.width / 3;
            CGFloat pipHeight = dualContainer.bounds.size.height / 3;
            CGRect pipFrame = CGRectMake(10, 10, pipWidth, pipHeight);
            frontPreviewController.view.frame = pipFrame;
            
            // Add both preview views.
            [dualContainer addSubview:backPreviewController.view];
            [dualContainer addSubview:frontPreviewController.view];
            
            // Add the preview controllers as children.
            [self.viewController addChildViewController:backPreviewController];
            [self.viewController addChildViewController:frontPreviewController];
            [backPreviewController didMoveToParentViewController:self.viewController];
            [frontPreviewController didMoveToParentViewController:self.viewController];
            
            // Store the dual preview controllers.
            self.dualPreviewControllers = @[backPreviewController, frontPreviewController];
            // Insert the dual container behind the webView.
            [self.webView.superview insertSubview:dualContainer atIndex:0];
            
            // Mark that we are in dual mode.
            self.dualModeEnabled = YES;
        });

        
        // Start the new multi-cam session.
        [self.sessionManager.session startRunning];
        dispatch_async(dispatch_get_main_queue(), ^{
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                messageAsString:@"Switched to dual mode"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        });
    });
}




- (void)switchToNormalMode:(CDVInvokedUrlCommand*)command {
    dispatch_async(self.sessionManager.sessionQueue, ^{
        // Stop the current dual session if running.
        if (self.sessionManager.session.running) {
            [self.sessionManager.session stopRunning];
        }
        // Tear down the dual mode session.
        [self.sessionManager deallocSession];
        
        // Create a new standard AVCaptureSession.
        self.sessionManager.session = [[AVCaptureSession alloc] init];
        if ([self.sessionManager.session canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
            [self.sessionManager.session setSessionPreset:AVCaptureSessionPresetPhoto];
        }
        
        NSError *error = nil;
        // Configure a single (default back) camera input.
        AVCaptureDevice *videoDevice = [self.sessionManager cameraWithPosition:AVCaptureDevicePositionBack
                                                           captureDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera];
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
        if (error || ![self.sessionManager.session canAddInput:videoDeviceInput]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                                    messageAsString:@"Unable to add camera input."];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            });
            return;
        }
        [self.sessionManager.session addInput:videoDeviceInput];
        self.sessionManager.videoDeviceInput = videoDeviceInput;
        
        // Add outputs for normal mode (e.g., photo output).
        AVCapturePhotoOutput *photoOutput = [[AVCapturePhotoOutput alloc] init];
        if ([self.sessionManager.session canAddOutput:photoOutput]) {
            [self.sessionManager.session addOutput:photoOutput];
            self.sessionManager.imageOutput = photoOutput;
        }
        
        // Update the UI on the main thread.
        dispatch_async(dispatch_get_main_queue(), ^{
            // Remove dual preview controllers if they exist.
            if (self.dualPreviewControllers) {
                for (UIViewController *vc in self.dualPreviewControllers) {
                    [vc.view removeFromSuperview];
                    [vc removeFromParentViewController];
                }
                self.dualPreviewControllers = nil;
            }
            // Remove any container view that was used for dual mode.
            UIView *firstSubview = [self.webView.superview.subviews firstObject];
            if (firstSubview) {
                [firstSubview removeFromSuperview];
            }
            // Re-create (or reuse) the single preview.
            if (!self.cameraRenderController) {
                self.cameraRenderController = [[CameraRenderController alloc] init];
                self.cameraRenderController.sessionManager = self.sessionManager;
            }
            // Reset the preview size using your existing _setSize: method.
            [self _setSize:command];
            [self.viewController addChildViewController:self.cameraRenderController];
            [self.webView.superview insertSubview:self.cameraRenderController.view atIndex:0];
            [self.cameraRenderController didMoveToParentViewController:self.viewController];
            self.dualModeEnabled = NO;
        });
        
        // Start the normal session.
        [self.sessionManager.session startRunning];
        dispatch_async(dispatch_get_main_queue(), ^{
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                                messageAsString:@"Switched to normal mode"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        });
    });
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
            self.sessionManager.delegate = nil;
            [self.sessionManager deallocSession];
            self.sessionManager = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.cameraRenderController willMoveToParentViewController:nil];
                [self.cameraRenderController.view removeFromSuperview];
                [self.cameraRenderController removeFromParentViewController];
                [self.cameraRenderController deallocateRenderMemory];
                self.cameraRenderController = nil;
                [self deallocateMemory];
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
    formatter = nil;
    
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
        CFRelease(imageSource);
        CFRelease(UTI);
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

- (void)deallocateMemory {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionInterruptionEndedNotification object:nil];
    [locationManager stopUpdatingLocation];
    locationManager.delegate = nil;
    locationManager = nil;
}

- (void) initVideoCallback:(CDVInvokedUrlCommand*)command {
    self.videoCallbackContext = command;
    NSDictionary *data = @{ @"videoCallbackInitialized" : @true };
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:data];
    [pluginResult setKeepCallbackAsBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)startVideoCapture:(CDVInvokedUrlCommand*)command {
    NSDictionary* config = command.arguments[0];
    NSInteger videoDuration = ((NSNumber*)config[@"videoDurationMs"]).intValue;

    if (self.sessionManager != nil && !self.sessionManager.movieFileOutput.isRecording) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *libraryDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"NoCloud"];
        NSString* uniqueFileName = [NSString stringWithFormat:@"%@.mp4",[[NSUUID UUID] UUIDString]];
        NSString *dataPath = [libraryDirectory stringByAppendingPathComponent:uniqueFileName];
        NSURL *fileURL = [NSURL fileURLWithPath:dataPath];
        [self.sessionManager startRecording:fileURL recordingDelegate:self videoDurationMs:videoDuration];
    } else {
       CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not initialized or already recording"];
       [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void)stopVideoCapture:(CDVInvokedUrlCommand*)command {
    if (self.sessionManager != nil && self.sessionManager.movieFileOutput.isRecording) {
        [self.sessionManager stopRecording];
    } else {
       CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not initialized or not recording"];
       [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (NSString*)generateThumbnailForVideoAtURL:(NSURL *)videoURL {
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(1.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef imageRef = [imageGenerator copyCGImageAtTime:time actualTime:&actualTime error:&error];

    if (error) {
        NSLog(@"Error generating thumbnail: %@", error.localizedDescription);
        return nil;
    }

    UIImage *thumbnail = [[UIImage alloc] initWithCGImage:imageRef];
    CGImageRelease(imageRef);

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"NoCloud"];

    NSError *directoryError = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:libraryDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:libraryDirectory withIntermediateDirectories:YES attributes:nil error:&directoryError];

        if (directoryError) {
            NSLog(@"Error creating NoCloud directory: %@", directoryError.localizedDescription);
            return nil;
        }
    }

    NSString *uniqueFileName = [NSString stringWithFormat:@"video_thumb_%@.jpg", [[NSUUID UUID] UUIDString]];
    NSString *filePath = [libraryDirectory stringByAppendingPathComponent:uniqueFileName];

    NSData *jpegData = UIImageJPEGRepresentation(thumbnail, 1.0);

    if ([jpegData writeToFile:filePath atomically:YES]) {
        NSLog(@"Thumbnail saved successfully at path: %@", filePath);
    } else {
        NSLog(@"Failed to save thumbnail.");
        return nil;
    }
    return filePath;
}


- (void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections {
    NSDictionary *result = @{@"recording": @TRUE};
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
    [pluginResult setKeepCallbackAsBool:true];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:self.videoCallbackContext.callbackId];
}

- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    if (error) {
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.videoCallbackContext.callbackId];
    } else {
        NSString *thumbnail = [self generateThumbnailForVideoAtURL:outputFileURL];
        NSString *filePath = [outputFileURL path];
        NSDictionary *result = @{@"nativePath": filePath, @"thumbnail": thumbnail};

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.videoCallbackContext.callbackId];
    }
}

@end