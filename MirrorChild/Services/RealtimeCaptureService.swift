import Foundation
import ReplayKit
import UIKit
import Vision
import CoreImage
import UserNotifications

// 代理协议，用于接收实时屏幕帧和识别结果
protocol RealtimeCaptureDelegate: AnyObject {
    func didCaptureFrame(_ image: UIImage, timestamp: TimeInterval)
    func didRecognizeContent(_ results: [Any], on image: UIImage)
    func captureDidFail(with error: Error)
}

class RealtimeCaptureService: NSObject, ObservableObject {
    static let shared = RealtimeCaptureService()
    
    // 发布属性，可在SwiftUI中观察
    @Published var isCapturing = false
    @Published var lastCapturedImage: UIImage?
    @Published var captureRate: Double = 2.0 // 每秒捕获帧数
    @Published var recognizedText: String = ""
    @Published var recognizedElements: [String] = []
    @Published var processingEnabled = true // 是否启用处理
    
    // 委托
    weak var delegate: RealtimeCaptureDelegate?
    
    // RPScreenRecorder实例
    private let recorder = RPScreenRecorder.shared()
    
    // 处理队列和计时控制
    private let processingQueue = DispatchQueue(label: "com.mirrochild.imageProcessing", qos: .userInitiated)
    private var lastCaptureTime = Date()
    private var captureThrottleInterval: TimeInterval {
        return 1.0 / captureRate
    }
    
    // 识别请求
    private var textRecognitionRequest: VNRecognizeTextRequest?
    private var elementRecognitionRequest: VNRecognizeTextRequest?
    
    // 后台任务标识符
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // 预览模式检测
    private var isRunningInPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    override init() {
        super.init()
        setupVisionRequests()
        
        // 监听应用进入后台的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        // 监听应用回到前台的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // 设置Vision识别请求
    private func setupVisionRequests() {
        // 文本识别请求
        textRecognitionRequest = VNRecognizeTextRequest { [weak self] (request, error) in
            guard let self = self, let results = request.results as? [VNRecognizedTextObservation], error == nil else { return }
            
            let recognizedStrings = results.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            DispatchQueue.main.async {
                self.recognizedText = recognizedStrings.joined(separator: "\n")
                if let delegate = self.delegate, let lastImage = self.lastCapturedImage {
                    delegate.didRecognizeContent(results, on: lastImage)
                }
            }
        }
        textRecognitionRequest?.recognitionLevel = .accurate
        textRecognitionRequest?.usesLanguageCorrection = true
        
        // UI元素识别请求（这里简化使用文本识别）
        elementRecognitionRequest = VNRecognizeTextRequest { [weak self] (request, error) in
            guard let self = self, let results = request.results as? [VNRecognizedTextObservation], error == nil else { return }
            
            // 假设UI元素都有特定格式或特征，这里简化处理
            let potentialElements = results.compactMap { observation -> String? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                // 这里可以添加过滤逻辑，识别按钮、标签等UI元素
                return candidate.string
            }
            
            DispatchQueue.main.async {
                self.recognizedElements = potentialElements
            }
        }
        elementRecognitionRequest?.recognitionLevel = .fast
    }
    
    // 开始实时捕获
    func startCapture(completion: @escaping (Bool, Error?) -> Void) {
        guard !isCapturing else {
            completion(true, nil)
            return
        }
        
        // 检查权限和可用性
        guard recorder.isAvailable else {
            let error = NSError(domain: "com.mirrochild.realtimecapture", 
                                code: 1, 
                                userInfo: [NSLocalizedDescriptionKey: "Screen recording is not available on this device"])
            completion(false, error)
            return
        }
        
        // 开始捕获
        recorder.startCapture { [weak self] (sampleBuffer, bufferType, error) in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isCapturing = false
                    self.delegate?.captureDidFail(with: error)
                }
                return
            }
            
            // 只处理视频缓冲区
            guard bufferType == .video else { return }
            
            // 控制捕获频率
            let now = Date()
            if now.timeIntervalSince(self.lastCaptureTime) < self.captureThrottleInterval {
                return
            }
            self.lastCaptureTime = now
            
            // 处理帧
            self.processingQueue.async {
                self.processVideoFrame(sampleBuffer)
            }
            
        } completionHandler: { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    self.isCapturing = false
                    completion(false, error)
                    return
                }
                
