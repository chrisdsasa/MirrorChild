import Foundation
import Combine
import UIKit
import AVFoundation

// 协调服务状态
enum CoordinatorStatus: Equatable {
    case idle
    case capturing
    case processing
    case error(Error)
    
    // 自定义实现Equatable，因为Error不一定符合Equatable
    static func == (lhs: CoordinatorStatus, rhs: CoordinatorStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.capturing, .capturing):
            return true
        case (.processing, .processing):
            return true
        case (.error, .error):
            // 只比较是否都是错误状态，不比较具体错误
            return true
        default:
            return false
        }
    }
}

// 协调服务结果
struct AssistantResponse {
    let timestamp: Date
    let query: String
    let response: String
    let screenshotURLs: [URL]
}

class CaptureCoordinatorService: ObservableObject {
    static let shared = CaptureCoordinatorService()
    
    // 状态和结果
    @Published var status: CoordinatorStatus = .idle
    @Published var latestResponse: AssistantResponse?
    @Published var processingProgress: Double = 0
    @Published var isBackgroundCapturingActive: Bool = false
    
    // 依赖的服务
    private let screenCaptureManager = ScreenCaptureManager.shared
    private let voiceCaptureManager = VoiceCaptureManager.shared
    private let openAIService = OpenAIService.shared
    
    // 后台任务标识符
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    // 内部状态追踪
    private var cancellables = Set<AnyCancellable>()
    private var lastTranscribedText: String = ""
    private var captureTimer: Timer?
    private var processingTimer: Timer?
    var captureStartTime: Date?
    
    // 最大录制时间（秒）
    private let maxCaptureTime: TimeInterval = 300 // 5分钟
    
    // 私有初始化以确保单例
    private init() {
        // 设置状态监听
        setupStateObservers()
    }
    
