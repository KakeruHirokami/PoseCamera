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
    enum Inputs {
        case onAppear
        case tappedRecordingButton
        case tappedCloseButton
        case onDisappear
    }
    
    init() {
        interactor.setupAVCaptureSession()
        bind()
    }
    
    deinit {
        canseables.forEach { (cancellable) in
            cancellable.cancel()
        }
    }
    
    var overlayView: UIImageView {
        return interactor.overlayView!
    }
    
    @Published var photoImage: UIImage = UIImage()
    @Published var showSheet: Bool = false
    
    func apply(inputs: Inputs) {
        switch inputs {
        case .onAppear:
            interactor.startSettion()
            break
        case .tappedRecordingButton:
            interactor.recordVideo()
        case .tappedCloseButton:
            showSheet = false
        case .onDisappear:
            interactor.stopSettion()
        }
    }
    
    private let interactor = SimpleVideoCaptureInteractor()
    private var canseables: [Cancellable] = []
    
    private func bind() {
        let photoImageObserver = interactor.$photoImage.sink { (image) in
            if let image = image {
                self.photoImage = image
            }
        }
        canseables.append(photoImageObserver)
        
        let showPhotoObserver = interactor.$showPhoto.assign(to: \.showSheet, on: self)
        canseables.append(showPhotoObserver)
    }
}
