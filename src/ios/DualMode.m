#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "DualMode.h"

@implementation DualMode

+ (instancetype)shared {
    static DualMode *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DualMode alloc] init];
    });
    return sharedInstance;
}

- (void)toggleDualMode:(UIView *)webView {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.session && self.session.isRunning) {
            NSLog(@"[DualMode] Stopping Dual Mode...");
            [self stopDualMode];
            [self setupDualMode:webView]; // Restart Dual Mode
        } else {
            NSLog(@"[DualMode] Restarting Dual Mode...");
            self.session = nil; // Ensure old session is fully reset
            [self setupDualMode:webView];
        }
    });
}

- (BOOL)setupDualMode:(UIView *)webView {
    NSLog(@"[DualMode] Setting up Dual Mode...");

    if (!AVCaptureMultiCamSession.isMultiCamSupported) {
        NSLog(@"[DualMode] ERROR: MultiCam not supported on this device.");
        return NO;
    }

    // Ensure session is always recreated
    self.session = [[AVCaptureMultiCamSession alloc] init];
    [self.session beginConfiguration];

    @try {
        // Remove old inputs before adding new ones
        if (self.frontCameraInput) {
            [self.session removeInput:self.frontCameraInput];
            self.frontCameraInput = nil;
        }
        if (self.backCameraInput) {
            [self.session removeInput:self.backCameraInput];
            self.backCameraInput = nil;
        }

        // Setup Back Camera
        AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        if (backCamera) {
            AVCaptureDeviceInput *backCameraInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:nil];
            if ([self.session canAddInput:backCameraInput]) {
                [self.session addInput:backCameraInput];
                self.backCameraInput = backCameraInput;
                NSLog(@"[DualMode] Back Camera added successfully.");
            } else {
                NSLog(@"[DualMode] ERROR: Cannot add back camera input.");
            }
        } else {
            NSLog(@"[DualMode] ERROR: Back camera not found.");
        }

        // Setup Front Camera
        AVCaptureDevice *frontCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        if (frontCamera) {
            AVCaptureDeviceInput *frontCameraInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:nil];
            if ([self.session canAddInput:frontCameraInput]) {
                [self.session addInput:frontCameraInput];
                self.frontCameraInput = frontCameraInput;
                NSLog(@"[DualMode] Front Camera added successfully.");
            } else {
                NSLog(@"[DualMode] ERROR: Cannot add front camera input.");
            }
        } else {
            NSLog(@"[DualMode] ERROR: Front camera not found.");
        }

        [self.session commitConfiguration];
        [self.session startRunning];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupPreviewLayers:webView];
        });

        NSLog(@"[DualMode] Dual Mode started successfully.");
        return YES;
    }
    @catch (NSException *exception) {
        NSLog(@"[DualMode] ERROR: Failed to setup dual mode - %@", exception.reason);
        [self cleanupOnError];
        return NO;
    }
}

- (void)setupPreviewLayers:(UIView *)webView {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!webView || !webView.superview) {
            NSLog(@"[DualMode] ERROR: WebView or superview is nil. Aborting setup.");
            return;
        }

        UIView *rootView = webView.superview;

        // Remove any existing previewContainer before creating a new one
        [self.previewContainer removeFromSuperview];
        self.previewContainer = [[UIView alloc] initWithFrame:rootView.bounds];
        self.previewContainer.backgroundColor = [UIColor blackColor];
        [rootView insertSubview:self.previewContainer belowSubview:webView];

        // Setup Back Camera Preview Layer
        self.backPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        self.backPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.backPreviewLayer.frame = self.previewContainer.bounds;
        [self.previewContainer.layer addSublayer:self.backPreviewLayer];

        // Create a smaller front camera preview overlay
        CGRect frontFrame = CGRectMake(10, 50, 150, 200);
        UIView *frontView = [[UIView alloc] initWithFrame:frontFrame];
        frontView.backgroundColor = [UIColor clearColor];
        [self.previewContainer addSubview:frontView];

        self.frontPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        self.frontPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.frontPreviewLayer.frame = frontView.bounds;
        self.frontPreviewLayer.cornerRadius = 10;
        self.frontPreviewLayer.masksToBounds = YES;
        [frontView.layer addSublayer:self.frontPreviewLayer];

        NSLog(@"[DualMode] Preview layers set up successfully.");
    });
}

@end
