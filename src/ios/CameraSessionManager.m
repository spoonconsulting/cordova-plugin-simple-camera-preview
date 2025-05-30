#include "CameraSessionManager.h"
@implementation CameraSessionManager

- (CameraSessionManager *)init {
    if (self = [super init]) {
        // Create the AVCaptureSession
        self.session = [AVCaptureSession new];
        self.audioConfigured = false;
        self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
        if ([self.session canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
            [self.session setSessionPreset:AVCaptureSessionPresetPhoto];
        }
        self.filterLock = [NSLock new];
        self.movieFileOutput = [AVCaptureMovieFileOutput new];
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
                videoDevice = [self cameraWithPosition:self.defaultCamera captureDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera];
                if ([options[@"lens"] isEqual:@"wide"] && ![options[@"direction"] isEqual:@"front"] && [self deviceHasUltraWideCamera]) {
                    if (@available(iOS 13.0, *)) {
                        videoDevice = [self cameraWithPosition:self.defaultCamera captureDeviceType:AVCaptureDeviceTypeBuiltInUltraWideCamera];
                    }
                }

                self.aspectRatio = @"3:4";
                NSString *aspectRatio = options[@"aspectRatio"];
                   if (aspectRatio && [aspectRatio length] > 0) {
                       self.aspectRatio = aspectRatio;
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
                
                if (error) {
                    NSLog(@"%@", error);
                    success = FALSE;
                }
                
                if (options) {
                    NSInteger targetSize = ((NSNumber*)options[@"targetSize"]).intValue;
                    self.targetSize = targetSize;
                    AVCaptureSessionPreset calculatedPreset = [self calculateResolution:self.targetSize aspectRatio:self.aspectRatio];
                    if ([self.session canSetSessionPreset:calculatedPreset]) {
                        [self.session setSessionPreset:calculatedPreset];
                    }
                }

                [self.session beginConfiguration];

                AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];

                if ([self.session canAddInput:videoDeviceInput]) {
                    [self.session addInput:videoDeviceInput];
                    self.videoDeviceInput = videoDeviceInput;
                }

                AVCapturePhotoOutput *imageOutput = [AVCapturePhotoOutput new];
                if ([self.session canAddOutput:imageOutput]) {
                    [self.session addOutput:imageOutput];
                    self.imageOutput = imageOutput;
                }
                
                AVCaptureVideoDataOutput *dataOutput = [AVCaptureVideoDataOutput new];
                if ([[AVAudioSession sharedInstance] inputNumberOfChannels] == 0) {
                    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
                    NSError *audioError = nil;
                    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&audioError];
                    if (audioInput && [self.session canAddInput:audioInput]) {
                        [self.session addInput:audioInput];
                    } else {
                        NSLog(@"Error adding audio input: %@", audioError.localizedDescription);
                    }
                    self.audioConfigured = true;
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

                [self.session commitConfiguration];

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

- (void) startSession {
    dispatch_async(self.sessionQueue, ^{
        if (![self.session isRunning]) {
            [self.session startRunning];
        }
    });
}

- (AVCaptureSessionPreset)calculateResolution:(NSInteger)targetSize aspectRatio:(NSString *)aspectRatio {
    // Define the available presets along with their native widths and aspect ratios.
    NSArray<NSDictionary *> *presets = @[
        @{@"preset": AVCaptureSessionPreset3840x2160, @"width": @(3840), @"aspect": @"9:16"},
        @{@"preset": AVCaptureSessionPreset1920x1080, @"width": @(1920), @"aspect": @"9:16"},
        @{@"preset": AVCaptureSessionPreset1280x720,  @"width": @(1280), @"aspect": @"9:16"},
        @{@"preset": AVCaptureSessionPreset640x480,   @"width": @(640),  @"aspect": @"3:4"},
        @{@"preset": AVCaptureSessionPreset352x288,   @"width": @(352),  @"aspect": @"3:4"},
    ];
    
    // Normalize the requested aspect ratio: only "9:16" is treated as such, all other inputs become "3:4".
    NSString *normalizedAspect = [aspectRatio isEqualToString:@"9:16"] ? @"9:16" : @"3:4";   

    // Filter out presets that don’t match the normalized aspect ratio.
    NSPredicate *aspectFilter = [NSPredicate predicateWithFormat:@"aspect == %@", normalizedAspect];
    NSArray<NSDictionary *> *candidates = [presets filteredArrayUsingPredicate:aspectFilter];
    
    // If no positive targetSize is provided, choose a default:
    //    - For "3:4", return the AVCaptureSessionPresetPhoto (highest-quality still image).
    //    - For "9:16", return the first (i.e., highest-resolution) candidate.
    if (targetSize <= 0) {
        if ([normalizedAspect isEqualToString:@"3:4"])
            return AVCaptureSessionPresetPhoto;
        else
            return (AVCaptureSessionPreset)candidates.firstObject[@"preset"];
    }
    
    // Otherwise, find which candidate’s width is closest to the requested targetSize.
    NSDictionary *bestMatch = nil;
    NSInteger bestDiff = NSIntegerMax;
    for (NSDictionary *info in candidates) {
        NSInteger width = [info[@"width"] integerValue];
        NSInteger diff = llabs((long)(width - targetSize));
        if (diff < bestDiff) {
            bestDiff = diff;
            bestMatch = info;
        }
    }

    // Return the preset of the closest match.
    if (bestMatch) {
        return bestMatch[@"preset"];
    } else {
        return candidates.firstObject[@"preset"];
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
    NSString* aspectRatio = cameraOptions[@"aspectRatio"];

    if (aspectRatio && [aspectRatio length] > 0)
        self.aspectRatio = aspectRatio;
    else
        self.aspectRatio = @"3:4";

    if (![self deviceHasUltraWideCamera] && [cameraMode isEqualToString:@"wide"]) {
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
                if (!error && [self.session canAddInput:ultraWideVideoDeviceInput]) {
                    // Add the new input to the session
                    [self.session addInput:ultraWideVideoDeviceInput];
                    self.videoDeviceInput = ultraWideVideoDeviceInput;
                    __block AVCaptureVideoOrientation orientation;
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        orientation = [self getCurrentOrientation];
                    });
                    [self updateOrientation:orientation];
                    self.device = ultraWideCamera;
                    cameraSwitched = TRUE;

                    // Update session preset based on new targetSize and aspectRatio
                    AVCaptureSessionPreset calculatedPreset = [self calculateResolution:self.targetSize aspectRatio:self.aspectRatio];
                    if ([self.session canSetSessionPreset:calculatedPreset]) {
                        [self.session setSessionPreset:calculatedPreset];
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
        self.isCameraDirectionFront = self.defaultCamera == AVCaptureDevicePositionFront;
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
  if (self.session.running) {
    [self.session stopRunning];
  }
  self.session = nil;
  self.videoDeviceInput = nil;
  self.imageOutput = nil;
  self.dataOutput = nil;
  self.filterLock = nil;
  if (self.sessionQueue) {
    self.sessionQueue = nil;
  }
  self.device = nil;
}

@end
