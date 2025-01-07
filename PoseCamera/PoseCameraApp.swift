//
//  PoseCameraApp.swift
//  PoseCamera
//
//  Created by 広上駆 on 2024/10/26.
//

import SwiftUI
import SwiftData

@main
struct PoseCameraApp: App {
    #if targetEnvironment(simulator)
    var body: some Scene {
        WindowGroup {
            SimpleVideoCaptureViewMock(presenter: SimpleVideoCapturePresenterMock())
        }
    }
    #else
    var body: some Scene {
        WindowGroup {
            SimpleVideoCaptureView(presenter: SimpleVideoCapturePresenter())
        }
    }
    #endif
}
