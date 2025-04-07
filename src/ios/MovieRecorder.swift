import Foundation
import AVFoundation
import UIKit

class MovieRecorder {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?

    private var isWriting = false
    private var startTime: CMTime?

    private var outputURL: URL?
    private var completionHandler: ((String, String?, Error?) -> Void)?

    func startWriting(audioEnabled: Bool, completion: @escaping (Error?) -> Void) {
        do {
            let outputDirectory = try FileManager.default.url(
                for: .libraryDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("NoCloud", isDirectory: true)

            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

            let fileName = UUID().uuidString + "_dual.mov"
            outputURL = outputDirectory.appendingPathComponent(fileName)

            assetWriter = try AVAssetWriter(outputURL: outputURL!, fileType: .mov)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 720,
                AVVideoHeightKey: 1280
            ]

            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true

            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: 720,
                kCVPixelBufferHeightKey as String: 1280
            ]

            adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

            guard let writer = assetWriter, let vInput = videoInput else {
                return completion(NSError(domain: "Recorder", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize AVAssetWriter"]))
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

                audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                audioInput?.expectsMediaDataInRealTime = true

                if let aInput = audioInput, writer.canAdd(aInput) {
                    writer.add(aInput)
                }
            }
            print("MovieRecorder: Writer initialized at \(outputURL!.path)")
            isWriting = true
            completionHandler = nil
            completion(nil)

        } catch {
            completion(error)
        }
    }

    func appendVideoPixelBuffer(_ pixelBuffer: CVPixelBuffer, withPresentationTime presentationTime: CMTime) {
        guard isWriting,
              let writer = assetWriter,
              writer.status == .unknown || writer.status == .writing,
              let vInput = videoInput,
              let adaptor = adaptor else { return }

        if writer.status == .unknown {
            writer.startWriting()
            writer.startSession(atSourceTime: presentationTime)
            startTime = presentationTime
        }

        if vInput.isReadyForMoreMediaData {
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }
    }

    func appendAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isWriting,
              let aInput = audioInput,
              aInput.isReadyForMoreMediaData,
              let writer = assetWriter,
              writer.status == .writing else { return }

        aInput.append(sampleBuffer)
    }

    func stopWriting(completion: @escaping (String, String?, Error?) -> Void) {
        guard isWriting, let writer = assetWriter else {
            completion("", nil, NSError(domain: "Recorder", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Recording was not started"]))
            return
        }

        isWriting = false
        completionHandler = completion

        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        writer.finishWriting { [weak self] in
            guard let self = self else { return }

            if let error = writer.error {
                self.completionHandler?("", nil, error)
                return
            }

            guard let videoPath = self.outputURL?.path else {
                self.completionHandler?("", nil, NSError(domain: "Recorder", code: 1003, userInfo: [NSLocalizedDescriptionKey: "No video file path"]))
                return
            }

            self.generateThumbnail(from: URL(fileURLWithPath: videoPath)) { thumbnailPath in
                self.completionHandler?(videoPath, thumbnailPath, nil)
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
                    let thumbName = UUID().uuidString + "_thumb.jpg"
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
}
