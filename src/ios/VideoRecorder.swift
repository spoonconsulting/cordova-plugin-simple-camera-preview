import Foundation
import AVFoundation
import UIKit

class VideoRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    private var outputURL: URL?
    private var completionHandler: ((String, String?, Error?) -> Void)?
    private let writerQueue = DispatchQueue(label: "video.recorder.queue", qos: .userInitiated)
    private let stateLock = NSLock()
    private var _isWriting = false

    func startWriting(audioEnabled: Bool, recordingOrientation: UIDeviceOrientation? = nil, completion: @escaping (Error?) -> Void) {
        writerQueue.async { [weak self] in
            guard let self = self else {
                completion(NSError(domain: "VideoRecorder", code: 1000, userInfo: [NSLocalizedDescriptionKey: "VideoRecorder deallocated"]))
                return
            }

            guard !self.isWriting else {
                completion(NSError(domain: "VideoRecorder", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Already writing"]))
                return
            }

            do {
                let outputDirectory = try FileManager.default.url(
                    for: .libraryDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                ).appendingPathComponent("NoCloud", isDirectory: true)

                try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

                let fileName = UUID().uuidString + ".mov"
                self.outputURL = outputDirectory.appendingPathComponent(fileName)
                self.assetWriter = try AVAssetWriter(outputURL: self.outputURL!, fileType: .mov)
                
                // Use provided orientation or fall back to current device orientation
                let orientationToUse = recordingOrientation ?? UIDevice.current.orientation
                
                // Ensure we use a valid orientation for recording
                let validOrientation: UIDeviceOrientation
                switch orientationToUse {
                case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
                    validOrientation = orientationToUse
                case .faceUp, .faceDown, .unknown:
                    validOrientation = .portrait
                @unknown default:
                    validOrientation = .portrait
                }
                
                let isLandscape = validOrientation.isLandscape
                let videoWidth = isLandscape ? 1920 : 1080
                let videoHeight = isLandscape ? 1080 : 1920

                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: videoWidth,
                    AVVideoHeightKey: videoHeight
                ]

                self.videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                self.videoInput?.expectsMediaDataInRealTime = true

                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String: videoWidth,
                    kCVPixelBufferHeightKey as String: videoHeight
                ]

                self.adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.videoInput!, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

                guard let writer = self.assetWriter, let vInput = self.videoInput else {
                    completion(NSError(domain: "VideoRecorder", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize AVAssetWriter"]))
                    return
                }

                if writer.canAdd(vInput) {
                    writer.add(vInput)
                }

                if audioEnabled {
                    let audioSettings: [String: Any] = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVNumberOfChannelsKey: 1,
                        AVSampleRateKey: 44100,
                        AVEncoderBitRateKey: 64000
                    ]

                    self.audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                    self.audioInput?.expectsMediaDataInRealTime = true

                    if let aInput = self.audioInput, writer.canAdd(aInput) {
                        writer.add(aInput)
                    }
                }
                
                print("VideoRecorder: Writer initialized at \(self.outputURL!.path)")
                self.isWriting = true
                self.completionHandler = nil
                
                DispatchQueue.main.async {
                    completion(nil)
                }

            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }

    func appendVideoPixelBuffer(_ pixelBuffer: CVPixelBuffer, withPresentationTime presentationTime: CMTime) {
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.isWriting,
                  let writer = self.assetWriter,
                  writer.status == .unknown || writer.status == .writing,
                  let vInput = self.videoInput,
                  let adaptor = self.adaptor else { return }

            if writer.status == .unknown {
                writer.startWriting()
                writer.startSession(atSourceTime: presentationTime)
                self.startTime = presentationTime
            }

            if vInput.isReadyForMoreMediaData {
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            }
        }
    }

    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard self.isWriting,
                  let aInput = self.audioInput,
                  aInput.isReadyForMoreMediaData,
                  let writer = self.assetWriter,
                  writer.status == .writing else { return }

            aInput.append(sampleBuffer)
        }
    }

    func stopWriting(completion: @escaping (String, String?, Error?) -> Void) {
        writerQueue.async { [weak self] in
            guard let self = self else {
                completion("", nil, NSError(domain: "VideoRecorder", code: 1000, userInfo: [NSLocalizedDescriptionKey: "VideoRecorder deallocated"]))
                return
            }
            
            guard self.isWriting, let writer = self.assetWriter else {
                completion("", nil, NSError(domain: "VideoRecorder", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Recording was not started"]))
                return
            }

            self.isWriting = false
            self.completionHandler = completion

            self.videoInput?.markAsFinished()
            self.audioInput?.markAsFinished()

            writer.finishWriting { [weak self] in
                guard let self = self else { return }

                if let error = writer.error {
                    DispatchQueue.main.async {
                        self.completionHandler?("", nil, error)
                    }
                    return
                }

                guard let videoPath = self.outputURL?.path else {
                    DispatchQueue.main.async {
                        self.completionHandler?("", nil, NSError(domain: "VideoRecorder", code: 1004, userInfo: [NSLocalizedDescriptionKey: "No video file path"]))
                    }
                    return
                }

                self.generateThumbnail(from: URL(fileURLWithPath: videoPath)) { thumbnailPath in
                    DispatchQueue.main.async {
                        self.completionHandler?(videoPath, thumbnailPath, nil)
                    }
                }
            }
        }
    }

    private func generateThumbnail(from url: URL, completion: @escaping (String?) -> Void) {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)

        DispatchQueue.global().async {
            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                if let data = uiImage.jpegData(compressionQuality: 0.8) {
                    let thumbName = UUID().uuidString + "video_thumb_.jpg"
                    let dir = try FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                        .appendingPathComponent("NoCloud", isDirectory: true)

                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let fileURL = dir.appendingPathComponent(thumbName)
                    try data.write(to: fileURL)
                    completion(fileURL.path)
                } else {
                    completion(nil)
                }
            } catch {
                print("Thumbnail generation failed: \(error)")
                completion(nil)
            }
        }
    }

    private var isWriting: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _isWriting
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _isWriting = newValue
        }
    }
}
