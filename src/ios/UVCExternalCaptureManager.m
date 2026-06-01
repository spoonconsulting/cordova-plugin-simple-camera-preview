#import "UVCExternalCaptureManager.h"
#import "libusb.h"
#import <dlfcn.h>
#import <mach/mach.h>
#import <ImageIO/ImageIO.h>
#import <CoreVideo/CoreVideo.h>
#import <UIKit/UIKit.h>

typedef mach_port_t io_object_t;
typedef mach_port_t io_registry_entry_t;
typedef char io_name_t[128];
static const mach_port_t kUVCIOMasterPort = MACH_PORT_NULL;

// Common UVC HDMI capture card VID/PID values (MacroSilicon, Generic, etc.)
static const uint16_t kDefaultVendorIDs[] = { 0x534D, 0x1BCF, 0x0FD9, 0x345F, 0x32E4, 0 };
static const uint16_t kDefaultProductIDs[] = { 0x2109, 0x2C99, 0x006C, 0x2130, 0x9410, 0 };

#pragma mark - IOKit dynamic loading (device discovery on iPhone)

typedef mach_port_t io_service_t;
typedef mach_port_t io_iterator_t;
typedef uint32_t IOOptionBits;

typedef kern_return_t (*IOObjectReleaseFunc)(io_object_t object);
typedef kern_return_t (*IOIteratorNextFunc)(io_iterator_t iterator);
typedef kern_return_t (*IOServiceGetMatchingServicesFunc)(mach_port_t masterPort, CFDictionaryRef matching, io_iterator_t *existing);
typedef CFMutableDictionaryRef (*IOServiceMatchingFunc)(const char *name);
typedef CFTypeRef (*IORegistryEntryCreateCFPropertyFunc)(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, IOOptionBits options);

static IOObjectReleaseFunc IOObjectReleasePtr = NULL;
static IOIteratorNextFunc IOIteratorNextPtr = NULL;
static IOServiceGetMatchingServicesFunc IOServiceGetMatchingServicesPtr = NULL;
static IOServiceMatchingFunc IOServiceMatchingPtr = NULL;
static IORegistryEntryCreateCFPropertyFunc IORegistryEntryCreateCFPropertyPtr = NULL;
static void *IOKitHandle = NULL;

static BOOL UVCLoadIOKit(void) {
    if (IOKitHandle) return YES;
    IOKitHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
    if (!IOKitHandle) return NO;

    IOObjectReleasePtr = (IOObjectReleaseFunc)dlsym(IOKitHandle, "IOObjectRelease");
    IOIteratorNextPtr = (IOIteratorNextFunc)dlsym(IOKitHandle, "IOIteratorNext");
    IOServiceGetMatchingServicesPtr = (IOServiceGetMatchingServicesFunc)dlsym(IOKitHandle, "IOServiceGetMatchingServices");
    IOServiceMatchingPtr = (IOServiceMatchingFunc)dlsym(IOKitHandle, "IOServiceMatching");
    IORegistryEntryCreateCFPropertyPtr = (IORegistryEntryCreateCFPropertyFunc)dlsym(IOKitHandle, "IORegistryEntryCreateCFProperty");

    return IOObjectReleasePtr && IOIteratorNextPtr &&
           IOServiceGetMatchingServicesPtr && IOServiceMatchingPtr && IORegistryEntryCreateCFPropertyPtr;
}

#pragma mark - UVCExternalCaptureManager

@interface UVCExternalCaptureManager ()
@property (nonatomic, readwrite) BOOL isCapturing;
@property (nonatomic, readwrite, nullable) NSData *latestJPEGFrame;
@property (nonatomic) dispatch_queue_t captureQueue;
@property (nonatomic) NSMutableData *frameBuffer;
@property (nonatomic) uint8_t currentFID;
@property (nonatomic) BOOL hasCurrentFrame;
@property (nonatomic) int streamingInterface;
@property (nonatomic) unsigned char bulkEndpoint;
@property (nonatomic) libusb_context *libusbCtx;
@property (nonatomic) libusb_device_handle *libusbHandle;
@end

@implementation UVCExternalCaptureManager

