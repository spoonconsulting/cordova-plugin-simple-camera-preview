#import <CoreImage/CoreImage.h>
#import <AVFoundation/AVFoundation.h>


@interface CameraSessionManager : NSObject

- (CameraSessionManager *)init;
- (void) setupSession:(NSDictionary *)options completion:(void(^)(BOOL started))completion photoSettings:(AVCapturePhotoSettings *)photoSettings;
- (void) setFlashMode:(NSInteger)flashMode photoSettings:(AVCapturePhotoSettings *)photoSettings completion:(void(^) (BOOL success)) completion;
- (void)torchSwitch:(NSInteger)torchState completion:(void (^)(BOOL success, NSError *error))completion;
- (void) switchCameraTo:(NSDictionary *)options completion:(void (^)(BOOL success))completion;
- (BOOL) deviceHasUltraWideCamera;
- (BOOL) deviceHasFrontCamera;
- (BOOL) deviceHasFlash;
- (void) deallocSession;
- (void) updateOrientation:(AVCaptureVideoOrientation)orientation;
- (void) startRecording:(NSURL *)fileURL recordingDelegate:(id<AVCaptureFileOutputRecordingDelegate>)recordingDelegate videoDurationMs:(NSInteger)videoDuration;
- (void) stopRecording;
- (void) startSession;
- (AVCaptureVideoOrientation) getCurrentOrientation:(UIInterfaceOrientation)toInterfaceOrientation;
- (AVCaptureSessionPreset)calculateResolution:(NSInteger)targetSize aspectRatio:(NSString *)aspectRatio;
- (UIInterfaceOrientation) getOrientation;
- (AVCaptureSessionPreset)validateCameraPreset:(AVCaptureSessionPreset)preset;

@property (atomic) CIFilter *ciFilter;
@property (nonatomic) NSLock *filterLock;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) AVCaptureDevicePosition defaultCamera;
@property (nonatomic) NSInteger defaultFlashMode;
@property (nonatomic) bool audioConfigured;
@property (nonatomic) AVCaptureDevice *device;
@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic) AVCapturePhotoOutput *imageOutput;
@property (nonatomic) AVCaptureVideoDataOutput *dataOutput;
@property (nonatomic, weak) id delegate;
@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) NSTimer *videoTimer;
@property (nonatomic) NSInteger targetSize;
@property (nonatomic) NSString *aspectRatio;
@property (atomic, assign) BOOL isCameraDirectionFront;
@end
