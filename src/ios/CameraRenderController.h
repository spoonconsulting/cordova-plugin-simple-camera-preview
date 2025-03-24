#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

#import "CameraSessionManager.h"

@protocol TakePictureDelegate
- (void) capture;
@end;

@interface CameraRenderController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate> {
  GLuint _renderBuffer;
  CVOpenGLESTextureCacheRef _videoTextureCache;
  CVOpenGLESTextureRef _lumaTexture;
}

-(void) deallocateRenderMemory;

@property (nonatomic) CameraSessionManager *sessionManager;
@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (nonatomic) CIContext *ciContext;
@property (nonatomic) CIImage *latestFrame;
@property (nonatomic) EAGLContext *context;
@property (nonatomic) CVPixelBufferRef pixelBuffer;
@property (nonatomic) NSLock *renderLock;

@end
