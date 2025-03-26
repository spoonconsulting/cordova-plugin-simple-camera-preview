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



    
    private let queue = DispatchQueue(label: "dualMode.session.queue")

    @objc func enableDualMode(on view: UIView) {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("Multicam not supported")
            return
        }

        session = AVCaptureMultiCamSession()
        queue.async {
            self.setupSession()
            DispatchQueue.main.async {
                self.setupPreview(on: view)
                self.session.startRunning()
            }
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Back Camera
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let backInput = try? AVCaptureDeviceInput(device: backCamera),
           session.canAddInput(backInput) {

            self.backInput = backInput
            session.addInputWithNoConnections(backInput)

            if session.canAddOutput(backOutput) {
                backOutput.setSampleBufferDelegate(self, queue: queue)
                session.addOutputWithNoConnections(backOutput)

                if let port = self.backVideoPort, let layer = backPreviewLayer {
                    let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
                    conn.videoOrientation = .portrait
                    session.addConnection(conn)
                }

            }
        }

        // Front Camera
        if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let frontInput = try? AVCaptureDeviceInput(device: frontCamera),
           session.canAddInput(frontInput) {

            self.frontInput = frontInput
            session.addInputWithNoConnections(frontInput)

            if session.canAddOutput(frontOutput) {
                frontOutput.setSampleBufferDelegate(self, queue: queue)
                session.addOutputWithNoConnections(frontOutput)

                if let port = self.frontVideoPort, let layer = frontPreviewLayer {
                    let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
                    conn.videoOrientation = .portrait
                    conn.automaticallyAdjustsVideoMirroring = false
                    conn.isVideoMirrored = true

                    session.addConnection(conn)
                }


            }
        }
    }

    private func setupPreview(on view: UIView) {
        // BACK - Fullscreen
        backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        backPreviewLayer?.videoGravity = .resizeAspectFill
        backPreviewLayer?.frame = view.bounds

        if let backLayer = backPreviewLayer {
            // Insert BELOW the webView layer
            if let webViewLayer = view.subviews.first(where: { $0 is WKWebView || $0 is UIWebView })?.layer {
                view.layer.insertSublayer(backLayer, below: webViewLayer)
            } else {
                view.layer.insertSublayer(backLayer, at: 0)
            }
        }

        // FRONT - PiP
        let pipView = UIView(frame: CGRect(x: view.bounds.width - 160 - 16, y: 60, width: 160, height: 240))
        self.pipView = pipView // Save the reference
        pipView.layer.cornerRadius = 12
        pipView.clipsToBounds = true
        pipView.backgroundColor = .black
        view.addSubview(pipView)


        frontPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        frontPreviewLayer?.videoGravity = .resizeAspectFill
        frontPreviewLayer?.frame = pipView.bounds

        if let frontLayer = frontPreviewLayer {
            pipView.layer.addSublayer(frontLayer)
        }

        // FRONT layer connection
        if let port = self.frontVideoPort, let layer = frontPreviewLayer {
            let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
            conn.videoOrientation = .portrait
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
            session.addConnection(conn)
        }

        // BACK layer connection
        if let port = self.backVideoPort, let layer = backPreviewLayer {
            let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
            conn.videoOrientation = .portrait
            session.addConnection(conn)
        }
    }
    
    
    @objc func disableDualModeWithCompletion(_ completion: @escaping () -> Void) {
        print("Disable 3")
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

                completion() // Notify Objective-C plugin
            }
        }
        print("Disable 4")
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

        let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .right)

        if output == backOutput {
            latestBackImage = image
        } else if output == frontOutput {
            latestFrontImage = image
        }

        if let front = latestFrontImage, let back = latestBackImage, let completion = captureCompletion {
            // Merge and return
            let merged = mergeImages(top: front, bottom: back)
            DispatchQueue.main.async {
                completion(merged, nil)
                self.captureCompletion = nil
            }
        }
    }

    
    func mergeImages(top: UIImage, bottom: UIImage) -> UIImage {
        let width = max(top.size.width, bottom.size.width)
        let height = top.size.height + bottom.size.height
        let size = CGSize(width: width, height: height)

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        bottom.draw(in: CGRect(x: 0, y: 0, width: width, height: bottom.size.height))
        top.draw(in: CGRect(x: 0, y: bottom.size.height, width: width, height: top.size.height))
        let mergedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return mergedImage!
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
