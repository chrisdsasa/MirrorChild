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
    
    // 添加预览模式检测属性
    private var isRunningInPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
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
    // 添加防止初始化多次的标志
    private var hasInitialized = false
    
    enum PermissionStatus {
        case notDetermined, denied, authorized
    }
    
    override init() {
        super.init()
        
        // 防止重复初始化可能导致的问题
        if hasInitialized {
            return
        }
        hasInitialized = true
        
        // 进一步延迟初始化ReplayKit相关组件，增加稳定性
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            // Set up recorder delegate
            self.recorder.delegate = self
            
            // Listen for app entering background
            NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
                .sink { [weak self] _ in
                    guard let self = self, self.isRecording else { return }
                    self.stopCapture()
                }
                .store(in: &self.cancellables)
        }
            
        // 延迟检查是否有活跃的录制会话，避免应用启动时就尝试访问
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self = self else { return }
            // Check if there's already an active session and stop it
            // 避免在模拟器或不支持的设备上调用
            if self.isScreenRecordingAvailable && self.recorder.isRecording {
                self.stopExistingRecordingSessions()
            }
        }
    }
    
    // Clean up any existing recording sessions
    private func stopExistingRecordingSessions() {
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.stopExistingRecordingSessions()
            }
            return
        }
        
        // 在预览模式下不执行
        if isRunningInPreview {
            return
        }
        
        // 添加额外保护，防止在模拟器上崩溃
        #if targetEnvironment(simulator)
        isRecording = false
        isCapturing = false
        return
        #else
        // 防止在设备不支持时执行
        guard isScreenRecordingAvailable, recorder.isAvailable else {
            isRecording = false
            isCapturing = false
            return
        }
        
        // 使用自动释放池管理内存
        autoreleasepool {
            // Only attempt to stop recording if actually recording
            if recorder.isRecording {
                recorder.stopRecording { [weak self] _,_  in 
                    // Recording stopped
                    DispatchQueue.main.async {
                        self?.isRecording = false
                    }
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
        #endif
    }
    
    // Call this to request permissions before trying to record
    func requestScreenCapturePermission(completion: @escaping (Bool) -> Void) {
        // 确保在主线程执行UI更新
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.requestScreenCapturePermission(completion: completion)
            }
            return
        }
        
        // 在预览模式下总是返回成功
        if isRunningInPreview {
            self.permissionStatus = .authorized
            DispatchQueue.main.async {
                completion(true)
            }
            return
        }
        
        // 添加额外保护，防止在模拟器上崩溃
        #if targetEnvironment(simulator)
        self.permissionStatus = .authorized
        completion(true)
        return
        #else
        // First check if recording is available on this device
        guard isScreenRecordingAvailable, recorder.isAvailable else {
            self.permissionStatus = .denied
            completion(false)
            return
        }
        
        // 避免重复请求权限
        if permissionStatus == .authorized {
            completion(true)
            return
        }
        
        // This will trigger the system permission dialog
        // iOS will show a permission popup when we call this
        recorder.isMicrophoneEnabled = true
        
        // 使用自动释放池
        autoreleasepool {
            // 开始捕获屏幕以请求权限
            recorder.startCapture { [weak self] (cmSampleBuffer, bufferType, error) in
                // Just immediately stop - we just want the permission dialog to show
                self?.recorder.stopCapture { _ in
                    // Permission has been granted if we got here without error
                    DispatchQueue.main.async {
                        self?.permissionStatus = .authorized
                        completion(true)
                    }
                }
                
                // We won't actually process any buffers here since we immediately stop
            } completionHandler: { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("请求屏幕录制权限时出错: \(error.localizedDescription)")
                        self?.error = error
                        self?.permissionStatus = .denied
                        completion(false)
                    } else {
                        // Permission granted
                        self?.permissionStatus = .authorized
                        completion(true)
                    }
                }
            }
        }
        #endif
    }
    
    func startCapture(completion: @escaping (Bool, Error?) -> Void) {
        // 明确检查是否在主线程执行UI更新
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.startCapture(completion: completion)
            }
            return
        }
        
        // 在预览模式下模拟成功
        if isRunningInPreview {
            isRecording = true
            startGeneratingPreviewFrames()
            completion(true, nil)
            return
        }
        
        // 更严格地检查录制是否可用
        guard isScreenRecordingAvailable, recorder.isAvailable else {
            let error = NSError(domain: "com.mirrochild.screenrecording", 
                               code: 1,
                               userInfo: [NSLocalizedDescriptionKey: "Screen recording is not available on this device."])
            completion(false, error)
            return
        }
        
        // 避免多次启动
        if isRecording || isCapturing {
            completion(true, nil)
            return
        }
        
        // 添加额外保护，防止在模拟器上崩溃
        #if targetEnvironment(simulator)
        // 在模拟器中，只模拟成功而不实际调用API
        isRecording = true
        startGeneratingPreviewFrames() 
        completion(true, nil)
        return
        #else
        // First ensure we have permissions
        requestScreenCapturePermission { [weak self] granted in
            guard let self = self else { 
                completion(false, nil)
                return 
            }
            
            if !granted {
                let error = NSError(domain: "com.mirrochild.screenrecording", 
                                   code: 2,
                                   userInfo: [NSLocalizedDescriptionKey: "Screen recording permission was denied."])
                completion(false, error)
                return
            }
            
            // 确保在主线程执行
            DispatchQueue.main.async {
                // 捕获任何可能的异常
                autoreleasepool {
                    // Now that we have permission, start the actual recording
                    self.recorder.startCapture { [weak self] (buffer, bufferType, error) in
                        if let error = error {
                            DispatchQueue.main.async {
                                self?.error = error
                                self?.isRecording = false
                            }
                        }
                        
                        // Here you would process the CMSampleBuffer to:
                        // 1. Extract frames for preview
                        // 2. Send to server if needed
                        // 3. Process for AI analysis, etc.
                        
                    } completionHandler: { [weak self] error in
                        guard let self = self else { return }
                        
                        DispatchQueue.main.async {
                            if let error = error {
                                self.error = error
                                self.isRecording = false
                                completion(false, error)
                            } else {
                                self.isRecording = true
                                self.isCapturing = true
                                
                                // For demo purposes only - simulate receiving frames
                                self.startGeneratingPreviewFrames()
                                
                                completion(true, nil)
                            }
                        }
                    }
                }
            }
        }
        #endif
    }
    
    func stopCapture() {
        // 确保在主线程执行UI更新
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.stopCapture()
            }
            return
        }
        
        guard isRecording else { return }
        
        stopGeneratingPreviewFrames()
        
        // 在预览模式下仅重置状态
        if isRunningInPreview {
            isRecording = false
            return
        }
        
        // 添加额外保护，防止在模拟器上崩溃
        #if targetEnvironment(simulator)
        isRecording = false
        isCapturing = false
        return
        #else
        // 防止在设备不支持时执行
        guard isScreenRecordingAvailable, recorder.isAvailable else {
            isRecording = false
            isCapturing = false
            return
        }
        
        // 使用自动释放池
        autoreleasepool {
            recorder.stopCapture { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.error = error
                        print("停止屏幕捕获时出错: \(error.localizedDescription)")
                    }
                    self?.isRecording = false
                    self?.isCapturing = false
                }
            }
        }
        #endif
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
                // 避免强制解包
                let randomColor = colors.randomElement() ?? .systemBlue
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
    
    // MARK: - RPScreenRecorderDelegate
    
    func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        // Update our state when availability changes
        DispatchQueue.main.async {
            if !screenRecorder.isAvailable {
                self.permissionStatus = .denied
            }
        }
    }
    
    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWithError error: Error, previewViewController: RPPreviewViewController?) {
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
