#include "CameraSessionManager.h"
@implementation CameraSessionManager

- (CameraSessionManager *)init {
    if (self = [super init]) {
        self.session = [[AVCaptureSession alloc] init];
        self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
        if ([self.session canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
            [self.session setSessionPreset:AVCaptureSessionPresetPhoto];
        }
        self.filterLock = [[NSLock alloc] init];
        self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    }
    return self;
}

- (AVCaptureVideoOrientation) getCurrentOrientation {
    UIInterfaceOrientation orientation = [self getOrientation];
    return [self getCurrentOrientation: orientation];
}

- (AVCaptureVideoOrientation) getCurrentOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    AVCaptureVideoOrientation orientation;
    switch (toInterfaceOrientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        default:
        case UIInterfaceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
    }
    return orientation;
}

- (void)setupSession:(NSDictionary *)options completion:(void(^)(BOOL started))completion photoSettings:(AVCapturePhotoSettings *)photoSettings {
    // If this fails, video input will just stream blank frames and the user will be notified. User only has to accept once.
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        NSLog(@"permission callback");
        if (granted) {
            dispatch_async(self.sessionQueue, ^{
                NSError *error = nil;
                BOOL success = TRUE;
                
                if ([options[@"direction"] isEqual: @"front"]) {
                    self.defaultCamera = AVCaptureDevicePositionFront;
                } else {
                    self.defaultCamera = AVCaptureDevicePositionBack;
                }
                
                AVCaptureDevice *videoDevice;
                NSLog(@"Enable normal mode setup session: %@", options[@"lens"]);
                videoDevice = [self cameraWithPosition:self.defaultCamera captureDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera];
                if ([options[@"lens"] isEqual:@"wide"] && ![options[@"direction"] isEqual:@"front"] && [self deviceHasUltraWideCamera]) {
                    if (@available(iOS 13.0, *)) {
                        videoDevice = [self cameraWithPosition:self.defaultCamera captureDeviceType:AVCaptureDeviceTypeBuiltInUltraWideCamera];
                    }
                }
                
                if (options[@"previewWidth"] && options[@"previewHeight"]) {
                    CGFloat previewWidth = ((NSNumber *)options[@"previewWidth"]).floatValue;
                    CGFloat previewHeight = ((NSNumber *)options[@"previewHeight"]).floatValue;
                    
                    CMVideoDimensions bestDimensions = (CMVideoDimensions){0, 0};
                    AVCaptureDeviceFormat *bestFormat = nil;
                    
                    for (AVCaptureDeviceFormat *format in [videoDevice formats]) {
                        CMFormatDescriptionRef desc = format.formatDescription;
                        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(desc);

                        if (dimensions.width >= (int)previewWidth && dimensions.height >= (int)previewHeight) {
                            if (!bestFormat || (dimensions.width < bestDimensions.width && dimensions.height < bestDimensions.height)) {
                                bestFormat = format;
                                bestDimensions = dimensions;
                            }
                        }
                    }
                    
                    if (bestFormat) {
                        NSError *formatError = nil;
                        if ([videoDevice lockForConfiguration:&formatError]) {
                            videoDevice.activeFormat = bestFormat;
                            videoDevice.videoZoomFactor = 1.0;
                            [videoDevice unlockForConfiguration];
                        } else {
                            NSLog(@"Failed to set activeFormat: %@", formatError.localizedDescription);
                        }
                    }
                }
                
                if ([videoDevice hasFlash]) {
                    if ([videoDevice lockForConfiguration:&error]) {
                        photoSettings.flashMode = AVCaptureFlashModeAuto;
                        [videoDevice unlockForConfiguration];
                    } else {
                        NSLog(@"%@", error);
                        success = FALSE;
                    }
                }
                
                AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
                
                if (error) {
                    NSLog(@"%@", error);
                    success = FALSE;
                }
                
                if (options) {
                    NSInteger targetSize = ((NSNumber*)options[@"targetSize"]).intValue;
                    if (targetSize > 0) {
                        AVCaptureSessionPreset calculatedPreset = [CameraSessionManager calculateResolution:targetSize];
                        if ([self.session canSetSessionPreset:calculatedPreset]) {
                            [self.session setSessionPreset:calculatedPreset];
                        }
                    }
                }
                
                if ([self.session canAddInput:videoDeviceInput]) {
                    [self.session addInput:videoDeviceInput];
                    self.videoDeviceInput = videoDeviceInput;
                }
                
                AVCapturePhotoOutput *imageOutput = [[AVCapturePhotoOutput alloc] init];
                if ([self.session canAddOutput:imageOutput]) {
                    [self.session addOutput:imageOutput];
                    self.imageOutput = imageOutput;
                }
                
                AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
                
                AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
                NSError *audioError = nil;
                AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&audioError];
                if (audioInput && [self.session canAddInput:audioInput]) {
                    [self.session addInput:audioInput];
                } else {
                    NSLog(@"Error adding audio input: %@", audioError.localizedDescription);
                }

                if ([self.session canAddOutput:self.movieFileOutput]) {
                    [self.session addOutput:self.movieFileOutput];
                }
                if ([self.session canAddOutput:dataOutput]) {
                    self.dataOutput = dataOutput;
                    [dataOutput setAlwaysDiscardsLateVideoFrames:YES];
                    [dataOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
                    
                    [dataOutput setSampleBufferDelegate:self.delegate queue:self.sessionQueue];
                    
                    [self.session addOutput:dataOutput];
                }
                __block AVCaptureVideoOrientation orientation;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    orientation=[self getCurrentOrientation];
                });
                [self updateOrientation:orientation];
                self.device = videoDevice;
                
                completion(success);
            });
        }else{
            completion(false);
        }
    }];
}

