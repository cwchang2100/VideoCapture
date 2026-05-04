//
//  ContentView.swift
//  VideoCapture
//
//  Created by Chih-Wei Chang on 2026/5/5.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    
    var body: some View {
        ZStack(alignment: .top) {
            if cameraManager.isAuthorized {
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
                
                Text("Frames: \(cameraManager.frameCount)")
                    .font(.headline)
                    .padding()
                    .background(.black.opacity(0.6))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 50)
            } else {
                VStack(spacing: 12) {
                    Text("Camera is not available")
                        .font(.headline)
                    
                    if let error = cameraManager.errorMessage {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
            }
        }
        .onAppear {
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
        }
    }
}

#Preview {
    ContentView()
}
