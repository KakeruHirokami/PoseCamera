//
//  SimpleVideoCapturePresenter.swift
//  PoseCamera
//
//  Created by 広上駆 on 2024/10/27.
//

import Foundation
import AVKit
import Combine

final class SimpleVideoCapturePresenter: ObservableObject {
    
    private let interactor = SimpleVideoCaptureInteractor()
    @Published var isRecording: Bool = false
    @Published var recordingTime: String = "00:00:00"
    
    enum Inputs {
        case onAppear
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
    
    func apply(inputs: Inputs) {
        switch inputs {
        case .onAppear:
            interactor.startSettion()
            break
        case .tappedRecordingButton:
            interactor.recordVideo()
        case .switchInAndOutCamera:
            interactor.switchInAndOutCamera()
        }
    }
}
