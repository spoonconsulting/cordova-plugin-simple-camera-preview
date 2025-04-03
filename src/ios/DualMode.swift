import UIKit
import AVFoundation

class DualMode: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var session: AVCaptureMultiCamSession!
    private var backPreviewLayer: AVCaptureVideoPreviewLayer?
    private var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    private var backInput: AVCaptureDeviceInput?
    private var frontInput: AVCaptureDeviceInput?
    private var backOutput = AVCaptureVideoDataOutput()
    private var frontOutput = AVCaptureVideoDataOutput()
    private var backVideoPort: AVCaptureInput.Port?
    private var frontVideoPort: AVCaptureInput.Port?
    private var pipView: UIView?
    private var latestBackImage: UIImage?
    private var latestFrontImage: UIImage?
    private var captureCompletion: ((UIImage?, Error?) -> Void)?
    private var containerView: UIView?
    private var savedPortraitPiPFrame: CGRect?
    private let queue = DispatchQueue(label: "dualMode.session.queue")

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
        
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let backInput = try? AVCaptureDeviceInput(device: backCamera),
           session.canAddInput(backInput) {
            configureCamera(backCamera, desiredWidth: 1920, desiredHeight: 1080)
            self.backInput = backInput
            session.addInputWithNoConnections(backInput)
            if let port = backInput.ports.first(where: { $0.mediaType == .video }) {
                self.backVideoPort = port
            }

            if session.canAddOutput(backOutput) {
                backOutput.setSampleBufferDelegate(self, queue: queue)
                session.addOutputWithNoConnections(backOutput)

                if let port = self.backVideoPort {
                    let conn = AVCaptureConnection(inputPorts: [port], output: backOutput)
                    conn.videoOrientation = .portrait
                    session.addConnection(conn)
                }
            }
        }

        if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let frontInput = try? AVCaptureDeviceInput(device: frontCamera),
           session.canAddInput(frontInput) {
            configureCamera(frontCamera, desiredWidth: 1920, desiredHeight: 1080)
        
            self.frontInput = frontInput
            session.addInputWithNoConnections(frontInput)
            if let port = frontInput.ports.first(where: { $0.mediaType == .video }) {
                self.frontVideoPort = port
            }

            if session.canAddOutput(frontOutput) {
                frontOutput.setSampleBufferDelegate(self, queue: queue)
                session.addOutputWithNoConnections(frontOutput)

                if let port = self.frontVideoPort {
                    let conn = AVCaptureConnection(inputPorts: [port], output: frontOutput)
                    conn.videoOrientation = .portrait
                    conn.automaticallyAdjustsVideoMirroring = false
                    conn.isVideoMirrored = true
                    session.addConnection(conn)
                }
            }
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

    private func setupPreview(on view: UIView) {
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
        if isLandscape {
            if savedPortraitPiPFrame == nil {
                savedPortraitPiPFrame = pipView.frame
            }
            let pipWidth: CGFloat = 240
            let pipHeight: CGFloat = 160
            let pipX: CGFloat = 16
            let pipY: CGFloat = 16
            pipView.frame = CGRect(x: pipX, y: pipY, width: pipWidth, height: pipHeight)
        } else if orientation.isPortrait {
            if let savedFrame = savedPortraitPiPFrame {
                pipView.frame = savedFrame
            } else {
                let pipWidth: CGFloat = 160
                let pipHeight: CGFloat = 240
                let pipX: CGFloat = 16
                let pipY: CGFloat = 16
                pipView.frame = CGRect(x: pipX, y: pipY, width: pipWidth, height: pipHeight)
            }
            savedPortraitPiPFrame = pipView.frame
        }

        frontPreviewLayer?.frame = pipView.bounds
    }

    @objc func captureDualImagesWithCompletion(_ completion: @escaping (UIImage?, Error?) -> Void) {
        self.captureCompletion = completion
        self.latestFrontImage = nil
        self.latestBackImage = nil
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
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
            return .landscapeRight // Front camera
        case .landscapeRight:
            return .landscapeLeft // Front camera
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
