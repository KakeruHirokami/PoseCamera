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
        ZStack {
            //CALayerView(caLayer: presenter.previewLayer)
            PoseEstimateView(overlayView: presenter.overlayView)
            Button(action: {
                presenter.apply(inputs: .tappedRecordingButton)
            }, label: {
                Text("動画撮影")
            })
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            self.presenter.apply(inputs: .onAppear)
        }
        .onDisappear {
            self.presenter.apply(inputs: .onDisappear)
        }
        .sheet(isPresented: $presenter.showSheet) {
            VStack {
                Image(uiImage: self.presenter.photoImage)
                    .resizable()
                    .frame(width: 200, height: 200)
                Button(action: {
                    self.presenter.apply(inputs: .tappedCloseButton)
                }) {
                    Text("Close")
                }
            }
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
        print("caLayer Frame:", caLayer.frame)
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
