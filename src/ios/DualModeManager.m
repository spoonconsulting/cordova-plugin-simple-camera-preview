#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface DualModeManager : NSObject

@property (nonatomic, strong) AVCaptureMultiCamSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *frontCameraInput;
@property (nonatomic, strong) AVCaptureDeviceInput *backCameraInput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *backPreviewLayer;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *frontPreviewLayer;
@property (nonatomic, strong) UIView *previewContainer;

+ (instancetype)sharedInstance;
- (void)toggleDualMode:(UIView *)webView;
- (BOOL)setupDualMode:(UIView *)webView;
- (void)stopDualMode;

@end

@implementation DualModeManager

+ (instancetype)sharedInstance {
    static DualModeManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DualModeManager alloc] init];
    });
    return sharedInstance;
}

- (void)toggleDualMode:(UIView *)webView {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.session && self.session.running) {
            NSLog(@"[DualModeManager] Stopping Dual Mode...");
            [self stopDualMode];
            [self setupDualMode:webView]; // Restart Dual Mode
        } else {
            NSLog(@"[DualModeManager] Restarting Dual Mode...");
            self.session = nil; // Ensure old session is fully reset
            [self setupDualMode:webView];
        }
    });
}

- (BOOL)setupDualMode:(UIView *)webView {
    NSLog(@"[DualModeManager] Setting up Dual Mode...");

    if (!AVCaptureMultiCamSession.isMultiCamSupported) {
        NSLog(@"[DualModeManager] ERROR: MultiCam not supported on this device.");
        return NO;
    }

    // Ensure session is always recreated
    self.session = [[AVCaptureMultiCamSession alloc] init];
    [self.session beginConfiguration];

    @try {
        // Setup Back Camera
        AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
        if (backCamera) {
            AVCaptureDeviceInput *backCameraInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:nil];
            if ([self.session canAddInput:backCameraInput]) {
                [self.session addInput:backCameraInput];
                self.backCameraInput = backCameraInput;
                NSLog(@"[DualModeManager] Back Camera added successfully.");
            } else {
                NSLog(@"[DualModeManager] ERROR: Cannot add back camera input.");
            }
        } else {
            NSLog(@"[DualModeManager] ERROR: Back camera not found.");
        }

        // Setup Front Camera
        AVCaptureDevice *frontCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
        if (frontCamera) {
            AVCaptureDeviceInput *frontCameraInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:nil];
            if ([self.session canAddInput:frontCameraInput]) {
                [self.session addInput:frontCameraInput];
                self.frontCameraInput = frontCameraInput;
                NSLog(@"[DualModeManager] Front Camera added successfully.");
            } else {
                NSLog(@"[DualModeManager] ERROR: Cannot add front camera input.");
            }
        } else {
            NSLog(@"[DualModeManager] ERROR: Front camera not found.");
        }

        [self.session commitConfiguration];
        [self.session startRunning];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupPreviewLayers:webView];
        });

        NSLog(@"[DualModeManager] Dual Mode started successfully.");
        return YES;
    }
    @catch (NSException *exception) {
        NSLog(@"[DualModeManager] ERROR: Failed to setup dual mode - %@", exception.reason);
        [self cleanupOnError];
        return NO;
    }
}

- (void)setupPreviewLayers:(UIView *)webView {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.session || !webView.superview) {
            NSLog(@"[DualModeManager] ERROR: WebView superview not found.");
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

        NSLog(@"[DualModeManager] Preview layers set up successfully.");
    });
}

- (void)stopDualMode {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[DualModeManager] Stopping Dual Mode and cleaning up session...");

        [self.session stopRunning];
        self.session = nil; // Fully release session

        // Remove preview layers safely
        [self.backPreviewLayer removeFromSuperlayer];
        self.backPreviewLayer = nil;

        [self.frontPreviewLayer removeFromSuperlayer];
        self.frontPreviewLayer = nil;

        // ✅ Ensure preview container is removed
        [self.previewContainer removeFromSuperview];
        self.previewContainer = nil;

        NSLog(@"[DualModeManager] Dual Mode fully disabled.");
    });
}

/// Cleans up session in case of error
- (void)cleanupOnError {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[DualModeManager] ERROR: Cleaning up due to failure...");

        [self.session stopRunning];
        self.session = nil; // Fully release session

        [self.backPreviewLayer removeFromSuperlayer];
        self.backPreviewLayer = nil;

        [self.frontPreviewLayer removeFromSuperlayer];
        self.frontPreviewLayer = nil;

        [self.previewContainer removeFromSuperview];
        self.previewContainer = nil;

        NSLog(@"[DualModeManager] Cleanup complete.");
    });
}

@end
