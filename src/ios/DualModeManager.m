#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "DualModeManager.h"

@interface DualModeManager () <AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong) AVCapturePhotoOutput *frontPhotoOutput;
@property (nonatomic, strong) AVCapturePhotoOutput *backPhotoOutput;
@property (nonatomic, strong) UIImage *capturedFrontImage;
@property (nonatomic, strong) UIImage *capturedBackImage;
@property (nonatomic, copy) void (^captureCompletion)(UIImage *compositeImage);
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
        if (!self.session && !self.session.isRunning) {
            NSLog(@"[DualModeManager] Stopping Dual Mode...");
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

    self.session = [[AVCaptureMultiCamSession alloc] init];
    [self.session beginConfiguration];

    @try {
        // Remove existing inputs if any.
        if (self.frontCameraInput) {
            [self.session removeInput:self.frontCameraInput];
            self.frontCameraInput = nil;
        }
        if (self.backCameraInput) {
            [self.session removeInput:self.backCameraInput];
            self.backCameraInput = nil;
        }
        
        // Add back camera input.
        AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                         mediaType:AVMediaTypeVideo
                                                                          position:AVCaptureDevicePositionBack];
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
        
        // Add front camera input.
        AVCaptureDevice *frontCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                          mediaType:AVMediaTypeVideo
                                                                           position:AVCaptureDevicePositionFront];
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
        
        // *** Initialize and add photo outputs ***
        self.frontPhotoOutput = [[AVCapturePhotoOutput alloc] init];
        if ([self.session canAddOutput:self.frontPhotoOutput]) {
            [self.session addOutput:self.frontPhotoOutput];
            NSLog(@"[DualModeManager] Front photo output added successfully.");
        } else {
            NSLog(@"[DualModeManager] ERROR: Cannot add front photo output.");
        }
        
        self.backPhotoOutput = [[AVCapturePhotoOutput alloc] init];
        if ([self.session canAddOutput:self.backPhotoOutput]) {
            [self.session addOutput:self.backPhotoOutput];
            NSLog(@"[DualModeManager] Back photo output added successfully.");
        } else {
            NSLog(@"[DualModeManager] ERROR: Cannot add back photo output.");
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
        if (!webView || !webView.superview) {
            NSLog(@"[DualModeManager] ERROR: WebView or superview is nil. Aborting setup.");
            return;
        }
        UIView *rootView = webView.superview;
        [self.previewContainer removeFromSuperview];
        self.previewContainer = [[UIView alloc] initWithFrame:rootView.bounds];
        self.previewContainer.backgroundColor = [UIColor blackColor];
        [rootView insertSubview:self.previewContainer belowSubview:webView];
        self.backPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        self.backPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.backPreviewLayer.frame = self.previewContainer.bounds;
        [self.previewContainer.layer addSublayer:self.backPreviewLayer];

        CGRect frontFrame = CGRectMake(10, 50, 150, 200);
        self.frontPreviewFrame = frontFrame;
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

        if (self.session) {
            [self.session stopRunning];
            self.session = nil;
        }

        if (self.backPreviewLayer) {
            [self.backPreviewLayer removeFromSuperlayer];
            self.backPreviewLayer = nil;
        }

        if (self.frontPreviewLayer) {
            [self.frontPreviewLayer removeFromSuperlayer];
            self.frontPreviewLayer = nil;
        }

        if (self.previewContainer) {
            [self.previewContainer removeFromSuperview];
            self.previewContainer = nil;
        }

        NSLog(@"[DualModeManager] Dual Mode fully disabled.");
    });
}



- (void)cleanupOnError {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[DualModeManager] ERROR: Cleaning up due to failure...");

        if (self.session) {
            [self.session stopRunning];
            self.session = nil;
        }

        if (self.backPreviewLayer) {
            [self.backPreviewLayer removeFromSuperlayer];
            self.backPreviewLayer = nil;
        }

        if (self.frontPreviewLayer) {
            [self.frontPreviewLayer removeFromSuperlayer];
            self.frontPreviewLayer = nil;
        }

        if (self.previewContainer) {
            [self.previewContainer removeFromSuperview];
            self.previewContainer = nil;
        }

        NSLog(@"[DualModeManager] Cleanup complete.");
    });
}

#pragma mark - Dual Image Capture

// Call this method to capture images from both cameras.
// The 'completion' block returns the composite image when both captures are done.
- (void)captureDualImageWithCompletion:(void (^)(UIImage *compositeImage))completion {
    
    NSLog(@"Jatin 2 captureDual Dual mode manager");
    // Reset any previously captured images.
    self.capturedFrontImage = nil;
    self.capturedBackImage = nil;
    self.captureCompletion = completion;
    
    // Create photo settings.
    AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
    
    // Start capturing from both outputs concurrently.
    [self.frontPhotoOutput capturePhotoWithSettings:settings delegate:self];
    [self.backPhotoOutput capturePhotoWithSettings:settings delegate:self];
}

