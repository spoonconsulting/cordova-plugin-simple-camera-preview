import UIKit
import AVFoundation

class DualCameraRenderController {
    private var backPreviewLayer: AVCaptureVideoPreviewLayer?
    private var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    private var pipView: UIView?
    private var containerView: UIView?
    private var session: AVCaptureMultiCamSession?
    private var sessionManager: DualCameraSessionManager?

    func setupPreview(on view: UIView, session: AVCaptureMultiCamSession, sessionManager: DualCameraSessionManager) {
        self.containerView = view
        self.session = session
        self.sessionManager = sessionManager
        setupBackPreviewLayer(on: view, session: session)
        setupPiPView(on: view)
        setupFrontPreviewLayer(session: session)
        
        // Set initial orientation based on current device orientation
        updatePreviewForCurrentOrientation()
        
        // Add orientation change notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    func teardownPreview() {
        NotificationCenter.default.removeObserver(self)
        
        backPreviewLayer?.removeFromSuperlayer()
        backPreviewLayer = nil
        frontPreviewLayer?.removeFromSuperlayer()
        frontPreviewLayer = nil
        pipView?.removeFromSuperview()
        pipView = nil
        containerView = nil
        session = nil
    }

    @objc private func orientationChanged() {
        guard let containerView = containerView else { return }
        
        DispatchQueue.main.async {
            self.updatePreviewForCurrentOrientation()
        }
    }
    
    private func updatePreviewForCurrentOrientation() {
        guard let containerView = containerView,
              let pipView = pipView,
              let frontPreviewLayer = frontPreviewLayer else { return }
        
        let orientation = UIDevice.current.orientation
        let isLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
        
        if isLandscape {
            let pipWidth: CGFloat = 240
            let pipHeight: CGFloat = 160
            let pipX: CGFloat = 20
            let pipY: CGFloat = 15
            
            pipView.frame = CGRect(x: pipX, y: pipY, width: pipWidth, height: pipHeight)
        } else {
            let pipWidth: CGFloat = 160
            let pipHeight: CGFloat = 240
            let pipX: CGFloat = 16
            let pipY: CGFloat = 60
            
            pipView.frame = CGRect(x: pipX, y: pipY, width: pipWidth, height: pipHeight)
        }
        
        frontPreviewLayer.frame = pipView.bounds
        backPreviewLayer?.frame = containerView.bounds
        updateFrontCameraOrientation()
    }
    
    private func updateFrontCameraOrientation() {
        guard let session = session else { return }
        
        let orientation = UIDevice.current.orientation
        let videoOrientation: AVCaptureVideoOrientation
        
        switch orientation {
        case .portrait:
            videoOrientation = .portrait
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        case .landscapeLeft:
            videoOrientation = .landscapeRight
        case .landscapeRight:
            videoOrientation = .landscapeLeft
        default:
            videoOrientation = .portrait
        }
        
        sessionManager?.updateVideoOrientation(videoOrientation)
        if let frontConnection = frontPreviewLayer?.connection {
            if frontConnection.isVideoOrientationSupported {
                frontConnection.videoOrientation = videoOrientation
            }
        }
        
        if let backConnection = backPreviewLayer?.connection {
            if backConnection.isVideoOrientationSupported {
                backConnection.videoOrientation = videoOrientation
            }
        }
    }

    private func setupBackPreviewLayer(on view: UIView, session: AVCaptureMultiCamSession) {
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
        let orientation = UIDevice.current.orientation
        let isLandscape = orientation == .landscapeLeft || orientation == .landscapeRight
        
        let pipWidth: CGFloat
        let pipHeight: CGFloat
        let pipX: CGFloat = 16
        let pipY: CGFloat = 60
        
        if isLandscape {
            pipWidth = 240
            pipHeight = 160
        } else {
            pipWidth = 160
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

    private func setupFrontPreviewLayer(session: AVCaptureMultiCamSession) {
        guard let pipView = self.pipView else { return }

        frontPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        frontPreviewLayer?.videoGravity = .resizeAspectFill
        frontPreviewLayer?.frame = pipView.bounds

        if let frontLayer = frontPreviewLayer {
            pipView.layer.addSublayer(frontLayer)
        }
    }
}
