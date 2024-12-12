//
//  SimpleVideoCaptureInteractor.swift
//  PoseCamera
//
//  Created by 広上駆 on 2024/10/27.
//

import Photos
import Foundation
import AVKit


final class SimpleVideoCaptureInteractor: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice?
    private let dataOutput = AVCaptureMovieFileOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    @Published var isRecording: Bool = false
    @Published var recordingTime: String = "00:00:00"
    private let formatter = DateFormatter()
    private var loading: Bool = false
    
    // Pose estimation model configs
    private var modelType: ModelType = Constants.defaultModelType
    private var threadCount: Int = Constants.defaultThreadCount
    private var delegate: Delegates = Constants.defaultDelegate
    private let minimumScore = Constants.minimumScore
    
    // ForPoseEstimation
    let queue = DispatchQueue(label: "serial_queue")
    private var poseEstimator: PoseEstimator?
    @Published var overlayView: OverlayView?
    var isEstimating = false   // Flag to make sure there's only one frame processed at each moment.
    
    // VideoWriter
    private var videoWriter: AVAssetWriter!
    private var videoWriterVideoInput: AVAssetWriterInput!
    private var videoWriterPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    private var videoWriterAudioInput: AVAssetWriterInput!
    private var recordingStartTime: CMTime?
    
    /// - Tag: CreateCaptureSession
    func setupAVCaptureSession() {
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        captureSession.sessionPreset = .high    // FullHD(1920×1080)
        if let availableDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first {
            captureDevice = availableDevice
        }
        
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice!)
            if captureSession.canAddInput(captureDeviceInput) {
                captureSession.addInput(captureDeviceInput)
            }
            
        } catch let error {
            print(error.localizedDescription)
        }
        
        if captureSession.canAddOutput(self.dataOutput) {
            captureSession.addOutput(self.dataOutput)
        }
        captureSession.commitConfiguration()
        
        // Setup VideoOutput
        let dataOutputQueue = DispatchQueue(
            label: "video data queue",
            qos: .userInitiated,
            attributes: [],
            autoreleaseFrequency: .workItem)
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA)
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        
        // Setup PoseEstimator
        let overlayView = OverlayView()
        overlayView.image = UIImage()
        overlayView.contentMode = .scaleAspectFit
        self.overlayView = overlayView
        do {
            self.poseEstimator = try MoveNet(
                threadCount: self.threadCount,
                delegate: self.delegate,
                modelType: self.modelType
            )
        } catch let error {
            print("model loading error: \(error.localizedDescription)")
        }
        self.setupVideoWriter()
        // Warm up VideoWriter
        self.videoWriter.startWriting()
        self.videoWriter.startSession(atSourceTime: .zero)
        videoWriterVideoInput.markAsFinished()
        videoWriterAudioInput.markAsFinished()
        videoWriter.finishWriting {
            print("Warm up finished")
            self.setupVideoWriter()
        }
    }
    
    func setupVideoWriter() {
        if recordingStartTime != nil {
            recordingStartTime = nil
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(self.captureDevice!.activeFormat.formatDescription)
        let videoSize: CGSize = CGSize(width: CGFloat(dimensions.height), height: CGFloat(dimensions.width))
        let outputURL: URL = self.makeUniqueTempFileURL(extension: "mov")
        self.videoWriter = try! AVAssetWriter(outputURL: outputURL, fileType: .mov)
        let videoOutputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height
        ]
        self.videoWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
        self.videoWriterVideoInput.expectsMediaDataInRealTime = true
        self.videoWriterPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.videoWriterVideoInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
        let audioOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000
        ]
        self.videoWriterAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
        self.videoWriterAudioInput.expectsMediaDataInRealTime = true
        if self.videoWriter.canAdd(self.videoWriterVideoInput) {
            self.videoWriter.add(self.videoWriterVideoInput)
        }
        if self.videoWriter.canAdd(self.videoWriterAudioInput) {
            self.videoWriter.add(self.videoWriterAudioInput)
        }
    }
    
    func startSettion() {
        if captureSession.isRunning { return }
        DispatchQueue.global(qos: .background).async {
            self.captureSession.addOutput(self.videoOutput)
            self.videoOutput.connection(with: .video)?.videoRotationAngle = 90
            self.captureSession.startRunning()
        }
    }
    
    func stopSettion() {
        if !captureSession.isRunning { return }
        captureSession.stopRunning()
    }
    
    func recordVideo() {
        if isRecording {
            AudioServicesPlaySystemSound(1118)
            if videoWriter.status == .writing {
                // Finish record
                videoWriterVideoInput.markAsFinished()
                videoWriterAudioInput.markAsFinished()
                videoWriter.finishWriting { [weak self] in
                    guard let self = self else { return }
                    let outputURL = self.videoWriter.outputURL
                    self.saveVideoToPhotoLibrary(url: outputURL)
                    recordingTime = "00:00:00"
                }
            }
        } else {
            AudioServicesPlaySystemSound(1117)
            if videoWriter.status == .unknown {
                self.videoWriter.startWriting()
                self.videoWriter.startSession(atSourceTime: .zero)
            }
        }
        self.isRecording.toggle()
    }
    
    // Switch between in-camera and out-camera
    func switchInAndOutCamera() {
        guard !loading else { return }
        DispatchQueue.global(qos: .background).async {
            do {
                self.loading = true
                self.captureSession.stopRunning()
                self.captureSession.beginConfiguration()
                // Select camera in-camera or out-camera
                if let inputs = self.captureSession.inputs as? [AVCaptureDeviceInput] {
                    for input in inputs {
                        if input.device.position == .back {
                            if let availableDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front).devices.first {
                                self.captureDevice = availableDevice
                            }
                            self.captureSession.removeInput(input)
                        } else if input.device.position == .front {
                            if let availableDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first {
                                self.captureDevice = availableDevice
                            }
                            self.captureSession.removeInput(input)
                        }
                    }
                }
                let captureDeviceInput = try AVCaptureDeviceInput(device: self.captureDevice!)
                if self.captureSession.canAddInput(captureDeviceInput) {
                    self.captureSession.addInput(captureDeviceInput)
                }
                self.captureSession.commitConfiguration()
                self.videoOutput.connection(with: .video)?.videoRotationAngle = 90
                self.captureSession.startRunning()
                self.loading = false
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    /**
     @brief Create unique url string.
     - parameter type : extension type
     */
    private func makeUniqueTempFileURL(extension type: String) -> URL {
        let temporaryDirectoryURL = FileManager.default.temporaryDirectory
        let uniqueFilename = ProcessInfo.processInfo.globallyUniqueString
        let urlNoExt = temporaryDirectoryURL.appendingPathComponent(uniqueFilename)
        let url = urlNoExt.appendingPathExtension(type)
        return url
    }
    
    private func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> UIImage.Orientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    private func exifOrientationForCurrentDeviceOrientation() -> UIImage.Orientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
    
    func writeProcessedVideoFrame(uiImage: UIImage, timestamp: CMTime) {
        if self.isRecording,
           self.videoWriterVideoInput.isReadyForMoreMediaData {
            if self.recordingStartTime == nil {
                self.recordingStartTime = timestamp
            }
            // UIImage -> CVPixelBuffer
            let processedPixelBuffer: CVPixelBuffer? = self.toPixelBuffer(uiImage: uiImage)
            // write
            let timespan = CMTimeSubtract(timestamp, self.recordingStartTime!)
            recordingTime = formatter.string(from: Date(timeIntervalSince1970: timespan.seconds))    // for View
            self.videoWriterPixelBufferAdaptor.append(processedPixelBuffer!, withPresentationTime: timespan)
        }
    }
    
    func toPixelBuffer(uiImage: UIImage) -> CVPixelBuffer? {
        guard let cgImage = uiImage.cgImage else { return nil } // ここでエラー
        
        let size = uiImage.size
        
        let options: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB, // フォーマットは必要に応じて変更
            options as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: pixelData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        return buffer
    }
    
    func saveVideoToPhotoLibrary(url: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { saved, error in
                    DispatchQueue.main.async {
                        if saved {
                            print("Video saved in photo library")
                            self.setupVideoWriter()
                        } else {
                            print("Failed saving: \(String(describing: error))")
                        }
                    }
                }
            } else {
                print("Access denided to photo library")
            }
        }
    }

    
}

