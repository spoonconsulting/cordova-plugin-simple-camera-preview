import UIKit
import AVFoundation

@objc(DualMode)
class DualMode: CDVPlugin, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    private var session: AVCaptureMultiCamSession!
    private var backPreviewLayer: AVCaptureVideoPreviewLayer?
    private var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    private var backInput: AVCaptureDeviceInput?
    private var frontInput: AVCaptureDeviceInput?
    private var backOutput = AVCaptureVideoDataOutput()
    private var frontOutput = AVCaptureVideoDataOutput()
    private var backVideoPort: AVCaptureInput.Port?
    private var frontVideoPort: AVCaptureInput.Port?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var pipView: UIView?
    private var latestBackImage: UIImage?
    private var latestFrontImage: UIImage?
    private var captureCompletion: ((UIImage?, Error?) -> Void)?
    private var containerView: UIView?
    private var savedPortraitPiPFrame: CGRect?
    private let queue = DispatchQueue(label: "dualMode.session.queue")
    private var movieRecorder: MovieRecorder?
    private var videoMixer = PiPVideoMixer()
    private var audioInput: AVCaptureInput?
    private var latestFrontBuffer: CMSampleBuffer?
    private var latestBackBuffer: CMSampleBuffer?
    @objc weak var recordingDelegate: DualModeRecordingDelegate?
    private var recordingTimer: Timer?
    private var recordingCompletion: ((String, String?, Error?) -> Void)?
    private var callbackId: String?
    private var videoCallbackContext: CDVInvokedUrlCommand?
    var simpleCameraPreview: SimpleCameraPreview?

    @objc(enableDualMode:)
    func enableDualMode(_ command: CDVInvokedUrlCommand) {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            let pluginResult = CDVPluginResult(status: .error, messageAs: "Multicam not supported")
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            return
        }
        
        session = AVCaptureMultiCamSession()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        queue.async {
            self.setupSession()
            DispatchQueue.main.async {
                if let container = self.webView.superview {
                    self.setupPreview(on: container)
                } else {
                    let pluginResult = CDVPluginResult(status: .error, messageAs: "Container view not set")
                    self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                    return
                }
                
                self.session.startRunning()
                let pluginResult = CDVPluginResult(status: .ok, messageAs: "Dual mode enabled successfully")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        setupBackCamera()
        setupFrontCamera()
        setupMicrophone()
    }
    
    private func setupBackCamera() {
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let backInput = try? AVCaptureDeviceInput(device: backCamera),
              session.canAddInput(backInput) else {
            return
        }

        configureCamera(backCamera, desiredWidth: 1920, desiredHeight: 1080)
        self.backInput = backInput
        session.addInputWithNoConnections(backInput)

        if let port = backInput.ports.first(where: { $0.mediaType == .video }) {
            self.backVideoPort = port
        }

        if session.canAddOutput(backOutput) {
            backOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            backOutput.setSampleBufferDelegate(self, queue: queue)
            session.addOutputWithNoConnections(backOutput)

            if let port = self.backVideoPort {
                let connection = AVCaptureConnection(inputPorts: [port], output: backOutput)
                connection.videoOrientation = .portrait
                session.addConnection(connection)
            }
        }
    }

    private func setupFrontCamera() {
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let frontInput = try? AVCaptureDeviceInput(device: frontCamera),
              session.canAddInput(frontInput) else {
            return
        }

        configureCamera(frontCamera, desiredWidth: 1920, desiredHeight: 1080)
        self.frontInput = frontInput
        session.addInputWithNoConnections(frontInput)

        if let port = frontInput.ports.first(where: { $0.mediaType == .video }) {
            self.frontVideoPort = port
        }

        if session.canAddOutput(frontOutput) {
            frontOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            frontOutput.setSampleBufferDelegate(self, queue: queue)
            session.addOutputWithNoConnections(frontOutput)

            if let port = self.frontVideoPort {
                let connection = AVCaptureConnection(inputPorts: [port], output: frontOutput)
                connection.videoOrientation = .portrait
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
                session.addConnection(connection)
            }
        }
    }
    
    private func setupMicrophone() {
        guard let mic = AVCaptureDevice.default(for: .audio),
              let micInput = try? AVCaptureDeviceInput(device: mic),
              session.canAddInput(micInput) else {
            return
        }

        self.audioInput = micInput
        session.addInputWithNoConnections(micInput)

        let audioOutput = AVCaptureAudioDataOutput()
        if session.canAddOutput(audioOutput) {
            audioOutput.setSampleBufferDelegate(self, queue: queue)
            session.addOutputWithNoConnections(audioOutput)

            if let port = micInput.ports.first(where: { $0.mediaType == .audio }) {
                let audioConnection = AVCaptureConnection(inputPorts: [port], output: audioOutput)
                if session.canAddConnection(audioConnection) {
                    session.addConnection(audioConnection)
                }
            }

            self.audioOutput = audioOutput
        }
    }

    private func configureCamera(_ device: AVCaptureDevice, desiredWidth: Int32, desiredHeight: Int32) {
        for format in device.formats {
            let description = format.formatDescription
            let dimensions = CMVideoFormatDescriptionGetDimensions(description)
            if dimensions.width == desiredWidth && dimensions.height == desiredHeight {
                do {
                    try device.lockForConfiguration()
                    device.activeFormat = format
                    device.unlockForConfiguration()
                    print("Set \(device.localizedName) resolution to \(desiredWidth)x\(desiredHeight)")
                    break
                } catch {
                    print("Error locking configuration for \(device.localizedName): \(error)")
                }
            }
        }
    }

    func setupPreview(on view: UIView) {
        self.setupBackPreviewLayer(on: view)
        self.setupPiPView(on: view)
        self.setupFrontPreviewLayer()
    }
    
    private func setupBackPreviewLayer(on view: UIView) {
        backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        backPreviewLayer?.videoGravity = .resizeAspectFill
        backPreviewLayer?.frame = view.bounds

        if let backLayer = backPreviewLayer {
            if let webViewLayer = view.subviews.first(where: { $0 is WKWebView || $0 is UIWebView })?.layer {
                view.layer.insertSublayer(backLayer, below: webViewLayer)
            } else {
                view.layer.insertSublayer(backLayer, at: 0)
            }
        }
    }

    private func setupPiPView(on view: UIView) {
        let pipWidth: CGFloat = 160
        let pipHeight: CGFloat = 240
        let pipX: CGFloat = 16
        let pipY: CGFloat = 60

        let pipView = UIView(frame: CGRect(x: pipX, y: pipY, width: pipWidth, height: pipHeight))
        self.pipView = pipView
        pipView.layer.cornerRadius = 12
        pipView.clipsToBounds = true
        pipView.backgroundColor = .black

        if let webView = view.subviews.first(where: { $0 is WKWebView || $0 is UIWebView }) {
            view.insertSubview(pipView, belowSubview: webView)
        } else {
            view.addSubview(pipView)
        }
    }

    private func setupFrontPreviewLayer() {
        guard let pipView = self.pipView else { return }

        frontPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        frontPreviewLayer?.videoGravity = .resizeAspectFill
        frontPreviewLayer?.frame = pipView.bounds

        if let frontLayer = frontPreviewLayer {
            pipView.layer.addSublayer(frontLayer)
        }
    }

    @objc func disableDualModeWithCompletion(_ completion: @escaping () -> Void) {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        queue.async {
            self.session.stopRunning()

            self.session = nil
            self.backInput = nil
            self.frontInput = nil
            self.backVideoPort = nil
            self.frontVideoPort = nil
            self.backOutput = AVCaptureVideoDataOutput()
            self.frontOutput = AVCaptureVideoDataOutput()

            DispatchQueue.main.async {
                self.backPreviewLayer?.removeFromSuperlayer()
                self.backPreviewLayer = nil
                self.frontPreviewLayer?.removeFromSuperlayer()
                self.frontPreviewLayer = nil
                self.pipView?.removeFromSuperview()
                self.pipView = nil

                completion()
            }
        }
    }
    
    @objc private func deviceOrientationDidChange() {
        DispatchQueue.main.async {
            self.updatePreviewOrientation()
        }
    }
    
    private func updatePreviewOrientation() {
        let orientation = UIDevice.current.orientation
        let videoOrientation = orientation.videoOrientation
        
        if let connection = backPreviewLayer?.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
        if let connection = frontPreviewLayer?.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
        
        if let view = containerView {
            backPreviewLayer?.frame = view.bounds
        }
        
        guard let pipView = pipView, let view = containerView else { return }
        
        let isLandscape = orientation.isLandscape
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Larger PiP size for iPad in both portrait and landscape
            if isLandscape {
                let pipWidth: CGFloat = 320 
                let pipHeight: CGFloat = 240 
                pipView.frame = CGRect(x: 16, y: 16, width: pipWidth, height: pipHeight)
            } else {
                let pipWidth: CGFloat = 240 
                let pipHeight: CGFloat = 320
                pipView.frame = CGRect(x: 16, y: 60, width: pipWidth, height: pipHeight)
            }
        } else {
            // Default PiP size for iPhone
            if isLandscape {
                let pipWidth: CGFloat = 240
                let pipHeight: CGFloat = 160
                pipView.frame = CGRect(x: 16, y: 16, width: pipWidth, height: pipHeight)
            } else {
                let pipWidth: CGFloat = 160
                let pipHeight: CGFloat = 240
                pipView.frame = CGRect(x: 16, y: 60, width: pipWidth, height: pipHeight)
            }
        }
        
        if orientation.isPortrait {
            savedPortraitPiPFrame = pipView.frame
        }

        frontPreviewLayer?.frame = pipView.bounds
    }
    
    @objc(captureDual:)
    func captureDual(_ command: CDVInvokedUrlCommand) {
        self.captureDualImagesWithCompletion { [weak self] mergedImage, error in
            guard let self = self else { return }
            
            if let error = error {
                let errorResult = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            guard let mergedImage = mergedImage else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to capture image")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            guard let imageData = mergedImage.jpegData(compressionQuality: 0.9) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to convert merged image")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            let cfData = imageData as CFData
            guard let imageSource = CGImageSourceCreateWithData(cfData, nil) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to create image source")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            guard let metaDict = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to get image properties")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            let mutableDict = NSMutableDictionary(dictionary: metaDict)
            
            if let gpsData = simpleCameraPreview?.getGPSDictionaryForLocation() {
                mutableDict[kCGImagePropertyGPSDictionary as String] = gpsData
            }
            
            let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
            guard let libraryDirectory = paths.first else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Library directory not found")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            let noCloudPath = (libraryDirectory as NSString).appendingPathComponent("NoCloud")
            let uniqueFileName = UUID().uuidString + ".jpg"
            let fullPath = (noCloudPath as NSString).appendingPathComponent(uniqueFileName)
            let dataPath = "file://" + fullPath
            
            guard let url = URL(string: dataPath) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Invalid file URL")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            guard let uti = CGImageSourceGetType(imageSource) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to get image UTI")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, uti, 1, nil) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to create image destination")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            CGImageDestinationAddImageFromSource(destination, imageSource, 0, mutableDict)
            
            guard CGImageDestinationFinalize(destination) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to finalize image destination")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
    
            let successResult = CDVPluginResult(status: .ok, messageAs: dataPath)
            self.commandDelegate.send(successResult, callbackId: command.callbackId)
        }
    }



    @objc func captureDualImagesWithCompletion(_ completion: @escaping (UIImage?, Error?) -> Void) {
        self.captureCompletion = completion
        self.latestFrontImage = nil
        self.latestBackImage = nil
    }
    
    @objc(initVideoCallback:)
    func initVideoCallback(_ command: CDVInvokedUrlCommand) {
        self.videoCallbackContext = command
        let data: [String: Any] = ["videoCallbackInitialized": true]
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: data)
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }
    
    @objc(startVideoCaptureDual:)
     func startVideoCaptureDual(_ command: CDVInvokedUrlCommand) {
        guard let options = command.arguments.first as? [String: Any] else {
            let errorResult = CDVPluginResult(status: .error, messageAs: "Missing options")!
            self.commandDelegate.send(errorResult, callbackId: command.callbackId)
            return
        }
        
        let recordWithAudio = options["recordWithAudio"] as? Bool ?? true
        let videoDurationMs = options["videoDurationMs"] as? Int ?? 3000
        
        guard self.session != nil else {
            let errorResult = CDVPluginResult(status: .error, messageAs: "Dual mode not enabled")!
            self.commandDelegate.send(errorResult, callbackId: command.callbackId)
            return
        }
        
        if let callbackId = self.videoCallbackContext?.callbackId {
            let event: [String: Any] = ["recording": true]
            let recordingStarted = CDVPluginResult(status: .ok, messageAs: event)!
            recordingStarted.setKeepCallbackAs(true)
            self.commandDelegate.send(recordingStarted, callbackId: callbackId)
        } else {
            let errorResult = CDVPluginResult(status: .error, messageAs: "Video callback context not initialized")!
            self.commandDelegate.send(errorResult, callbackId: command.callbackId)
            return
        }
        
        self.startDualVideoRecordingWithAudio(recordWithAudio, duration: videoDurationMs) { [weak self] (videoPath, thumbnailPath, error) in
            guard let self = self else { return }
            if let error = error {
                let errorResult = CDVPluginResult(status: .error, messageAs: error.localizedDescription)!
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
            } else {
                let result: [String: Any] = [
                    "nativePath": videoPath,
                    "thumbnail": thumbnailPath ?? NSNull()
                ]
                let pluginResult = CDVPluginResult(status: .ok, messageAs: result)!
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    @objc func startDualVideoRecordingWithAudio(
        _ recordWithAudio: Bool,
        duration: Int,
        completion: @escaping (String, String?, Error?) -> Void
    ) {
        self.videoMixer.pipFrame = CGRect(x: 0.05, y: 0.05, width: 0.3, height: 0.3)
        self.movieRecorder = MovieRecorder()
        self.recordingCompletion = completion
        self.movieRecorder?.startWriting(audioEnabled: recordWithAudio) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completion("", nil, error)
                return
            }

            let durationInSeconds = TimeInterval(duration) / 1000.0
            self.recordingTimer = Timer.scheduledTimer(
                timeInterval: durationInSeconds,
                target: self,
                selector: #selector(self.stopVideoCaptureDual),
                userInfo: nil,
                repeats: false
            )
        }
    }
    
    @objc(stopVideoCaptureDual:)
    func stopVideoCaptureDual(_ command: CDVInvokedUrlCommand) {
        if self.session != nil {
            self.stopDualVideoRecording(command)
            let result = CDVPluginResult(status: .ok)!
            self.commandDelegate.send(result, callbackId: command.callbackId)
        } else {
            let errorResult = CDVPluginResult(status: .error, messageAs: "Dual mode not enabled")!
            self.commandDelegate.send(errorResult, callbackId: command.callbackId)
        }
    }
    
    func stopDualVideoRecording(_ command: CDVInvokedUrlCommand) {
        recordingTimer?.invalidate()
        recordingTimer = nil

        self.movieRecorder?.stopWriting { [weak self] path, thumb, err in
            guard let self = self else { return }

            if let error = err {
                self.dualModeRecordingDidFail(withError: error)
            } else {
                self.dualModeRecordingDidFinish(withVideoPath: path, thumbnailPath: thumb)
            }
        }
    }

    @objc func dualModeRecordingDidFinish(withVideoPath videoPath: String, thumbnailPath: String?) {
        let result: [String: Any] = [
            "nativePath": videoPath,
            "thumbnail": thumbnailPath ?? NSNull()
        ]
        
        let pluginResult = CDVPluginResult(status: .ok, messageAs: result)!
        pluginResult.setKeepCallbackAs(true)
        
        if let callbackId = self.videoCallbackContext?.callbackId {
            self.commandDelegate.send(pluginResult, callbackId: callbackId)
        } else {
            print("videoCallbackContext not set; cannot send result.")
        }
    }

    @objc func dualModeRecordingDidFail(withError error: Error) {
        let pluginResult = CDVPluginResult(status: .error, messageAs: error.localizedDescription)!
        
        if let callbackId = self.videoCallbackContext?.callbackId {
            self.commandDelegate.send(pluginResult, callbackId: callbackId)
        } else {
            print("videoCallbackContext not set; cannot send error.")
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let movieRecorder = self.movieRecorder {
            if output == backOutput {
                self.latestBackBuffer = sampleBuffer
            } else if output == frontOutput {
                self.latestFrontBuffer = sampleBuffer
            } else if output == audioOutput {
                movieRecorder.appendAudioBuffer(sampleBuffer)
                return
            }

            if self.videoMixer.inputFormatDescription == nil,
               let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
                self.videoMixer.prepare(with: formatDesc, outputRetainedBufferCountHint: 6)
            }

            guard let front = latestFrontBuffer, let back = latestBackBuffer else { return }

            guard let frontBuffer = CMSampleBufferGetImageBuffer(front),
                  let backBuffer = CMSampleBufferGetImageBuffer(back) else { return }

            if let merged = self.videoMixer.mix(fullScreenPixelBuffer: backBuffer, pipPixelBuffer: frontBuffer, fullScreenPixelBufferIsFrontCamera: false) {
                movieRecorder.appendVideoPixelBuffer(merged, withPresentationTime: CMSampleBufferGetPresentationTimeStamp(back))
                latestFrontBuffer = nil
                latestBackBuffer = nil
            }
        }

        if self.captureCompletion != nil {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

            let orientation = self.imageOrientationForCurrentDevice()
            let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: orientation)

            if output == backOutput {
                latestBackImage = image
            } else if output == frontOutput {
                latestFrontImage = image
            }

            if let front = latestFrontImage, let back = latestBackImage, let completion = captureCompletion {
                let merged = mergeImages(background: back, overlay: front)
                let rotated = rotateImage(merged)

                DispatchQueue.main.async {
                    completion(rotated, nil)
                    self.captureCompletion = nil
                    self.latestBackImage = nil
                    self.latestFrontImage = nil
                }
            }
        }
    }

    func mergeImages(background: UIImage, overlay: UIImage) -> UIImage {
        let size = background.size
        let overlayWidth: CGFloat = size.width * 0.3
        let overlayHeight = overlay.size.height * (overlayWidth / overlay.size.width)
        let padding: CGFloat = 16

        let overlayRect = CGRect(
            x: size.width - overlayWidth - padding,
            y: padding,
            width: overlayWidth,
            height: overlayHeight
        )

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        background.draw(in: CGRect(origin: .zero, size: size))
        overlay.draw(in: overlayRect)
        let merged = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return merged!
    }
    
    @objc(disableDualMode:)
    func disableDualMode(_ command: CDVInvokedUrlCommand) {
        guard self.session != nil else {
            let errorResult = CDVPluginResult(status: .error, messageAs: "Dual mode not started")
            self.commandDelegate.send(errorResult, callbackId: command.callbackId)
            return
        }
        
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        
        queue.async {
            self.session.stopRunning()
            self.session = nil
            self.backInput = nil
            self.frontInput = nil
            self.backVideoPort = nil
            self.frontVideoPort = nil
            
            self.backOutput = AVCaptureVideoDataOutput()
            self.frontOutput = AVCaptureVideoDataOutput()
            
            DispatchQueue.main.async {
                self.backPreviewLayer?.removeFromSuperlayer()
                self.backPreviewLayer = nil
                self.frontPreviewLayer?.removeFromSuperlayer()
                self.frontPreviewLayer = nil
                self.pipView?.removeFromSuperview()
                self.pipView = nil
                
                let pluginResult = CDVPluginResult(status: .ok, messageAs: "Dual mode disabled successfully")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    private func imageOrientationForCurrentDevice() -> UIImage.Orientation {
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        case .portrait:
            return .right
        default:
            return .right
        }
    }
}

func rotateImage(_ image: UIImage) -> UIImage {
    let size = CGSize(width: image.size.height, height: image.size.width)
    
    UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
    guard let context = UIGraphicsGetCurrentContext() else {
        return image
    }

    context.translateBy(x: 0, y: size.height)
    context.rotate(by: -.pi / 2)
    image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))

    let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return rotatedImage ?? image
}

extension UIDeviceOrientation {
    var videoOrientation: AVCaptureVideoOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight 
        case .landscapeRight:
            return .landscapeLeft 
        default:
            return .portrait
        }
    }
}

extension CALayer {
    func snapshot() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: self.bounds.size)
        return renderer.image { ctx in
            self.render(in: ctx.cgContext)
        }
    }
}

@objc protocol DualModeRecordingDelegate: AnyObject {
    func dualModeRecordingDidFinish(videoPath: String, thumbnailPath: String?)
    func dualModeRecordingDidFail(error: Error)
}
