import Foundation
import ReplayKit
import Combine
import SwiftUI
import AVFoundation
import UIKit
import UserNotifications

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
    
    // 后台任务标识符
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // 存储录制的帧和相关文本
    private var capturedFrames: [CapturedFrame] = []
    private let maxStoredFrames = 300 // 存储约5分钟的帧（假设每秒1帧）
    
    // 保存文件的目录
    var captureSessionDirectory: URL? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let captureDir = documentDirectory.appendingPathComponent("ScreenCaptures")
        
        // 确保目录存在
        if !fileManager.fileExists(atPath: captureDir.path) {
            do {
                try fileManager.createDirectory(at: captureDir, withIntermediateDirectories: true)
            } catch {
                print("创建屏幕捕获目录失败: \(error)")
                return nil
            }
        }
        
        return captureDir
    }
    
    // 当前捕获会话的ID
    private var currentSessionId: String = UUID().uuidString
    
    // 捕获数据结构
    struct CapturedFrame {
        let timestamp: Date
        let image: UIImage
        var transcribedText: String?
        let sessionId: String
        
        // 将帧保存到本地文件系统
        func saveToFile(in directory: URL) -> URL? {
            // 创建文件名：sessionId_timestamp.jpg
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss_SSS"
            let timeString = formatter.string(from: timestamp)
            let fileName = "\(sessionId)_\(timeString).jpg"
            
            let fileURL = directory.appendingPathComponent(fileName)
            
            // 保存图像到JPEG文件
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                do {
                    try imageData.write(to: fileURL)
                    return fileURL
                } catch {
                    print("保存帧图像失败: \(error)")
                    return nil
                }
            }
            
            return nil
        }
    }
    
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
                    // 当应用进入后台且正在录屏时，启动后台任务
                    self.beginBackgroundTask()
                }
                .store(in: &self.cancellables)
                
            // 监听应用回到前台的通知
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    // 应用恢复前台时，结束后台任务
                    self.endBackgroundTask()
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
    
    // 开始后台任务
    private func beginBackgroundTask() {
        guard !isRunningInPreview else { return }
        
        // 结束之前的后台任务（如果有）
        endBackgroundTask()
        
        // 开始一个新的后台任务
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // 这是后台任务即将过期的回调
            print("屏幕录制后台任务即将过期")
            self?.endBackgroundTask()
        }
        
        print("已开始屏幕录制后台任务，ID: \(backgroundTask)")
        
        // 显示一个本地通知，告知用户应用在后台录屏
        showBackgroundRecordingNotification()
    }
    
    // 显示后台录制通知
    private func showBackgroundRecordingNotification() {
        let content = UNMutableNotificationContent()
        content.title = "屏幕录制进行中"
        content.body = "MirrorChild正在后台继续录制屏幕"
        content.sound = .none
        
        // 立即触发通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "backgroundScreenRecording", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送后台屏幕录制通知失败: \(error)")
            }
        }
    }
    
    // 结束后台任务
    private func endBackgroundTask() {
        guard !isRunningInPreview, backgroundTask != .invalid else { return }
        
        print("结束屏幕录制后台任务，ID: \(backgroundTask)")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
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
        
        // 创建新的捕获会话ID
        currentSessionId = UUID().uuidString
        
        // 清空已存储的帧
        capturedFrames.removeAll()
        
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
                            return
                        }
                        
                        // 仅处理视频缓冲区
                        guard bufferType == .video, let strongSelf = self else { return }
                        
                        // 将CMSampleBuffer转换为UIImage并保存
                        strongSelf.processAndStoreVideoFrame(buffer)
                        
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
                                
                                // 开始后台任务，确保应用进入后台时继续捕获
                                self.beginBackgroundTask()
                                
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
    
    // 处理并存储视频帧
    private func processAndStoreVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording, 
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // 在后台线程处理帧以避免阻塞UI
        frameProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 转换CMSampleBuffer为UIImage
            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            
            // 缩小图像以节省内存
            let uiImage = UIImage(cgImage: cgImage).scaledForPreview()
            
            // 只对部分帧进行存储（例如每秒一帧）以节省空间
            if self.shouldStoreThisFrame() {
                // 创建已捕获的帧对象
                let frame = CapturedFrame(
                    timestamp: Date(),
                    image: uiImage,
                    transcribedText: nil, // 后续与语音识别文本关联
                    sessionId: self.currentSessionId
                )
                
                // 保存帧到文件系统
                if let directory = self.captureSessionDirectory {
                    _ = frame.saveToFile(in: directory)
                }
                
                // 添加到内存中的帧缓存
                DispatchQueue.main.async {
                    self.capturedFrames.append(frame)
                    
                    // 如果超出最大存储量，移除最旧的帧
                    if self.capturedFrames.count > self.maxStoredFrames {
                        self.capturedFrames.removeFirst()
                    }
                    
                    // 更新预览帧（仅保留几帧用于UI展示）
                    if self.previewFrames.count >= self.maxFrameCount {
                        self.previewFrames.remove(at: 0)
                    }
                    self.previewFrames.append(uiImage)
                }
            }
        }
    }
    
    // 决定是否存储当前帧（控制存储频率）
    private func shouldStoreThisFrame() -> Bool {
        // 简单实现：根据时间戳确定存储频率（例如每秒存储一帧）
        // 这可以根据需要调整
        var lastCaptureTime = Date(timeIntervalSince1970: 0)
        
        let now = Date()
        let timeSinceLastCapture = now.timeIntervalSince(lastCaptureTime)
        
        // 控制捕获频率（每秒一帧）
        if timeSinceLastCapture >= 1.0 {
            lastCaptureTime = now
            return true
        }
        
        return false
    }
    
    // 将语音文本关联到最近的帧
    func associateTranscribedText(_ text: String) {
        guard !capturedFrames.isEmpty else { return }
        
        // 找到最近添加的帧并关联文本
        if var lastFrame = capturedFrames.last {
            lastFrame.transcribedText = text
            
            // 更新帧数组中的元素
            if let lastIndex = capturedFrames.indices.last {
                capturedFrames[lastIndex] = lastFrame
            }
        }
    }
    
    // 准备发送数据到OpenAI API
    func prepareDataForOpenAI(completion: @escaping ([CapturedFrame]?, Error?) -> Void) {
        // 如果没有捕获的帧，返回错误
        guard !capturedFrames.isEmpty else {
            let error = NSError(domain: "com.mirrochild.screenrecording", 
                              code: 3,
                              userInfo: [NSLocalizedDescriptionKey: "没有可用的屏幕捕获数据。"])
            completion(nil, error)
            return
        }
        
        // 返回捕获的帧供外部处理
        completion(capturedFrames, nil)
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
        
        // 结束后台任务
        endBackgroundTask()
        
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