    // 监听各服务的状态变化
    private func setupStateObservers() {
        // 监听屏幕捕获状态
        screenCaptureManager.$isRecording
            .sink { [weak self] isRecording in
                guard let self = self else { return }
                if isRecording {
                    self.isBackgroundCapturingActive = true
                } else if self.status != .processing {
                    self.isBackgroundCapturingActive = false
                }
            }
            .store(in: &cancellables)
        
        // 监听语音转文字结果
        voiceCaptureManager.$transcribedText
            .dropFirst() // 忽略初始空值
            .debounce(for: .seconds(1), scheduler: RunLoop.main) // 减少频繁更新
            .sink { [weak self] text in
                guard let self = self, !text.isEmpty, text != self.lastTranscribedText else { return }
                
                self.lastTranscribedText = text
                
                // 如果正在进行屏幕捕获，将文本与最近的帧关联
                if self.screenCaptureManager.isRecording {
                    self.screenCaptureManager.associateTranscribedText(text)
                }
            }
            .store(in: &cancellables)
        
        // 监听应用状态变化
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                guard let self = self, self.isBackgroundCapturingActive else { return }
                self.beginBackgroundTask()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.endBackgroundTask()
            }
            .store(in: &cancellables)
    }
    
    // 开始后台捕获
    func startBackgroundCapture(completion: @escaping (Bool, Error?) -> Void) {
        // 如果已经在捕获，不重复启动
        if status == .capturing {
            completion(true, nil)
            return
        }
        
        // 重置状态
        status = .idle
        lastTranscribedText = ""
        captureStartTime = Date()
        
        // 启动屏幕捕获
        screenCaptureManager.startCapture { [weak self] success, error in
            guard let self = self else { return }
            
            if !success {
                if let error = error {
                    self.status = .error(error)
                }
                completion(false, error)
                return
            }
            
            // 启动语音捕获
            self.voiceCaptureManager.startRecording { success, error in
                if !success {
                    // 如果语音捕获失败，停止屏幕捕获
                    self.screenCaptureManager.stopCapture()
                    if let error = error {
                        self.status = .error(error)
                    }
                    completion(false, error)
                    return
                }
                
                // 都成功启动
                self.status = .capturing
                self.isBackgroundCapturingActive = true
                
                // 开始后台任务
                self.beginBackgroundTask()
                
                // 启动定时器，定期检查是否需要处理数据
                self.startCaptureTimer()
                
                completion(true, nil)
            }
        }
    }
    
    // 停止捕获并处理数据
    func stopCaptureAndProcess(completion: @escaping (Result<AssistantResponse, Error>) -> Void) {
        // 停止定时器
        captureTimer?.invalidate()
        captureTimer = nil
        
        // 如果未在捕获，直接返回错误
        guard status == .capturing else {
            let error = NSError(domain: "com.mirrochild.coordinator", 
                               code: 1, 
                               userInfo: [NSLocalizedDescriptionKey: "没有活动的捕获会话"])
            completion(.failure(error))
            return
        }
        
        // 更新状态
        status = .processing
        processingProgress = 0.1
        
        // 停止录音但保持屏幕捕获直到处理完成
        voiceCaptureManager.stopRecording()
        
        // 获取最终的语音文本
        let finalText = lastTranscribedText
        
        // 开始处理数据
        processData(text: finalText) { [weak self] result in
            guard let self = self else { return }
            
            // 完成后停止屏幕捕获
            self.screenCaptureManager.stopCapture()
            self.status = .idle
            self.processingProgress = 1.0
            
            // 清理进度定时器
            self.processingTimer?.invalidate()
            self.processingTimer = nil
            
            completion(result)
        }
    }
    
    // 立即停止所有捕获活动
    func forceStopCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        processingTimer?.invalidate()
        processingTimer = nil
        
        screenCaptureManager.stopCapture()
        voiceCaptureManager.stopRecording()
        
        status = .idle
        isBackgroundCapturingActive = false
        endBackgroundTask()
    }
    
    // 处理捕获的数据
    private func processData(text: String, completion: @escaping (Result<AssistantResponse, Error>) -> Void) {
        // 模拟处理进度
        startProcessingProgressTimer()
        
        // 获取屏幕捕获数据
        screenCaptureManager.prepareDataForOpenAI { [weak self] frames, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let frames = frames, !frames.isEmpty else {
                let error = NSError(domain: "com.mirrochild.coordinator", 
                                   code: 2, 
                                   userInfo: [NSLocalizedDescriptionKey: "没有捕获到屏幕数据"])
                completion(.failure(error))
                return
            }
            
            // 更新进度
            DispatchQueue.main.async {
                self.processingProgress = 0.4
            }
            
            // 发送到OpenAI处理
            self.openAIService.sendScreenCaptureAndVoiceData(frames: frames, transcribedText: text) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let responseText):
                        // 收集截图URL
                        var screenshotURLs: [URL] = []
                        
                        // 使用公开的captureSessionDirectory属性
                        if let directory = self.screenCaptureManager.captureSessionDirectory {
                            // 尝试保存帧中的一些截图
                            for frame in frames.prefix(5) {
                                if let url = frame.saveToFile(in: directory) {
                                    screenshotURLs.append(url)
                                }
                            }
                        }
                        
                        // 创建响应对象
                        let response = AssistantResponse(
                            timestamp: Date(),
                            query: text,
                            response: responseText,
                            screenshotURLs: screenshotURLs
                        )
                        
                        // 保存最新响应
                        self.latestResponse = response
                        
                        // 更新进度
                        self.processingProgress = 1.0
                        
                        completion(.success(response))
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    // 开始定期检查是否需要处理数据
    private func startCaptureTimer() {
        captureTimer?.invalidate()
        
        captureTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self, self.status == .capturing else { return }
            
            // 检查是否超过最大捕获时间
            if let startTime = self.captureStartTime,
               Date().timeIntervalSince(startTime) >= self.maxCaptureTime {
                
                // 自动停止并处理
                self.stopCaptureAndProcess { result in
                    switch result {
                    case .success(let response):
                        print("自动处理完成: \(response.response.prefix(50))...")
                    case .failure(let error):
                        print("自动处理失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // 模拟处理进度的定时器
    private func startProcessingProgressTimer() {
        processingTimer?.invalidate()
        processingProgress = 0.1
        
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self,
                  self.status == .processing,
                  self.processingProgress < 0.9 else {
                return
            }
            
            // 缓慢增加进度以模拟处理
            let increment = Double.random(in: 0.02...0.05)
            self.processingProgress = min(0.9, self.processingProgress + increment)
        }
    }
    
    // 开始后台任务
    private func beginBackgroundTask() {
        // 结束之前的后台任务（如果有）
        endBackgroundTask()
        
        // 开始一个新的后台任务
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // 这是后台任务即将过期的回调
            print("协调器后台任务即将过期")
            self?.endBackgroundTask()
        }
        
        print("已开始协调器后台任务，ID: \(backgroundTask)")
    }
    
    // 结束后台任务
    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        
        print("结束协调器后台任务，ID: \(backgroundTask)")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    // 检查是否有OpenAI API密钥
    var hasAPIKey: Bool {
        return openAIService.hasApiKey()
    }
    
    // 设置OpenAI API密钥
    func setAPIKey(_ key: String) {
        openAIService.setApiKey(key)
    }
} 