#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DualCameraRenderController : UIViewController

- (void)setUpWithMultiCamSession:(AVCaptureMultiCamSession *)session;

@end

NS_ASSUME_NONNULL_END