extension SimpleVideoCaptureInteractor: AVCaptureFileOutputRecordingDelegate {
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }) { _, error in
            DispatchQueue.main.async {
                //self.shutterButton.isEnabled = true
                //self.changeModeSegmentControl.isEnabled = true
            }
            
            if let error = error {
                print(error)
            }
            
            cleanup()
        }
        
        // Clean file path.
        func cleanup() {
            let path = outputFileURL.path
            if FileManager.default.fileExists(atPath: path) {
                do {
                    try FileManager.default.removeItem(atPath: path)
                } catch {
                    print("Error clean up: \(error)")
                }
            }
        }
    }
    
}
/// Delegate to receive the frames captured from the device's camera.

extension SimpleVideoCaptureInteractor: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let presentationTimeStamp: CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        runModel(pixelBuffer, timestamp: presentationTimeStamp)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    }
    
    /// Run pose estimation on the input frame from the camera.
    private func runModel(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        // Guard to make sure that there's only 1 frame process at each moment.
        guard !isEstimating else { return }
        
        // Guard to make sure that the pose estimator is already initialized.
        guard let estimator = poseEstimator else { return }
        
        // Run inference on a serial queue to avoid race condition.
        queue.async {
            
            self.isEstimating = true
            defer {self.isEstimating = false}
            
            // Run pose estimation
            do {
                let (result, times) = try estimator.estimateSinglePose(
                    on: pixelBuffer)
                
                // Return to main thread to show detection results on the app UI.
                DispatchQueue.main.async {
                    // Allowed to set image and overlay
                    let image = UIImage(
                            ciImage: CIImage(
                                cvPixelBuffer: pixelBuffer
                            )
                        )
                    
                    // If score is too low, clear result remaining in the overlayView.
                    if result.score < self.minimumScore {
                        self.overlayView?.draw(at: image)
                    } else {
                        // Visualize the pose estimation result.
                        self.overlayView?.draw(at: image, person: result)
                    }
                    // Capture overlayView
                    if self.isRecording {
                        self.writeProcessedVideoFrame(uiImage: self.overlayView!.image!, timestamp: timestamp)
                    }
                    return
                }
            } catch {
                print("error \(error)")
                return
            }
        }
    }
    
}

enum Constants {
    // Configs for the TFLite interpreter.
    static let defaultThreadCount = 4
    static let defaultDelegate: Delegates = .gpu
    static let defaultModelType: ModelType = .movenetThunder
    
    // Minimum score to render the result.
    static let minimumScore: Float32 = 0.2
}

