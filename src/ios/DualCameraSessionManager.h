#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface DualCameraSessionManager : NSObject

@property (nonatomic, strong) AVCaptureMultiCamSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *backCameraInput;
@property (nonatomic, strong) AVCaptureDeviceInput *frontCameraInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *backCameraOutput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *frontCameraOutput;
@property (nonatomic, strong) AVCaptureConnection *backCameraConnection;
@property (nonatomic, strong) AVCaptureConnection *frontCameraConnection;

- (void)setupDualCameraSessionWithDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate;
- (void)startSession;
- (void)stopSession;

@end
