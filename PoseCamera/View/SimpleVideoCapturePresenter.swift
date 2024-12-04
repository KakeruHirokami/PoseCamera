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
    @Published var photoImage: UIImage = UIImage()
    @Published var showSheet: Bool = false
    
    enum Inputs {
        case onAppear
        case tappedRecordingButton
    }
    
    init() {
        interactor.setupAVCaptureSession()
        interactor.$isRecording
            .assign(to: &$isRecording)
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
        }
    }
}
