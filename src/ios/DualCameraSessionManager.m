#import "DualCameraSessionManager.h"

@implementation DualCameraSessionManager

- (instancetype)init {
    self = [super init];
    if (self) {
        self.session = [[AVCaptureMultiCamSession alloc] init];
    }
    return self;
}

- (void)setupDualCameraSessionWithDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate {
    if (![AVCaptureMultiCamSession isMultiCamSupported]) {
        NSLog(@"MultiCam not supported on this device.");
        return;
    }

    NSError *error = nil;

    // Setup back camera
    AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                      mediaType:AVMediaTypeVideo
                                                                       position:AVCaptureDevicePositionBack];

    if (backCamera) {
        self.backCameraInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
        if (!error && [self.session canAddInput:self.backCameraInput]) {
            [self.session addInput:self.backCameraInput];
        } else {
            NSLog(@"Error setting up back camera input: %@", error.localizedDescription);
        }

        self.backCameraOutput = [[AVCaptureVideoDataOutput alloc] init];
        [self.backCameraOutput setSampleBufferDelegate:delegate queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];

        if ([self.session canAddOutput:self.backCameraOutput]) {
            [self.session addOutput:self.backCameraOutput];
            self.backCameraConnection = [self.backCameraOutput connectionWithMediaType:AVMediaTypeVideo];
        }
    }

    // Setup front camera
    AVCaptureDevice *frontCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                       mediaType:AVMediaTypeVideo
                                                                        position:AVCaptureDevicePositionFront];

    if (frontCamera) {
        self.frontCameraInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];
        if (!error && [self.session canAddInput:self.frontCameraInput]) {
            [self.session addInput:self.frontCameraInput];
        } else {
            NSLog(@"Error setting up front camera input: %@", error.localizedDescription);
        }

        self.frontCameraOutput = [[AVCaptureVideoDataOutput alloc] init];
        [self.frontCameraOutput setSampleBufferDelegate:delegate queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)];

        if ([self.session canAddOutput:self.frontCameraOutput]) {
            [self.session addOutput:self.frontCameraOutput];
            self.frontCameraConnection = [self.frontCameraOutput connectionWithMediaType:AVMediaTypeVideo];
        }
    }

    NSLog(@"Dual camera session setup completed.");
}

- (void)startSession {
    if (![self.session isRunning]) {
        [self.session startRunning];
        NSLog(@"Dual camera session started.");
    }
}

- (void)stopSession {
    if ([self.session isRunning]) {
        [self.session stopRunning];
        NSLog(@"Dual camera session stopped.");
    }
}

@end
