#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MultiCamSessionManager : NSObject

@property (nonatomic, strong) AVCaptureMultiCamSession *multiCamSession;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;

- (instancetype)init;
- (void)setupSessionWithCompletion:(void(^)(BOOL success))completion;
- (void)startRunning;
- (void)stopRunning;

@end

NS_ASSUME_NONNULL_END