// Delegate method called when a photo has been captured.
- (void)captureOutput:(AVCapturePhotoOutput *)output
didFinishProcessingPhoto:(AVCapturePhoto *)photo
             error:(NSError *)error {
    NSLog(@"Jatin 3 capture output Dual mode manager");
    if (error) {
        NSLog(@"[DualModeManager] ERROR capturing photo: %@", error);
        return;
    }
    
    NSData *imageData = [photo fileDataRepresentation];
    UIImage *capturedImage = [UIImage imageWithData:imageData];
    
    // Determine which output produced this image.
    if (output == self.frontPhotoOutput) {
        self.capturedFrontImage = capturedImage;
        NSLog(@"[DualModeManager] Captured front image.");
    } else if (output == self.backPhotoOutput) {
        self.capturedBackImage = capturedImage;
        NSLog(@"[DualModeManager] Captured back image.");
    }
    
    if (self.capturedFrontImage && self.capturedBackImage && self.captureCompletion) {
        // Swap the parameters to use the back camera image as the background and the front camera image as overlay.
        UIImage *compositeImage = [self compositeImageWithBackImage:self.capturedFrontImage
                                                            frontImage:self.capturedBackImage];
        self.captureCompletion(compositeImage);
        self.captureCompletion = nil;
    }

}

- (UIImage *)compositeImageWithBackImage:(UIImage *)backImage frontImage:(UIImage *)frontImage {
    // Use the back image's resolution as the composite image size.
    CGSize compositeSize = backImage.size;
    UIGraphicsBeginImageContextWithOptions(compositeSize, YES, 0);
    
    // Draw the back image full-screen.
    [backImage drawInRect:CGRectMake(0, 0, compositeSize.width, compositeSize.height)];
    
    // Get the preview container's size (from the UI).
    CGSize previewSize = self.previewContainer.bounds.size;
    
    // Compute scaling factors to convert from preview coordinates to composite image coordinates.
    CGFloat scaleX = compositeSize.width / previewSize.width;
    CGFloat scaleY = compositeSize.height / previewSize.height;
    
    // Calculate the initial overlay rect by scaling the stored front preview frame.
    CGRect overlayRect = CGRectMake(self.frontPreviewFrame.origin.x * scaleX,
                                    self.frontPreviewFrame.origin.y * scaleY,
                                    self.frontPreviewFrame.size.width * scaleX,
                                    self.frontPreviewFrame.size.height * scaleY);
    
    // Preserve the front image's aspect ratio using an aspect-fit approach.
    CGSize frontSize = frontImage.size;
    CGFloat frontAspect = frontSize.width / frontSize.height;
    CGFloat overlayAspect = overlayRect.size.width / overlayRect.size.height;
    
    if (fabs(frontAspect - overlayAspect) > 0.01) {
        if (frontAspect > overlayAspect) {
            // Front image is wider than the overlay: adjust the height.
            CGFloat newOverlayHeight = overlayRect.size.width / frontAspect;
            CGFloat yOffset = (overlayRect.size.height - newOverlayHeight) / 2.0;
            overlayRect = CGRectMake(overlayRect.origin.x, overlayRect.origin.y + yOffset,
                                     overlayRect.size.width, newOverlayHeight);
        } else {
            // Front image is taller than the overlay: adjust the width.
            CGFloat newOverlayWidth = overlayRect.size.height * frontAspect;
            CGFloat xOffset = (overlayRect.size.width - newOverlayWidth) / 2.0;
            overlayRect = CGRectMake(overlayRect.origin.x + xOffset, overlayRect.origin.y,
                                     newOverlayWidth, overlayRect.size.height);
        }
    }
    
    // Increase the overlay size a bit (e.g. 10% larger) while recentering it.
    CGFloat expansionFactor = 1.4; // 10% increase
    overlayRect = CGRectMake(overlayRect.origin.x - (overlayRect.size.width * (expansionFactor - 1) / 2.0),
                             overlayRect.origin.y - (overlayRect.size.height * (expansionFactor - 1) / 2.0),
                             overlayRect.size.width * expansionFactor,
                             overlayRect.size.height * expansionFactor);
    
    // Draw the front image into the adjusted overlay rect.
    [frontImage drawInRect:overlayRect];
    
    UIImage *combinedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return combinedImage;
}


@end
