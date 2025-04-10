import UIKit
import AVFoundation

class DualMode: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
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

    @objc func enableDualMode(on view: UIView) {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("Multicam not supported")
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
                self.containerView = view
                self.setupPreview(on: view)
                self.session.startRunning()
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

    private func setupPiPView(on view: UIView) {
        let pipWidth: CGFloat
        let pipHeight: CGFloat
        let pipX: CGFloat = 16
        let pipY: CGFloat = 60

        if UIDevice.current.userInterfaceIdiom == .pad {
            pipWidth = 240 // Larger PiP size for iPad
            pipHeight = 320
        } else {
            pipWidth = 160 // Default PiP size for iPhone
            pipHeight = 240
        }

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

    @objc func captureDualImagesWithCompletion(_ completion: @escaping (UIImage?, Error?) -> Void) {
        self.captureCompletion = completion
        self.latestFrontImage = nil
        self.latestBackImage = nil
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
                selector: #selector(self.stopDualVideoRecording),
                userInfo: nil,
                repeats: false
            )
        }
    }
    
    @objc func stopDualVideoRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        self.movieRecorder?.stopWriting { [weak self] path, thumb, err in
            guard let self = self else { return }

            if let err = err {
                self.recordingDelegate?.dualModeRecordingDidFail(error: err)
            } else {
                self.recordingDelegate?.dualModeRecordingDidFinish(videoPath: path, thumbnailPath: thumb)
            }

            self.recordingCompletion?(path, thumb, err)
            self.recordingCompletion = nil
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
