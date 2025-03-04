import AVFoundation
import UIKit

@objc class DualModeManager: NSObject {
    
    private var session: AVCaptureMultiCamSession?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?
    private var frontVideoOutput: AVCaptureVideoDataOutput?
    private var backVideoOutput: AVCaptureVideoDataOutput?
    
    private var previewLayerFront: AVCaptureVideoPreviewLayer?
    private var previewLayerBack: AVCaptureVideoPreviewLayer?
    
    private var parentView: UIView?
    
    @objc static let shared = DualModeManager()
    
    @objc func setupDualMode(in parentView: UIView) -> Bool {
        self.parentView = parentView
        
        if !AVCaptureMultiCamSession.isMultiCamSupported {
            print("MultiCam is not supported on this device.")
            return false
        }
        
        session = AVCaptureMultiCamSession()
        session?.beginConfiguration()
        
        do {
            if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                let backCameraInput = try AVCaptureDeviceInput(device: backCamera)
                if session!.canAddInput(backCameraInput) {
                    session!.addInput(backCameraInput)
                    self.backCameraInput = backCameraInput
                }
            }
            
            if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                let frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                if session!.canAddInput(frontCameraInput) {
                    session!.addInput(frontCameraInput)
                    self.frontCameraInput = frontCameraInput
                }
            }
            
            frontVideoOutput = AVCaptureVideoDataOutput()
            backVideoOutput = AVCaptureVideoDataOutput()
            
            if let frontVideoOutput = frontVideoOutput, session!.canAddOutput(frontVideoOutput) {
                session!.addOutput(frontVideoOutput)
            }
            
            if let backVideoOutput = backVideoOutput, session!.canAddOutput(backVideoOutput) {
                session!.addOutput(backVideoOutput)
            }
            
            setupPreviewLayers()
            
            session?.commitConfiguration()
            session?.startRunning()
            
            return true
            
        } catch {
            print("Error setting up dual mode: \(error.localizedDescription)")
            return false
        }
    }
    
    private func setupPreviewLayers() {
        guard let parentView = parentView else { return }
        
        previewLayerBack = AVCaptureVideoPreviewLayer(session: session!)
        previewLayerBack?.videoGravity = .resizeAspectFill
        previewLayerBack?.frame = parentView.bounds
        parentView.layer.addSublayer(previewLayerBack!)
        
        let frontFrame = CGRect(x: 10, y: 100, width: 150, height: 200)
        let frontView = UIView(frame: frontFrame)
        frontView.backgroundColor = .clear
        parentView.addSubview(frontView)
        
        previewLayerFront = AVCaptureVideoPreviewLayer(session: session!)
        previewLayerFront?.videoGravity = .resizeAspectFill
        previewLayerFront?.frame = frontView.bounds
        previewLayerFront?.cornerRadius = 10
        previewLayerFront?.masksToBounds = true
        frontView.layer.addSublayer(previewLayerFront!)
    }
    
    @objc func stopDualMode() {
        session?.stopRunning()
        session = nil
        previewLayerFront?.removeFromSuperlayer()
        previewLayerBack?.removeFromSuperlayer()
    }
}
