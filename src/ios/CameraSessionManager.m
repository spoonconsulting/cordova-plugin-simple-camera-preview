#include "CameraSessionManager.h"
@implementation CameraSessionManager

- (CameraSessionManager *)init {
    if (self = [super init]) {
        // Create the AVCaptureSession
        self.session = [[AVCaptureSession alloc] init];
        self.sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
        if ([self.session canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
            [self.session setSessionPreset:AVCaptureSessionPresetPhoto];
        }
        self.filterLock = [[NSLock alloc] init];
    }
    return self;
}

- (AVCaptureVideoOrientation) getCurrentOrientation {
    return [self getCurrentOrientation: [[UIApplication sharedApplication] statusBarOrientation]];
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

- (void) setupSession:(NSString *)defaultCamera completion:(void(^)(BOOL started))completion heightResolution:(NSInteger)heightResolution {
    // If this fails, video input will just stream blank frames and the user will be notified. User only has to accept once.
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        NSLog(@"permission callback");
        if (granted) {
            dispatch_async(self.sessionQueue, ^{
                NSError *error = nil;
                BOOL success = TRUE;
                
                NSLog(@"defaultCamera: %@", defaultCamera);
                if ([defaultCamera isEqual: @"front"]) {
                    self.defaultCamera = AVCaptureDevicePositionFront;
                } else {
                    self.defaultCamera = AVCaptureDevicePositionBack;
                }
                
                AVCaptureDevice * videoDevice = [self cameraWithPosition: self.defaultCamera];
                
                if ([videoDevice hasFlash] && [videoDevice isFlashModeSupported:AVCaptureFlashModeAuto]) {
                    if ([videoDevice lockForConfiguration:&error]) {
                        [videoDevice setFlashMode:AVCaptureFlashModeAuto];
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
                
                AVCaptureSessionPreset calculatedPreset = [self calculateResolution:heightResolution];
                
                if ([self.session canSetSessionPreset:calculatedPreset]) {
                    [self.session setSessionPreset:calculatedPreset];
                }
                
                if ([self.session canAddInput:videoDeviceInput]) {
                    [self.session addInput:videoDeviceInput];
                    self.videoDeviceInput = videoDeviceInput;
                }
                
                AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
                if ([self.session canAddOutput:stillImageOutput]) {
                    [self.session addOutput:stillImageOutput];
                    [stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
                    self.stillImageOutput = stillImageOutput;
                }
                
                AVCaptureVideoDataOutput *dataOutput = [[AVCaptureVideoDataOutput alloc] init];
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

- (AVCaptureSessionPreset) calculateResolution:(NSInteger)height {
    if (height >= 3840) {
        return AVCaptureSessionPreset3840x2160;
    } else if (height >= 1920) {
        return AVCaptureSessionPreset1920x1080;
    } else if (height >= 1280) {
        return AVCaptureSessionPreset1280x720;
    } else if (height >= 640) {
        return AVCaptureSessionPreset640x480;
    } else {
        return AVCaptureSessionPreset352x288;
    }
}

- (void) updateOrientation:(AVCaptureVideoOrientation)orientation {
    AVCaptureConnection *captureConnection;
    if (self.stillImageOutput != nil) {
        captureConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
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
- (NSInteger)getFlashMode {

    if ([self.device hasFlash] && [self.device isFlashModeSupported:self.defaultFlashMode]) {
        return self.device.flashMode;
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

- (void)setFlashMode:(NSInteger)flashMode {
    NSError *error = nil;
    // Let's save the setting even if we can't set it up on this camera.
    self.defaultFlashMode = flashMode;
    
    if ([self.device hasFlash] && [self.device isFlashModeSupported:self.defaultFlashMode]) {
        
        if ([self.device lockForConfiguration:&error]) {
            [self.device setFlashMode:self.defaultFlashMode];
            [self.device unlockForConfiguration];
            
        } else {
            NSLog(@"%@", error);
        }
    } else {
        NSLog(@"Camera has no flash or flash mode not supported");
    }
}
// Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices){
        if ([device position] == position)
            return device;
    }
    return nil;
}

@end
