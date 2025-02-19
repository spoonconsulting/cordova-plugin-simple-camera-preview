#import "DualCameraRenderController.h"

@interface DualCameraRenderController ()
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *backPreviewLayer;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *frontPreviewLayer;
@end

@implementation DualCameraRenderController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
}

// This method configures two preview layers from the same multi-cam session.
- (void)setUpWithMultiCamSession:(AVCaptureMultiCamSession *)session {
    // Remove any existing preview layers
    for (CALayer *layer in self.view.layer.sublayers) {
        [layer removeFromSuperlayer];
    }
    
    // Create the back preview layer (full screen)
    self.backPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    self.backPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.backPreviewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:self.backPreviewLayer];
    
    // Create the front preview layer (small picture-in-picture)
    self.frontPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    self.frontPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.frontPreviewLayer.frame = CGRectMake(10, 10, 120, 160);
    // Optional styling:
    self.frontPreviewLayer.borderWidth = 1.0;
    self.frontPreviewLayer.borderColor = [UIColor whiteColor].CGColor;
    [self.view.layer addSublayer:self.frontPreviewLayer];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Ensure the back preview layer always fills the view.
    self.backPreviewLayer.frame = self.view.bounds;
}

@end
