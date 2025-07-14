import UIKit
import AVFoundation

@objc(DualMode)
class DualMode: CDVPlugin, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    

    @objc(enableDualMode:)
    func enableDualMode(_ command: CDVInvokedUrlCommand) {
       
    }

}