+ (AVCaptureSessionPreset) calculateResolution:(NSInteger)targetSize {
    if (targetSize >= 3840) {
        return AVCaptureSessionPreset3840x2160;
    } else if (targetSize >= 1920) {
        return AVCaptureSessionPreset1920x1080;
    } else if (targetSize >= 1280) {
        return AVCaptureSessionPreset1280x720;
    } else if (targetSize >= 640) {
        return AVCaptureSessionPreset640x480;
    } else {
        return AVCaptureSessionPreset352x288;
    }
}

- (void) updateOrientation:(AVCaptureVideoOrientation)orientation {
    AVCaptureConnection *captureConnection;
    if (self.imageOutput != nil) {
        captureConnection = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoOrientationSupported]) {
            [captureConnection setVideoOrientation:orientation];
        }
    }
    
    if (self.dataOutput != nil) {
        captureConnection = [self.dataOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([captureConnection isVideoOrientationSupported]) {
            [captureConnection setVideoOrientation:orientation];
        }
    }
}
- (NSInteger)getFlashMode:(AVCapturePhotoSettings *)photoSettings {

    if ([self.device hasFlash]) {
        return photoSettings.flashMode;
    }

    return -1;
}

- (void) torchSwitch:(NSInteger)torchState{
    NSError *error = nil;
    if ([self.device hasTorch] && [self.device isTorchAvailable]) {
        if ([self.device lockForConfiguration:&error]) {
            self.device.torchMode = torchState;
            [self.device unlockForConfiguration];
        }
    }
}

- (void)switchCameraTo:(NSDictionary*)cameraOptions completion:(void (^)(BOOL success))completion {
    NSString* cameraMode = cameraOptions[@"lens"];
    NSString* cameraDirection = cameraOptions[@"direction"];

    if ([cameraDirection isEqualToString:@"back"] && ![self deviceHasUltraWideCamera] && [cameraMode isEqualToString:@"wide"]) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    self.defaultCamera = ([cameraDirection isEqual:@"front"]) ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;

    dispatch_async(self.sessionQueue, ^{
        BOOL cameraSwitched = FALSE;
        if (@available(iOS 13.0, *)) {
            AVCaptureDevice *ultraWideCamera;
            if([cameraMode isEqualToString:@"wide"]) {
                ultraWideCamera = [self cameraWithPosition:self.defaultCamera captureDeviceType:AVCaptureDeviceTypeBuiltInUltraWideCamera];
            } else {
                ultraWideCamera = [self cameraWithPosition:self.defaultCamera captureDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera];
            }
            if (ultraWideCamera) {
                // Remove the current input
                [self.session removeInput:self.videoDeviceInput];
                
                // Create a new input with the ultra-wide camera
                NSError *error = nil;
                AVCaptureDeviceInput *ultraWideVideoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:ultraWideCamera error:&error];
                
                if (!error) {
                    // Add the new input to the session
                    if ([self.session canAddInput:ultraWideVideoDeviceInput]) {
                        [self.session addInput:ultraWideVideoDeviceInput];
                        self.videoDeviceInput = ultraWideVideoDeviceInput;
                        __block AVCaptureVideoOrientation orientation;
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            orientation = [self getCurrentOrientation];
                        });
                        [self updateOrientation:orientation];
                        self.device = ultraWideCamera;
                        cameraSwitched = TRUE;
                    } else {
                        NSLog(@"Failed to add ultra-wide input to session");
                    }
                } else {
                    NSLog(@"Error creating ultra-wide device input: %@", error.localizedDescription);
                }
            } else {
                NSLog(@"Ultra-wide camera not found");
            }
        }
        
        completion ? completion(cameraSwitched): NULL;
    });
}

