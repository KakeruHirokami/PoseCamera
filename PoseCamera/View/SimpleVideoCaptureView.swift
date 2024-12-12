//
//  SimpleVideoCaptureView.swift
//  PoseCamera
//
//  Created by 広上駆 on 2024/10/27.
//

import SwiftUI

extension CALayer: @retroactive ObservableObject {}

struct SimpleVideoCaptureView: View {
    @ObservedObject
    var presenter: SimpleVideoCapturePresenter
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Button(action: {
                    print("a")
                }, label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 25, height: 25)
                        .foregroundColor(.white)
                })
                .padding(.horizontal)
                Spacer()
                Text(presenter.recordingTime).foregroundColor(.white)
                Spacer()
                Button(action: {
                    presenter.apply(inputs: .switchInAndOutCamera)
                }, label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .frame(width: 25, height: 25)
                        .foregroundColor(.white)
                })
                .padding(.horizontal)
            }
            ZStack(alignment: .bottom) {
                PoseEstimateView(overlayView: presenter.overlayView)
                Button(action: {
                    presenter.apply(inputs: .tappedRecordingButton)
                }, label: {
                    if(presenter.isRecording) {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 5)
                                .frame(width: 80,
                                       height: 80,
                                       alignment: .center)
                                .padding()
                            // 四角形の描画
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
            self.presenter.apply(inputs: .onAppear)
        }
    }
}

struct CALayerView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController
    var caLayer: CALayer
    
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.layer.addSublayer(caLayer)
        caLayer.frame = viewController.view.layer.frame
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        caLayer.frame = uiViewController.view.layer.frame
    }
}

struct PoseEstimateView: UIViewControllerRepresentable {
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

struct SimpleVideoCaptureViewMock: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .foregroundColor(.red)
                .frame(width: .infinity, height: .infinity)
            Button(action: {
                print("test")
            }, label: {
                Circle()
                    .stroke(.white, lineWidth: 10)
                    .fill(.red)
                    .frame(width: 80,
                           height: 80,
                           alignment: .center)
                    .padding()
                
            })
        }
    }
}

struct SimpleVideoCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleVideoCaptureViewMock()
    }
}
