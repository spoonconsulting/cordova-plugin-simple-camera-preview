#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "DualModeManager.h"
#import <GLKit/GLKit.h>
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <OpenGLES/ES2/glext.h>

@implementation DualModeManager

- (instancetype)init {
    if (self = [super init]) {
        self.session = [[AVCaptureMultiCamSession alloc] init];
        self.sessionQueue = dispatch_queue_create("DualModeManager.sessionQueue", DISPATCH_QUEUE_SERIAL);
        self.filterLock = [[NSLock alloc] init];
        self.renderLock = [[NSLock alloc] init];

        // OpenGL & Core Image setup
        self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
        if (!self.context) {
            NSLog(@"[DualModeManager] ERROR: Failed to create OpenGL context");
        } else {
            self.ciContext = [CIContext contextWithEAGLContext:self.context];
            CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.context, NULL, &_videoTextureCache);
            if (err) {
                NSLog(@"[DualModeManager] ERROR: OpenGL texture cache creation failed: %d", err);
            }
        }
        NSLog(@"[DualModeManager] OpenGL Context Initialized");
    }
    return self;
}

- (void)toggleDualMode:(UIView *)webView {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.session || !self.session.isRunning) {
            NSLog(@"[DualModeManager] Starting Dual Mode...");
            [self setupDualMode:webView];
        } else {
            NSLog(@"[DualModeManager] Stopping Dual Mode...");
            [self stopDualMode];
        }
    });
}

- (BOOL)setupDualMode:(UIView *)webView {
    NSLog(@"[DualModeManager] Setting up Dual Mode...");

    if (!AVCaptureMultiCamSession.isMultiCamSupported) {
        NSLog(@"ERROR: MultiCam not supported on this device.");
        return NO;
    }

    [self.session beginConfiguration];

    @try {
        [self cleanupSession];

        if (![self addBackCamera]) return NO;
        if (![self addFrontCamera]) return NO;

        [self setupPhotoOutputs];

        [self.session commitConfiguration];
        [self.session startRunning];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupPreviewLayers:webView];
        });

        NSLog(@"Dual Mode started successfully.");
        return YES;
    }
    @catch (NSException *exception) {
        NSLog(@"ERROR: Failed to setup dual mode - %@", exception.reason);
        [self cleanupOnError];
        return NO;
    }
}



- (void)setupVideoOutputs {
    dispatch_async(self.sessionQueue, ^{
        AVCaptureVideoDataOutput *frontVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
        AVCaptureVideoDataOutput *backVideoOutput = [[AVCaptureVideoDataOutput alloc] init];

        // Configure pixel buffer format
        NSDictionary *videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
        frontVideoOutput.videoSettings = videoSettings;
        backVideoOutput.videoSettings = videoSettings;

        dispatch_queue_t videoQueue = dispatch_queue_create("videoFrameQueue", DISPATCH_QUEUE_SERIAL);
        [frontVideoOutput setSampleBufferDelegate:self queue:videoQueue];
        [backVideoOutput setSampleBufferDelegate:self queue:videoQueue];

        // Add video outputs to the session
        if ([self.session canAddOutput:frontVideoOutput]) {
            [self.session addOutput:frontVideoOutput];
            NSLog(@"[DualModeManager] Front video output added.");
        } else {
            NSLog(@"[DualModeManager] ERROR: Cannot add front video output.");
        }

        if ([self.session canAddOutput:backVideoOutput]) {
            [self.session addOutput:backVideoOutput];
            NSLog(@"[DualModeManager] Back video output added.");
        } else {
            NSLog(@"[DualModeManager] ERROR: Cannot add back video output.");
        }
    });
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if ([self.renderLock tryLock]) {
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffer];

        //NSLog(@"[DualModeManager] Frame received from %@", (connection == [self.frontPhotoOutput connectionWithMediaType:AVMediaTypeVideo]) ? @"FRONT" : @"BACK");

        // Rotate image for correct portrait orientation
        CGAffineTransform rotation = CGAffineTransformMakeRotation(M_PI_2);
        CIImage *rotatedImage = [image imageByApplyingTransform:rotation];

        if (connection == [self.frontPhotoOutput connectionWithMediaType:AVMediaTypeVideo]) {
            NSLog(@"[DualModeManager] Processing front camera frame...");
            self.latestFrontFrame = rotatedImage;
        } else if (connection == [self.backPhotoOutput connectionWithMediaType:AVMediaTypeVideo]) {
            NSLog(@"[DualModeManager] Processing back camera frame...");
            self.latestBackFrame = rotatedImage;
        }

        [self.renderLock unlock];
    }
}



- (UIImage *)imageFromCIImage:(CIImage *)ciImage {
    CGImageRef cgImage = [self.ciContext createCGImage:ciImage fromRect:ciImage.extent];
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return image;
}



// MARK: - Camera Setup Methods

