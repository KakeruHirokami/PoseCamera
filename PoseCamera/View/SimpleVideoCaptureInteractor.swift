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
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureDevice: AVCaptureDevice?
    @Published var showPhoto: Bool = false
    @Published var photoImage: UIImage?
    private let dataOutput = AVCaptureMovieFileOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var captureState: captureState = .wait // VideoCapture State
    
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
    
    enum captureState: Int {
        case wait
        case capturing
    }
    
    /// - Tag: CreateCaptureSession
    func setupAVCaptureSession() {
        print(#function)
        captureSession.sessionPreset = .photo
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
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.name = "CameraPreview"
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer = previewLayer
        //self.dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]
        
        if captureSession.canAddOutput(self.dataOutput) {
            captureSession.addOutput(self.dataOutput)
        }
        captureSession.commitConfiguration()
        
        print("VideoOutput set")
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
        
        print("Prepare PoseEstimator")
        let overlayView = OverlayView()
        overlayView.image = UIImage(systemName: "photo")
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
        switch self.captureState {
        case .wait:
            AudioServicesPlaySystemSound(1117)
            let fileURL: URL = self.makeUniqueTempFileURL(extension: "mov")
            self.dataOutput.startRecording(to: fileURL, recordingDelegate: self)
            self.captureState = .capturing
            
        case .capturing:
            AudioServicesPlaySystemSound(1118)
            self.dataOutput.stopRecording()
            self.captureState = .wait
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
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        runModel(pixelBuffer)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
    }
    
    /// Run pose estimation on the input frame from the camera.
    private func runModel(_ pixelBuffer: CVPixelBuffer) {
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
                        print("no detected")
                        self.overlayView?.draw(at: image)
                        return
                    }
                    
                    // Visualize the pose estimation result.
                    print("\(image.size)")
                    self.overlayView?.draw(at: image, person: result)
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