- (void)startRecording:(NSURL *)fileURL recordingDelegate:(id<AVCaptureFileOutputRecordingDelegate>)recordingDelegate videoDurationMs:(NSInteger)videoDurationMs {
    if (!self.movieFileOutput.isRecording) {
        AVCaptureConnection *connection = [self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoOrientationSupported]) {
            connection.videoOrientation = [self getCurrentOrientation];
        }
        [self.movieFileOutput startRecordingToOutputFileURL:fileURL recordingDelegate:recordingDelegate];
        
        NSInteger videoDurationInSec = videoDurationMs / 1000;
        _videoTimer = [NSTimer scheduledTimerWithTimeInterval:videoDurationInSec
                                        target:self
                                        selector:@selector(stopRecording)
                                        userInfo:nil
                                        repeats:NO];
    }
}

- (void)stopRecording {
    if (self.movieFileOutput.isRecording) {
        [self.movieFileOutput stopRecording];
    }
    if (_videoTimer != nil) {
        [_videoTimer invalidate];
        _videoTimer = nil;
    }
}

- (BOOL)deviceHasUltraWideCamera {
    if (@available(iOS 13.0, *)) {
        AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInUltraWideCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
        return discoverySession.devices.count > 0;
    } else {
        return NO;
    }
}

- (void)setFlashMode:(NSInteger)flashMode photoSettings:(AVCapturePhotoSettings *)photoSettings {
    NSError *error = nil;
    // Let's save the setting even if we can't set it up on this camera.
    self.defaultFlashMode = flashMode;
    
    if ([self.device hasFlash]) {
        
        if ([self.device lockForConfiguration:&error]) {
            photoSettings.flashMode = self.defaultFlashMode;
            [self.device unlockForConfiguration];
            
        } else {
            NSLog(@"%@", error);
        }
    } else {
        NSLog(@"Camera has no flash or flash mode not supported");
    }
}
// Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position captureDeviceType:(AVCaptureDeviceType) captureDeviceType {
    AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[ captureDeviceType] mediaType:AVMediaTypeVideo position:self.defaultCamera];
    NSArray *devices = [captureDeviceDiscoverySession devices];
    for (AVCaptureDevice *device in devices){
        if ([device position] == position)
            return device;
    }
    return nil;
}

- (UIInterfaceOrientation) getOrientation {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *activeWindow = (UIWindowScene *)[[[UIApplication sharedApplication] windows] firstObject];
        return [activeWindow interfaceOrientation] ?: UIInterfaceOrientationPortrait;
    } else {
        return [[UIApplication sharedApplication] statusBarOrientation];
    }
}

- (void)deallocSession {
    if (self.session && self.session.running) {
        [self.session stopRunning];
    }

    // Remove inputs
    for (AVCaptureInput *input in self.session.inputs) {
        [self.session removeInput:input];
    }

    // Remove outputs
    for (AVCaptureOutput *output in self.session.outputs) {
        [self.session removeOutput:output];
    }

    self.session = nil;
    self.videoDeviceInput = nil;
    self.imageOutput = nil;
    self.dataOutput = nil;
    self.device = nil;
    self.filterLock = nil;
    self.sessionQueue = nil;
}


@end