+ (nullable AVCaptureDevice *)externalAVCaptureDevice {
    if (@available(iOS 17.0, *)) {
        NSArray<AVCaptureDeviceType> *deviceTypes = @[AVCaptureDeviceTypeExternal];
        AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession
            discoverySessionWithDeviceTypes:deviceTypes
            mediaType:AVMediaTypeVideo
            position:AVCaptureDevicePositionUnspecified];
        for (AVCaptureDevice *device in session.devices) {
            if ([device hasMediaType:AVMediaTypeVideo]) {
                return device;
            }
        }
    }
    return nil;
}

+ (BOOL)isUVCCaptureCardAvailable {
    return [self libusbUVCCardPresent] || [self iokitUVCCardPresent];
}

+ (BOOL)iokitUVCCardPresent {
    if (!UVCLoadIOKit()) return NO;

    CFMutableDictionaryRef matching = IOServiceMatchingPtr("IOUSBHostDevice");
    if (!matching) return NO;

    io_iterator_t iterator = 0;
    if (IOServiceGetMatchingServicesPtr(kUVCIOMasterPort, matching, &iterator) != KERN_SUCCESS) {
        return NO;
    }

    io_service_t device;
    BOOL found = NO;
    while ((device = IOIteratorNextPtr(iterator)) != 0) {
        NSNumber *vendorID = (__bridge NSNumber *)IORegistryEntryCreateCFPropertyPtr(
            device, CFSTR("idVendor"), kCFAllocatorDefault, 0);
        NSNumber *productID = (__bridge NSNumber *)IORegistryEntryCreateCFPropertyPtr(
            device, CFSTR("idProduct"), kCFAllocatorDefault, 0);
        if (vendorID && productID) {
            uint16_t vid = [vendorID unsignedShortValue];
            uint16_t pid = [productID unsignedShortValue];
            for (int i = 0; kDefaultVendorIDs[i] != 0; i++) {
                if (vid == kDefaultVendorIDs[i] && (kDefaultProductIDs[i] == 0 || pid == kDefaultProductIDs[i])) {
                    found = YES;
                    break;
                }
            }
        }
        if (vendorID) CFRelease((__bridge CFTypeRef)vendorID);
        if (productID) CFRelease((__bridge CFTypeRef)productID);
        IOObjectReleasePtr(device);
        if (found) break;
    }
    IOObjectReleasePtr(iterator);
    return found;
}

+ (BOOL)libusbUVCCardPresent {
    libusb_context *ctx = NULL;
    if (libusb_init(&ctx) < 0) return NO;

    BOOL found = NO;
    for (int i = 0; kDefaultVendorIDs[i] != 0; i++) {
        libusb_device_handle *handle = libusb_open_device_with_vid_pid(ctx, kDefaultVendorIDs[i], kDefaultProductIDs[i]);
        if (handle) {
            libusb_close(handle);
            found = YES;
            break;
        }
    }
    libusb_exit(ctx);
    return found;
}

- (instancetype)initWithDelegate:(id<UVCExternalCaptureDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
        _captureQueue = dispatch_queue_create("com.spoon.uvc.capture", DISPATCH_QUEUE_SERIAL);
        _frameBuffer = [NSMutableData data];
        _streamingInterface = 1;
        _bulkEndpoint = 0x82;
        _currentFID = 0xFF;
    }
    return self;
}

- (BOOL)startCaptureWithError:(NSError **)error {
    if (self.isCapturing) return YES;

    if (![self openLibusbDevice]) {
        if ([UVCExternalCaptureManager iokitUVCCardPresent]) {
            if (error) {
                *error = [NSError errorWithDomain:@"UVCExternalCapture"
                                             code:2
                                         userInfo:@{NSLocalizedDescriptionKey: @"UVC capture card detected but could not be opened. Ensure the capture card is connected and camera permission is granted."}];
            }
        } else if (error) {
            *error = [NSError errorWithDomain:@"UVCExternalCapture"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"No UVC HDMI capture card found."}];
        }
        return NO;
    }

    self.isCapturing = YES;
    self.frameBuffer.length = 0;
    self.hasCurrentFrame = NO;
    self.currentFID = 0xFF;

    dispatch_async(self.captureQueue, ^{
        [self captureLoop];
    });
    return YES;
}

