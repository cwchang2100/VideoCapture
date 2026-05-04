//
//  CameraManager.swift
//  VideoCapture
//
//  Created by Chih-Wei Chang on 2026/5/5.
//

import Foundation
import AVFoundation
import UIKit
import Combine
import CoreImage

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var isAuthorized: Bool = false
    @Published var errorMessage: String?
    @Published var frameCount: Int = 0
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutputQueue = DispatchQueue(label: "camera.video.output.queue")
    
    private let videoOutput = AVCaptureVideoDataOutput()
    
    override init() {
        super.init()
        checkPermission()
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.errorMessage = "Camera permission denied."
                    }
                }
            }

        case .denied, .restricted:
            isAuthorized = false
            errorMessage = "Camera permission denied or restricted."

        @unknown default:
            isAuthorized = false
            errorMessage = "Unknown camera permission status."
        }
    }

    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            // Remove old inputs
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            
            // Remove old outputs
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }
            
            guard let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Back camera not available."
                }
                self.session.commitConfiguration()
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)

                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Cannot add camera input."
                    }
                    self.session.commitConfiguration()
                    return
                }

                self.configureVideoOutput()
                
                self.session.commitConfiguration()
                self.start()

            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
                self.session.commitConfiguration()
            }
        }
    }

    private func configureVideoOutput() {
        /*
         kCVPixelFormatType_32BGRA:
         Good for CoreImage, UIKit, OpenCV-style processing.
         For Core ML / YOLO, you may also use:
         kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
         */
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]
        
        // If processing is slow, drop late frames instead of queueing them.
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(
            self,
            queue: videoOutputQueue
        )
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        } else {
            DispatchQueue.main.async {
                self.errorMessage = "Cannot add video output."
            }
            return
        }

        // Optional: set orientation

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }

        }
    }
    
    func start() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        /*
         這裡就是每一幀影像。

         pixelBuffer 型別是 CVPixelBuffer。
         你可以在這裡做：
         - Core ML / YOLO inference
         - OpenCV processing
         - convert to UIImage
         - save frame
         - barcode / face detection
        */

        processFrame(pixelBuffer)

        DispatchQueue.main.async {
            self.frameCount += 1
        }
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        // Example 1: get width / height
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Debug only. Do not print every frame in real app.
        if frameCount % 60 == 0 {
            print("Frame size: \(width)x\(height)")
        }

        // Example 2: convert to CIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // You can pass ciImage or pixelBuffer to your AI pipeline here.
        _ = ciImage
    }
}
