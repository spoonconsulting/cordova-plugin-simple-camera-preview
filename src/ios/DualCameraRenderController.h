#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <AVFoundation/AVFoundation.h>
#import "DualCameraSessionManager.h"

@interface DualCameraRenderController : GLKViewController <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) DualCameraSessionManager *sessionManager;
@property (nonatomic, strong) NSLock *renderLock;
@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, assign) CVPixelBufferRef backPixelBuffer;
@property (nonatomic, assign) CVPixelBufferRef frontPixelBuffer;

- (void)setupDualCamera;
- (void)stopDualCamera;

@end