- (BOOL)openLibusbDevice {
    if (self.libusbCtx == NULL && libusb_init(&_libusbCtx) < 0) return NO;

    for (int i = 0; kDefaultVendorIDs[i] != 0; i++) {
        self.libusbHandle = libusb_open_device_with_vid_pid(self.libusbCtx, kDefaultVendorIDs[i], kDefaultProductIDs[i]);
        if (self.libusbHandle) {
            if (libusb_claim_interface(self.libusbHandle, self.streamingInterface) == 0) {
                return YES;
            }
            libusb_close(self.libusbHandle);
            self.libusbHandle = NULL;
        }
    }
    return NO;
}

- (void)captureLoop {
    uint8_t buffer[16384];

    while (self.isCapturing) {
        int transferred = 0;
        int result = libusb_bulk_transfer(self.libusbHandle, self.bulkEndpoint, buffer, (int)sizeof(buffer), &transferred, 1000);

        if (result == 0 && transferred > 0) {
            [self processRawUVCBuffer:buffer length:transferred];
        }
    }
}

- (void)processRawUVCBuffer:(uint8_t *)buffer length:(int)length {
    int offset = 0;
    while (offset < length) {
        if (length - offset < 2) break;

        uint8_t headerLen = buffer[offset];
        if (headerLen < 2 || headerLen > 64 || offset + headerLen > length) {
            offset++;
            continue;
        }

        uint8_t headerInfo = buffer[offset + 1];
        uint8_t fid = headerInfo & 0x01;
        BOOL eof = (headerInfo & 0x02) != 0;
        int payloadOffset = offset + headerLen;
        int payloadLength = length - payloadOffset;

        if (fid != self.currentFID) {
            self.frameBuffer.length = 0;
            self.currentFID = fid;
            self.hasCurrentFrame = YES;
        }

        if (payloadLength > 0 && self.hasCurrentFrame) {
            [self.frameBuffer appendBytes:buffer + payloadOffset length:payloadLength];
        }

        if (eof && self.frameBuffer.length > 4) {
            const uint8_t *bytes = (const uint8_t *)self.frameBuffer.bytes;
            if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
                NSData *jpegData = [self.frameBuffer copy];
                [self deliverJPEGFrame:jpegData];
            }
            self.frameBuffer.length = 0;
            self.hasCurrentFrame = NO;
        }

        offset = payloadOffset + payloadLength;
    }
}

- (void)deliverJPEGFrame:(NSData *)jpegData {
    self.latestJPEGFrame = jpegData;

    CVPixelBufferRef pixelBuffer = NULL;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)jpegData, NULL);
    if (!source) return;

    CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, NULL);
    CFRelease(source);
    if (!image) return;

    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);

    NSDictionary *attrs = @{(__bridge NSString *)kCVPixelBufferCGImageCompatibilityKey: @YES,
                            (__bridge NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES};
    CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)attrs, &pixelBuffer);
    if (!pixelBuffer) {
        CGImageRelease(image);
        return;
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pixelBuffer);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, width, height, 8, CVPixelBufferGetBytesPerRow(pixelBuffer),
                                                 rgbColorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    CGContextRelease(context);
    CGColorSpaceRelease(rgbColorSpace);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CGImageRelease(image);

    CMSampleBufferRef sampleBuffer = NULL;
    CMVideoFormatDescriptionRef formatDesc = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDesc);

    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, YES, NULL, NULL, formatDesc, &timing, &sampleBuffer);

    if (sampleBuffer && self.delegate) {
        [self.delegate uvcCaptureManager:self didOutputSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    } else if (sampleBuffer) {
        CFRelease(sampleBuffer);
    }

    if (formatDesc) CFRelease(formatDesc);
    CVPixelBufferRelease(pixelBuffer);
}

- (void)stopCapture {
    self.isCapturing = NO;
    dispatch_sync(self.captureQueue, ^{});
    self.frameBuffer.length = 0;
    self.latestJPEGFrame = nil;

    if (self.libusbHandle) {
        libusb_release_interface(self.libusbHandle, self.streamingInterface);
        libusb_close(self.libusbHandle);
        self.libusbHandle = NULL;
    }
    if (self.libusbCtx) {
        libusb_exit(self.libusbCtx);
        self.libusbCtx = NULL;
    }
}

- (void)dealloc {
    [self stopCapture];
}

@end
