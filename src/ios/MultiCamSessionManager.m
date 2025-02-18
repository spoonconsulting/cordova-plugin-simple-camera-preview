#import "MultiCamSessionManager.h"

@implementation MultiCamSessionManager

- (instancetype)init {
    self = [super init];
    if (self) {
        // Ensure multi-cam is supported.
        if ([AVCaptureMultiCamSession isMultiCamSupported]) {
            self.multiCamSession = [[AVCaptureMultiCamSession alloc] init];
            // Choose an appropriate preset.
            if ([self.multiCamSession canSetSessionPreset:AVCaptureSessionPresetPhoto]) {
                self.multiCamSession.sessionPreset = AVCaptureSessionPresetPhoto;
            }
            self.sessionQueue = dispatch_queue_create("com.yourapp.multicam.sessionqueue", DISPATCH_QUEUE_SERIAL);
        } else {
            NSLog(@"MultiCam not supported on this device.");
            return nil;
        }
    }
    return self;
}

- (void)setupSessionWithCompletion:(void(^)(BOOL success))completion {
    dispatch_async(self.sessionQueue, ^{
        BOOL success = YES;
        NSError *error = nil;
        
        // --- Back Camera Input ---
        AVCaptureDevice *backCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
        if (backCamera) {
            self.backCameraInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
            if (error) {
                NSLog(@"Error creating back camera input: %@", error);
                success = NO;
            } else if ([self.multiCamSession canAddInput:self.backCameraInput]) {
                [self.multiCamSession addInput:self.backCameraInput];
            } else {
                NSLog(@"Cannot add back camera input");
                success = NO;
            }
        } else {
            NSLog(@"Back camera not available");
            success = NO;
        }
        
        // --- Front Camera Input ---
        AVCaptureDevice *frontCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
        if (frontCamera) {
            self.frontCameraInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
            if (error) {
                NSLog(@"Error creating front camera input: %@", error);
                success = NO;
            } else if ([self.multiCamSession canAddInput:self.frontCameraInput]) {
                [self.multiCamSession addInput:self.frontCameraInput];
            } else {
                NSLog(@"Cannot add front camera input");
                success = NO;
            }
        } else {
            NSLog(@"Front camera not available");
            success = NO;
        }
        
        // (Optional) Configure outputs as needed.
        // Here we add video data outputs for demonstration.
        self.backVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
        if ([self.multiCamSession canAddOutput:self.backVideoOutput]) {
            [self.multiCamSession addOutput:self.backVideoOutput];
        } else {
            NSLog(@"Cannot add back video output");
            success = NO;
        }
        
        self.frontVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
        if ([self.multiCamSession canAddOutput:self.frontVideoOutput]) {
            [self.multiCamSession addOutput:self.frontVideoOutput];
        } else {
            NSLog(@"Cannot add front video output");
            success = NO;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(success);
            }
        });
    });
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray<AVCaptureDevice *> *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

- (void)startRunning {
    dispatch_async(self.sessionQueue, ^{
        if (!self.multiCamSession.running) {
            [self.multiCamSession startRunning];
        }
    });
}

- (void)stopRunning {
    dispatch_async(self.sessionQueue, ^{
        if (self.multiCamSession.running) {
            [self.multiCamSession stopRunning];
        }
    });
}

@end
