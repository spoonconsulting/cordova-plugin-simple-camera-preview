#import <CoreImage/CoreImage.h>
#import <AVFoundation/AVFoundation.h>


@interface CameraSessionManager : NSObject

- (CameraSessionManager *)init;
- (void) setupSession:(NSDictionary *)options completion:(void(^)(BOOL started))completion photoSettings:(AVCapturePhotoSettings *)photoSettings;
- (void) setFlashMode:(NSInteger)flashMode photoSettings:(AVCapturePhotoSettings *)photoSettings;
- (void) torchSwitch:(NSInteger)torchState;
- (void) switchCameraTo:(NSDictionary *)options completion:(void (^)(BOOL success))completion;
- (BOOL) deviceHasUltraWideCamera;
- (void) deallocSession;
- (void) updateOrientation:(AVCaptureVideoOrientation)orientation;
- (void) startRecording:(NSURL *)fileURL recordingDelegate:(id<AVCaptureFileOutputRecordingDelegate>)recordingDelegate videoDurationMs:(NSInteger)videoDuration;
- (void) stopRecording;
- (void) setupPhotoOutput;
- (AVCaptureVideoOrientation) getCurrentOrientation:(UIInterfaceOrientation)toInterfaceOrientation;
+ (AVCaptureSessionPreset) calculateResolution:(NSInteger)targetSize;
- (UIInterfaceOrientation) getOrientation;

@property (atomic) CIFilter *ciFilter;
@property (nonatomic) NSLock *filterLock;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureDevicePosition defaultCamera;
@property (nonatomic) NSInteger defaultFlashMode;
@property (nonatomic) AVCaptureDevice *device;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCapturePhotoOutput *imageOutput;
@property (nonatomic) AVCaptureVideoDataOutput *dataOutput;
@property (nonatomic, weak) id delegate;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) NSTimer *videoTimer;
@end
