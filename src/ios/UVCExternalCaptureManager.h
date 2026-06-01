#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

@protocol UVCExternalCaptureDelegate <NSObject>
- (void)uvcCaptureManager:(id)manager didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

/// Discovers and captures UVC HDMI capture cards on iPhone via IOKit/libusb-style USB access.
/// On iPadOS 17+ prefer AVFoundation external cameras via CameraSessionManager.
@interface UVCExternalCaptureManager : NSObject

@property (nonatomic, weak) id<UVCExternalCaptureDelegate> delegate;
@property (nonatomic, readonly) BOOL isCapturing;
@property (nonatomic, readonly, nullable) NSData *latestJPEGFrame;

+ (BOOL)isUVCCaptureCardAvailable;
+ (nullable AVCaptureDevice *)externalAVCaptureDevice;

- (instancetype)initWithDelegate:(id<UVCExternalCaptureDelegate>)delegate;
- (BOOL)startCaptureWithError:(NSError **)error;
- (void)stopCapture;

@end
