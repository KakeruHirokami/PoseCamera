//
//  SimpleVideoCapturePresenterMock.swift
//  PoseCamera
//
//  Created by 広上駆 on 2024/12/22.
//

import Foundation
import AVKit
import Combine

final class SimpleVideoCapturePresenterMock: ObservableObject {
    
    private let interactor = SimpleVideoCaptureInteractorMock()
    @Published var isRecording: Bool = false
    @Published var recordingTime: String = "00:00:00"
    
    enum Inputs {
        case onAppear
        case onAppearVideo
        case tappedRecordingButton
        case switchInAndOutCamera
    }
    
    init() {
        interactor.setupAVCaptureSession()
        interactor.$isRecording
            .assign(to: &$isRecording)
        interactor.$recordingTime
            .assign(to: &$recordingTime)
    }
    
    var overlayView: UIImageView {
        return interactor.overlayView!
    }
    
    func apply(inputs: Inputs, imagePath: String) {
        switch inputs {
        case .onAppear:
            interactor.startSession(uiImage: UIImage(named: imagePath)!)
            break
        case .onAppearVideo:
            interactor.startSessionVideo(asset: AVAsset(url: URL(fileURLWithPath: imagePath)))
            break
        case .tappedRecordingButton:
            interactor.recordVideo()
        case .switchInAndOutCamera:
            break
        }
    }
}
