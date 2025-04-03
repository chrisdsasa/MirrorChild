import Foundation
import ReplayKit
import Combine
import SwiftUI

class ScreenCaptureManager: NSObject, ObservableObject {
    static let shared = ScreenCaptureManager()
    
    private let recorder = RPScreenRecorder.shared()
    private var isScreenRecordingAvailable: Bool {
        return recorder.isAvailable
    }
    
    @Published var isRecording = false
    @Published var error: Error?
    @Published var permissionStatus: PermissionStatus = .notDetermined
    
    // For preview only
    @Published var previewFrames: [UIImage] = []
    private var frameTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    enum PermissionStatus {
        case notDetermined, denied, authorized
    }
    
    override init() {
        super.init()
        // Listen for app entering background
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                guard let self = self, self.isRecording else { return }
                self.stopCapture()
            }
            .store(in: &cancellables)
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
        
        // First ensure we have permissions
        requestScreenCapturePermission { [weak self] granted in
            guard let self = self else { return }
            
            if !granted {
                let error = NSError(domain: "com.mirrochild.screenrecording", 
                                   code: 2,
                                   userInfo: [NSLocalizedDescriptionKey: "Screen recording permission was denied."])
                completion(false, error)
                return
            }
            
            // Now that we have permission, start the actual recording
            self.recorder.startCapture { [weak self] (buffer, bufferType, error) in
                if let error = error {
                    self?.error = error
                    self?.isRecording = false
                }
                
                // Here you would process the CMSampleBuffer to:
                // 1. Extract frames for preview
                // 2. Send to server if needed
                // 3. Process for AI analysis, etc.
                
            } completionHandler: { [weak self] error in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = error
                    self.isRecording = false
                    completion(false, error)
                    return
                }
                
                self.isRecording = true
                
                // For demo purposes only - simulate receiving frames
                self.startGeneratingPreviewFrames()
                
                completion(true, nil)
            }
        }
    }
    
    func stopCapture() {
        guard isRecording else { return }
        
        stopGeneratingPreviewFrames()
        
        recorder.stopCapture { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error
                }
                self?.isRecording = false
            }
        }
    }
    
    // MARK: - Demo Methods (for UI preview only)
    
    private func startGeneratingPreviewFrames() {
        // This simulates getting frames from the actual screen capture
        // In a real implementation, you would process CMSampleBuffers from ReplayKit
        frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Generate a simple colored rectangle as a "frame"
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 350))
            let image = renderer.image { ctx in
                let colors: [UIColor] = [.systemBlue, .systemGreen, .systemRed, .systemPurple, .systemOrange]
                let randomColor = colors.randomElement()!
                ctx.cgContext.setFillColor(randomColor.cgColor)
                ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 200, height: 350))
            }
            
            DispatchQueue.main.async {
                if self.previewFrames.count > 3 {
                    self.previewFrames.removeFirst()
                }
                self.previewFrames.append(image)
            }
        }
        frameTimer?.fire()
    }
    
    private func stopGeneratingPreviewFrames() {
        frameTimer?.invalidate()
        frameTimer = nil
        previewFrames.removeAll()
    }
} 