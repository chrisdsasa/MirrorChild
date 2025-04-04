import Foundation
import ReplayKit
import Combine
import SwiftUI
import AVFoundation
import UIKit

class ScreenCaptureManager: NSObject, ObservableObject, RPScreenRecorderDelegate {
    static let shared = ScreenCaptureManager()
    
    private let recorder = RPScreenRecorder.shared()
    private var isScreenRecordingAvailable: Bool {
        return recorder.isAvailable
    }
    
    @Published var isRecording = false
    @Published var error: Error?
    @Published var permissionStatus: PermissionStatus = .notDetermined
    
    // For capture preview
    @Published var previewFrames: [UIImage] = []
    private var frameTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let maxFrameCount = 4
    private let frameProcessingQueue = DispatchQueue(label: "com.mirrochild.frameprocessing", qos: .userInitiated)
    
    // Keep track of capturing state
    private var isCapturing = false
    
    enum PermissionStatus {
        case notDetermined, denied, authorized
    }
    
    override init() {
        super.init()
        
        // Set up recorder delegate
        recorder.delegate = self
        
        // Listen for app entering background
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                guard let self = self, self.isRecording else { return }
                self.stopCapture()
            }
            .store(in: &cancellables)
            
        // Check if there's already an active session and stop it
        if recorder.isRecording {
            stopExistingRecordingSessions()
        }
    }
    
    // Clean up any existing recording sessions
    private func stopExistingRecordingSessions() {
        // Only attempt to stop recording if actually recording
        if recorder.isRecording {
            recorder.stopRecording { _,_  in 
                // Recording stopped
            }
        }
        
        // Only attempt to stop capture if our internal state indicates we're capturing
        if isCapturing {
            recorder.stopCapture { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        // Log the error, but don't update UI state since this is just cleanup
                        print("Error stopping existing capture: \(error.localizedDescription)")
                    }
                    self?.isCapturing = false
                    self?.isRecording = false
                }
            }
        }
    }
    
    // Call this to request permissions before trying to record
    func requestScreenCapturePermission(completion: @escaping (Bool) -> Void) {
        // On iOS, we need to use RPScreenRecorder's APIs to request permissions
        // This is the proper way to trigger the system permission dialog
        
        // First check if recording is available on this device
        guard isScreenRecordingAvailable else {
            self.permissionStatus = .denied
            completion(false)
            return
        }
        
        // This will trigger the system permission dialog
        // iOS will show a permission popup when we call this
        RPScreenRecorder.shared().isMicrophoneEnabled = true
        RPScreenRecorder.shared().startCapture { [weak self] (cmSampleBuffer, bufferType, error) in
            // Just immediately stop - we just want the permission dialog to show
            RPScreenRecorder.shared().stopCapture { _ in
                // Permission has been granted if we got here without error
                self?.permissionStatus = .authorized
                completion(true)
            }
            
            // We won't actually process any buffers here since we immediately stop
        } completionHandler: { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error
                    self?.permissionStatus = .denied
                    completion(false)
                    return
                }
                
                // Permission granted
                self?.permissionStatus = .authorized
                completion(true)
            }
        }
    }
    
    func startCapture(completion: @escaping (Bool, Error?) -> Void) {
        guard isScreenRecordingAvailable else {
            let error = NSError(domain: "com.mirrochild.screenrecording", 
                               code: 1,
                               userInfo: [NSLocalizedDescriptionKey: "Screen recording is not available on this device."])
            completion(false, error)
            return
        }
        
        // Don't start if already recording
        if isRecording {
            completion(true, nil)
            return
        }
        
        // Make sure any existing sessions are stopped first, but only if we think we're capturing
        if isCapturing {
            stopExistingRecordingSessions()
        }
        
        // Clear any existing preview frames
        previewFrames.removeAll()
        
        // Wait a moment for cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Update internal state
            self.isCapturing = true
            
            // Start the actual recording
            self.recorder.startCapture(handler: { [weak self] (cmSampleBuffer, bufferType, error) in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        self.error = error
                        self.isRecording = false
                        self.isCapturing = false
                    }
                    return
                }
                
                // Process screen buffers only (not audio)
                if bufferType == .video {
                    self.processVideoFrame(cmSampleBuffer)
                }
                
            }, completionHandler: { [weak self] (error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        self.error = error
                        self.isRecording = false
                        self.isCapturing = false
                        
                        // Check if this is the "already active" error
                        let nsError = error as NSError
                        if nsError.localizedDescription.contains("already active") {
                            // Try to stop and restart
                            self.stopExistingRecordingSessions()
                            // Notify user to try again
                            completion(false, NSError(domain: "com.mirrochild.screenrecording", 
                                                   code: 3,
                                                   userInfo: [NSLocalizedDescriptionKey: "Please try again in a moment. Cleaning up previous recording session."]))
                            return
                        }
                        
                        self.permissionStatus = .denied
                        completion(false, error)
                        return
                    }
                    
                    self.isRecording = true
                    self.isCapturing = true
                    self.permissionStatus = .authorized
                    completion(true, nil)
                }
            })
        }
    }
    
    func stopCapture() {
        // Only attempt to stop if our app thinks we're recording or capturing
        guard isRecording || isCapturing else { return }
        
        // Clear preview frames when stopping
        DispatchQueue.main.async {
            self.previewFrames.removeAll()
        }
        
        // Update internal state first to avoid multiple stop attempts
        isCapturing = false
        isRecording = false
        
        recorder.stopCapture { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    // Just log the error but don't update UI state since we're stopping
                    print("Error in stopCapture: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Process Real Screen Capture Frames
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        // Only process occasional frames to avoid overloading
        guard isRecording, 
              previewFrames.count < maxFrameCount,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Process frames on a background queue to avoid UI stuttering
        frameProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Convert CMSampleBuffer to UIImage
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            // Scale down image to save memory
            let uiImage = UIImage(cgImage: cgImage).scaledForPreview()
            
            // Update the UI on the main thread
            DispatchQueue.main.async {
                // If we already have max frames, remove the oldest one
                if self.previewFrames.count >= self.maxFrameCount {
                    self.previewFrames.remove(at: 0)
                }
                
                // Add the new frame
                self.previewFrames.append(uiImage)
            }
        }
    }
    
    // MARK: - RPScreenRecorderDelegate
    
    func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        // Update our state when availability changes
        DispatchQueue.main.async {
            if !screenRecorder.isAvailable {
                self.permissionStatus = .denied
            }
        }
    }
    
    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith error: Error, previewController: RPPreviewViewController?) {
        // Handle recording stopped unexpectedly
        DispatchQueue.main.async {
            self.isRecording = false
            self.isCapturing = false
            self.error = error
        }
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    // Scale down images for the preview
    func scaledForPreview() -> UIImage {
        let maxDimension: CGFloat = 300
        
        // Calculate new size
        let originalSize = self.size
        var newSize = originalSize
        
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            let widthRatio = maxDimension / originalSize.width
            let heightRatio = maxDimension / originalSize.height
            let ratio = min(widthRatio, heightRatio)
            
            newSize = CGSize(width: originalSize.width * ratio, 
                             height: originalSize.height * ratio)
        }
        
        // Draw and return the resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        self.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
} 
