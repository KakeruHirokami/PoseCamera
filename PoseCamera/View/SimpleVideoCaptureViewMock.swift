//
//  SimpleVideoCaptureView.swift
//  PoseCamera
//
//  Created by 広上駆 on 2024/10/27.
//

import SwiftUI

struct SimpleVideoCaptureViewMock: View {
    
    @ObservedObject
    var presenter: SimpleVideoCapturePresenterMock
    
    @State
    var isRecording = true
    
    let imagePath = "IMG_8376"
    let videoPath = "/Users/kakeruhirokami/Downloads/IMG_8359.MOV"
    let isVideo = false
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack(alignment: .center) {
                    Menu {
                        Button {
                            // pass
                        } label: {
                            Text(String(localized: "Contact"))
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    Spacer()
                    Text(presenter.recordingTime).foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        //pass
                    }, label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .frame(width: 30, height: 30)
                            .foregroundColor(.white)
                    })
                    .padding(.horizontal)
                }
                ZStack(alignment: .bottom) {
                    PoseEstimateViewMock(overlayView: presenter.overlayView)
                    Button(action: {
                        presenter.apply(inputs: .tappedRecordingButton, imagePath: "")
                    }, label: {
                        if(presenter.isRecording) {
                            ZStack {
                                Circle()
                                    .stroke(.white, lineWidth: 5)
                                    .frame(width: 80,
                                           height: 80,
                                           alignment: .center)
                                    .padding()
                                Rectangle()
                                    .fill(Color.red)
                                    .frame(width: 30, height: 30)
                            }
                        } else {
                            Circle()
                                .stroke(.white, lineWidth:5)
                                .fill(.red)
                                .frame(width: 80,
                                       height: 80,
                                       alignment: .center)
                                .padding()
                        }
                    })
                }
                .edgesIgnoringSafeArea(.all)
            }
            .background(Color.black)
            .onAppear {
                if isVideo {
                    self.presenter.apply(inputs: .onAppearVideo, imagePath: videoPath)
                } else {
                    self.presenter.apply(inputs: .onAppear, imagePath: imagePath)
                }
            }
        }
    }
}

struct PoseEstimateViewMock: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController
    var overlayView: UIImageView
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.addSubview(overlayView)
        overlayView.frame = viewController.view.bounds
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}