- (BOOL)addBackCamera {
    AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                     mediaType:AVMediaTypeVideo
                                                                      position:AVCaptureDevicePositionBack];

    if (!backCamera) {
        NSLog(@"[DualModeManager] ERROR: Back camera not found.");
        return NO;
    }

    NSError *error = nil;
    self.backCameraInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];

    if (error || ![self.session canAddInput:self.backCameraInput]) {
        NSLog(@"[DualModeManager] ERROR: Cannot add back camera input.");
        return NO;
    }

    [self.session addInputWithNoConnections:self.backCameraInput];
    NSLog(@"[DualModeManager] Back Camera added successfully.");
    return YES;
}

- (BOOL)addFrontCamera {
    AVCaptureDevice *frontCamera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                      mediaType:AVMediaTypeVideo
                                                                       position:AVCaptureDevicePositionFront];
    if (!frontCamera) {
        NSLog(@"[DualModeManager] ERROR: Front camera not found.");
        return NO;
    }

    NSError *error = nil;
    self.frontCameraInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error:&error];

    if (error || ![self.session canAddInput:self.frontCameraInput]) {
        NSLog(@"[DualModeManager] ERROR: Cannot add front camera input.");
        return NO;
    }

    [self.session addInputWithNoConnections:self.frontCameraInput];
    NSLog(@"[DualModeManager] Front Camera added successfully.");
    return YES;
}

- (void)setupPhotoOutputs {
    NSLog(@"[DualModeManager] Setting up photo outputs...");

    self.frontPhotoOutput = [[AVCapturePhotoOutput alloc] init];
    self.backPhotoOutput = [[AVCapturePhotoOutput alloc] init];

    self.frontPhotoOutput.highResolutionCaptureEnabled = YES;
    self.backPhotoOutput.highResolutionCaptureEnabled = YES;

    if ([self.session canAddOutput:self.frontPhotoOutput]) {
        [self.session addOutput:self.frontPhotoOutput];
        NSLog(@"Front photo output added.");
    } else {
        NSLog(@"ERROR: Cannot add front photo output.");
    }

    if ([self.session canAddOutput:self.backPhotoOutput]) {
        [self.session addOutput:self.backPhotoOutput];
        NSLog(@"Back photo output added.");
    } else {
        NSLog(@"ERROR: Cannot add back photo output.");
    }

    // Ensure connections are properly created
    AVCaptureConnection *frontConnection = [self.frontPhotoOutput connectionWithMediaType:AVMediaTypeVideo];
    AVCaptureConnection *backConnection = [self.backPhotoOutput connectionWithMediaType:AVMediaTypeVideo];

    if (frontConnection) {
        frontConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
        NSLog(@"Front photo connection established.");
    } else {
        NSLog(@"ERROR: Front camera connection failed.");
    }

    if (backConnection) {
        backConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
        NSLog(@"Back photo connection established.");
    } else {
        NSLog(@"ERROR: Back camera connection failed.");
    }
}



// MARK: - Setup Preview Layers

- (void)setupPreviewLayers:(UIView *)webView {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!webView || !webView.superview) {
            NSLog(@"[DualModeManager] ERROR: WebView or superview is nil. Aborting setup.");
            return;
        }

        webView.opaque = NO;
        webView.backgroundColor = [UIColor clearColor];

        UIView *rootView = webView.superview;
        [self.previewContainer removeFromSuperview];

        self.previewContainer = [[UIView alloc] initWithFrame:rootView.bounds];
        self.previewContainer.backgroundColor = [UIColor blackColor];
        [rootView insertSubview:self.previewContainer belowSubview:webView];

        // Ensure back preview layer is set
        if (!self.backPreviewLayer) {
            self.backPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
            self.backPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
        self.backPreviewLayer.frame = self.previewContainer.bounds;
        [self.previewContainer.layer addSublayer:self.backPreviewLayer];

        // Ensure front preview layer is set
        CGRect frontFrame = CGRectMake(10, 50, 150, 200);
        self.frontPreviewFrame = frontFrame;
        UIView *frontView = [[UIView alloc] initWithFrame:frontFrame];
        frontView.backgroundColor = [UIColor clearColor];
        [self.previewContainer addSubview:frontView];

        if (!self.frontPreviewLayer) {
            self.frontPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
            self.frontPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
        self.frontPreviewLayer.frame = frontView.bounds;
        self.frontPreviewLayer.cornerRadius = 10;
        self.frontPreviewLayer.masksToBounds = YES;
        [frontView.layer addSublayer:self.frontPreviewLayer];

        NSLog(@"Preview layers set up successfully.");
    });
}