                self.isCapturing = true
                completion(true, nil)
            }
        }
    }
    
    // 停止捕获
    func stopCapture(completion: ((Error?) -> Void)? = nil) {
        guard isCapturing else {
            completion?(nil)
            return
        }
        
        // 结束后台任务
        endBackgroundTask()
        
        recorder.stopCapture { [weak self] error in
            DispatchQueue.main.async {
                self?.isCapturing = false
                completion?(error)
            }
        }
    }
    
    // 处理视频帧
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 创建CIImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        
        // 转换为UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async {
            self.lastCapturedImage = image
            
            // 通知代理
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            self.delegate?.didCaptureFrame(image, timestamp: timestamp)
            
            // 如果启用了处理，执行识别
            if self.processingEnabled {
                self.performRecognition(on: ciImage)
            }
        }
        
        // 保存捕获的帧（可以添加到ScreenCaptureManager的捕获帧数组中）
        // 这里可以扩展功能，将捕获的帧和识别结果保存起来
    }
    
    // 执行图像识别
    private func performRecognition(on ciImage: CIImage) {
        guard let textRequest = textRecognitionRequest, let elementRequest = elementRecognitionRequest else { return }
        
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        processingQueue.async {
            do {
                // 执行文本识别
                try imageRequestHandler.perform([textRequest])
                
                // 执行UI元素识别
                try imageRequestHandler.perform([elementRequest])
            } catch {
                print("Failed to perform image recognition: \(error)")
            }
        }
    }
    
    // 手动处理指定图像
    func processImage(_ image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        performRecognition(on: ciImage)
    }
    
    // 设置每秒捕获帧数
    func setCaptureRate(_ framesPerSecond: Double) {
        captureRate = max(0.5, min(framesPerSecond, 10.0)) // 限制在0.5-10帧/秒
    }
    
    // 启用/禁用处理
    func setProcessingEnabled(_ enabled: Bool) {
        processingEnabled = enabled
    }
    
    // MARK: - 后台运行支持
    
    // 应用将进入后台
    @objc private func handleAppWillResignActive() {
        // 如果正在捕获，则开始后台任务
        if isCapturing {
            beginBackgroundTask()
        }
    }
    
    // 应用回到前台
    @objc private func handleAppDidBecomeActive() {
        // 结束后台任务
        endBackgroundTask()
    }
    
    // 开始后台任务
    private func beginBackgroundTask() {
        // 避免在预览模式执行
        guard !isRunningInPreview else { return }
        
        // 结束之前的后台任务（如果有）
        endBackgroundTask()
        
        // 开始新的后台任务
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // 后台任务即将过期的回调
            print("实时捕获后台任务即将过期")
            self?.endBackgroundTask()
        }
        
        print("已开始实时捕获后台任务，ID: \(backgroundTask)")
        
        // 显示一个本地通知，告知用户应用在后台捕获屏幕
        showBackgroundCaptureNotification()
    }
    
    // 结束后台任务
    private func endBackgroundTask() {
        guard !isRunningInPreview, backgroundTask != .invalid else { return }
        
        print("结束实时捕获后台任务，ID: \(backgroundTask)")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    // 显示后台捕获通知
    private func showBackgroundCaptureNotification() {
        let content = UNMutableNotificationContent()
        content.title = "实时屏幕捕获"
        content.body = "MirrorChild正在后台运行屏幕捕获和识别"
        content.sound = .none
        
        // 立即触发通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "backgroundRealtimeCapture", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送后台实时捕获通知失败: \(error)")
            }
        }
    }
} 