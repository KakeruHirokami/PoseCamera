//
//  SimpleVideoCaptureInteractorMock.swift
//  PoseCamera
//
//  Created by 広上駆 on 2024/12/22.
//

import Photos
import Foundation
import AVKit
import SwiftUI

final class SimpleVideoCaptureInteractorMock: NSObject, ObservableObject {
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
    
    // for Mock
    private var timer: Timer?
    private var videoTrackOutput: AVAssetReaderTrackOutput?
    private var reader: AVAssetReader?
    private var pixelBufferList: Array<CVPixelBuffer> = []
    private var analyzedImageList: Array<Dictionary<String, Any>> = []
    private var currentFrameIndex: Int = 0
    
    /// - Tag: CreateCaptureSession
    func setupAVCaptureSession() {
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
    }
    
    func startSession(uiImage: UIImage) {
        let pixel = self.toPixelBuffer(uiImage: uiImage)!
        self.runModel(pixel)
    }
    
    func startSessionVideo(asset: AVAsset) {
        self.reader = try! AVAssetReader(asset: asset)
        guard let videoTrack = asset.tracks(withMediaType: AVMediaType.video).last else {
            print("could not retrieve the video track.")
            return
        }
        
        let readerOutputSettings: [String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerOutputSettings)

        self.reader!.add(readerOutput)
        self.videoTrackOutput = readerOutput
        
        self.reader!.startReading()
        
        // Process frames
        self.timer = Timer.scheduledTimer(withTimeInterval: 0, repeats: true) { _ in
            self.processNextFrame()
        }
    }
    
    func stopProcessing() {
        timer?.invalidate()
        timer = nil
        self.reader?.cancelReading()
    }
    
    private func processNextFrame() {
        guard let output = videoTrackOutput,
              let sampleBuffer = output.copyNextSampleBuffer(),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            stopProcessing()
            return
        }
        
        // Convert to UIImage
        let transform = CGAffineTransform(rotationAngle: .pi * 3 / 2)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        var rotatedImage = ciImage.transformed(by: transform)
        
        if rotatedImage.extent.isEmpty || rotatedImage.extent == .null {
            print("Error: Rotated image has an invalid extent.")
            return
        }
        
        // 範囲を正規化
        let extent = rotatedImage.extent
        rotatedImage = rotatedImage.transformed(by: CGAffineTransform(translationX: -extent.origin.x, y: -extent.origin.y))
        
        let context = CIContext()
        var newPixelBuffer: CVPixelBuffer?
        let width = Int(rotatedImage.extent.width)
        let height = Int(rotatedImage.extent.height)
        let pixelBufferOptions: [CFString: Any] = [
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32BGRA,
                                         pixelBufferOptions as CFDictionary,
                                         &newPixelBuffer)
        guard status == kCVReturnSuccess, let outputPixelBuffer = newPixelBuffer else {
            print("Error: Could not create new CVPixelBuffer.")
            return
        }
        
        context.render(rotatedImage, to: outputPixelBuffer)
        pixelBufferList.append(outputPixelBuffer)
        
        self.runModel(outputPixelBuffer)
        print("timer")
    }
    
    func recordVideo() {
        self.isRecording.toggle()
        self.currentFrameIndex = 0
        if self.isRecording {
            stopPlayback() // 既存のタイマーを停止
            let frameRate = 30.0
            self.timer = Timer.scheduledTimer(withTimeInterval: 1/frameRate, repeats: true) { _ in
                withAnimation {
                    let image: UIImage = self.analyzedImageList[self.currentFrameIndex]["image"] as! UIImage
                    let result: Person? = self.analyzedImageList[self.currentFrameIndex]["result"] as? Person
                    if result != nil {
                        self.overlayView?.draw(at: image, person: result!)
                    } else {
                        self.overlayView?.draw(at: image)
                    }
                    self.currentFrameIndex = self.currentFrameIndex + 1
                    let sec = Int(self.currentFrameIndex / 30)
                    self.recordingTime = "00:00:\(String(format: "%02d", sec))"
                }
            }
        }
    }
    
    // 再生を停止する
    private func stopPlayback() {
        timer?.invalidate()
        timer = nil
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
    
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let presentationTimeStamp: CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
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
                let (result, _) = try estimator.estimateSinglePose(
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
                    var resultData = Dictionary<String, Any>()
                    if result.score < self.minimumScore {
                        self.overlayView?.draw(at: image)
                        resultData["image"] = image
                        resultData["result"] = nil
                        self.analyzedImageList.append(resultData)
                    } else {
                        // Visualize the pose estimation result.
                        self.overlayView?.draw(at: image, person: result)
                        resultData["image"] = image
                        resultData["result"] = result
                        self.analyzedImageList.append(resultData)
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