- (void)captureDualImageWithCompletion:(void (^)(UIImage *compositeImage))completion {
    NSLog(@"[DualModeManager] 📸 Capturing Dual Mode Image...");

    if (!self.session.isRunning) {
        NSLog(@"ERROR: Capture session is not running!");
        return;
    }

    if (!self.frontPhotoOutput || !self.backPhotoOutput) {
        NSLog(@"ERROR: Photo outputs are not available!");
        return;
    }

    self.capturedFrontImage = nil;
    self.capturedBackImage = nil;
    self.captureCompletion = completion;

    AVCapturePhotoSettings *frontSettings = [AVCapturePhotoSettings photoSettings];
    AVCapturePhotoSettings *backSettings = [AVCapturePhotoSettings photoSettings];

    frontSettings.highResolutionPhotoEnabled = YES;
    backSettings.highResolutionPhotoEnabled = YES;

    if (self.frontPhotoOutput) {
        [self.frontPhotoOutput capturePhotoWithSettings:frontSettings delegate:self];
    } else {
        NSLog(@"ERROR: Front camera capture failed.");
    }

    if (self.backPhotoOutput) {
        [self.backPhotoOutput capturePhotoWithSettings:backSettings delegate:self];
    } else {
        NSLog(@"ERROR: Back camera capture failed.");
    }
}

// Delegate method called when a photo has been captured.
- (void)captureOutput:(AVCapturePhotoOutput *)output
didFinishProcessingPhoto:(AVCapturePhoto *)photo
             error:(NSError *)error {
    
    if (error) {
        NSLog(@"ERROR capturing photo: %@", error.localizedDescription);
        return;
    }

    NSData *imageData = [photo fileDataRepresentation];
    UIImage *capturedImage = [UIImage imageWithData:imageData];

    if (!capturedImage) {
        NSLog(@"ERROR: Failed to generate image from photo data.");
        return;
    }

    // Identify the source of the image
    if (output == self.frontPhotoOutput) {
        NSLog(@"Captured front image.");
        self.capturedFrontImage = capturedImage;
    } else if (output == self.backPhotoOutput) {
        NSLog(@"Captured back image.");
        self.capturedBackImage = capturedImage;
    }

    // Once both images are captured, merge them
    if (self.capturedFrontImage && self.capturedBackImage) {
        NSLog(@"[DualModeManager]  Merging images...");
        UIImage *compositeImage = [self compositeImageWithBackImage:self.capturedBackImage frontImage:self.capturedFrontImage];

        if (self.captureCompletion) {
            self.captureCompletion(compositeImage);
            self.captureCompletion = nil;
        }
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

// MARK: - Stop & Cleanup

- (void)stopDualMode {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[DualModeManager] Stopping Dual Mode...");
        [self.session stopRunning];
        self.session = nil;
        [self cleanupPreviewLayers];
        NSLog(@"[DualModeManager] Dual Mode disabled.");
    });
}

- (void)cleanupOnError {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[DualModeManager] Cleaning up due to error...");
        [self stopDualMode];
    });
}

- (void)cleanupPreviewLayers {
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
}

// MARK: - Session Cleanup

- (void)cleanupSession {
    if (self.frontCameraInput) {
        [self.session removeInput:self.frontCameraInput];
        self.frontCameraInput = nil;
    }
    if (self.backCameraInput) {
        [self.session removeInput:self.backCameraInput];
        self.backCameraInput = nil;
    }
}


- (void)deallocSession {
    dispatch_async(self.sessionQueue, ^{
        if (!self.session) {
            NSLog(@"[DualModeManager] Session already deallocated, skipping cleanup.");
            return;
        }

        NSLog(@"[DualModeManager] Stopping session...");

        if (self.session.isRunning) {
            [self.session stopRunning];
        }

        // Remove observers safely
        NSLog(@"[DualModeManager] Removing observers...");
        for (AVCaptureConnection *connection in self.session.connections) {
            [self safeRemoveObserver:self forKeyPath:@"enabled" fromObject:connection];
        }

        // Remove all inputs safely
        NSArray *inputs = [self.session.inputs copy];
        for (AVCaptureInput *input in inputs) {
            [self.session removeInput:input];
        }

        // Remove all outputs safely
        NSArray *outputs = [self.session.outputs copy];
        for (AVCaptureOutput *output in outputs) {
            [self.session removeOutput:output];
        }

        NSLog(@"[DualModeManager] Cleaning up references...");

        // Clear references **before setting session to nil**
        self.frontCameraInput = nil;
        self.backCameraInput = nil;
        self.frontPhotoOutput = nil;
        self.backPhotoOutput = nil;
        self.filterLock = nil;

        // Nullify session safely
        AVCaptureMultiCamSession *oldSession = self.session;
        self.session = nil;

        // Ensure oldSession is released properly before clearing queue
        oldSession = nil;

        // Clear session queue and device references
        self.device = nil;

        NSLog(@"[DualModeManager] Session deallocated successfully.");
    });
}

- (void)safeRemoveObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath fromObject:(NSObject *)object {
    @try {
        [object removeObserver:observer forKeyPath:keyPath];
        NSLog(@"[DualModeManager] Successfully removed observer for keyPath: %@", keyPath);
    } @catch (NSException *exception) {
        NSLog(@"[DualModeManager] WARNING: Tried to remove a non-existent observer for keyPath: %@", keyPath);
    }
}

@end
