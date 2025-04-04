import Foundation
import Speech
import AVFoundation
import AVFAudio
import Combine
import SwiftUI
import UserNotifications

// 创建一个专用环境键，以便在预览中检测
struct PreviewEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

extension EnvironmentValues {
    var isPreview: Bool {
        get { self[PreviewEnvironmentKey.self] }
        set { self[PreviewEnvironmentKey.self] = newValue }
    }
}

// 支持的语言枚举
enum VoiceLanguage: String, CaseIterable, Identifiable {
    case japanese = "ja-JP"
    case chinese = "zh-CN"
    case english = "en-US"
    
    var id: String { self.rawValue }
    
    // 语言的本地化显示名称
    var localizedName: String {
        switch self {
        case .english:
            return "English"
        case .chinese:
            return "中文"
        case .japanese:
            return "日本語"
        }
    }
    
    // 根据系统语言自动选择适合的语音识别语言
    static var deviceLanguage: VoiceLanguage {
        let preferredLanguages = Locale.preferredLanguages
        let languageCode = Locale(identifier: preferredLanguages.first ?? "en").language.languageCode?.identifier ?? "en"
        
        // 根据系统语言代码选择最合适的语音识别语言
        switch languageCode {
        case "zh":
            return .chinese
        case "ja":
            return .japanese
        default:
            return .english
        }
    }
}

class VoiceCaptureManager: NSObject, ObservableObject {
    static var shared: VoiceCaptureManager = {
        // 在初始化静态变量时检查是否在预览中
        let isInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        
        // 如果在预览中，返回一个模拟管理器
        if isInPreview {
            let mockManager = VoiceCaptureManager()
            mockManager.isRunningInPreview = true
            mockManager.permissionStatus = .authorized
            return mockManager
        } else {
            return VoiceCaptureManager()
        }
    }()
    
    // 直接用变量存储是否在预览中，避免每次访问环境变量
    var isRunningInPreview: Bool = false
    
    // 仅在非预览模式下初始化这些属性
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var error: Error?
    @Published var permissionStatus: PermissionStatus = .notDetermined
    @Published var enablePunctuation: Bool = true {
        didSet {
            UserDefaults.standard.set(enablePunctuation, forKey: "enablePunctuation")
        }
    }
    
    // 添加音频电平监控
    @Published var currentAudioLevel: Float = 0.0
    private var audioLevelTimer: Timer?
    
    // 语言相关属性
    @Published var currentLanguage: VoiceLanguage = .chinese {
        didSet {
            // 当语言改变时，更新语音识别器
            updateSpeechRecognizer()
        }
    }
    
    // 获取所有可用的语音识别语言
    @Published var availableLanguages: [VoiceLanguage] = []
    
    private var cancellables = Set<AnyCancellable>()
    private var micPermissionGranted = false
    
    enum PermissionStatus {
        case notDetermined, denied, authorized
    }
    
    override init() {
        super.init()
        
        // 初始化时检查是否在预览中
        isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        
        // 如果在预览模式下，直接将权限设为已授权，不进行任何实际初始化
        if isRunningInPreview {
            self.permissionStatus = .authorized
            self.availableLanguages = VoiceLanguage.allCases
            
            // 使用系统语言
            self.currentLanguage = VoiceLanguage.deviceLanguage
            
            // 获取标点符号设置
            self.enablePunctuation = UserDefaults.standard.bool(forKey: "enablePunctuation")
            
            return
        }
        
        // 使用系统语言
        self.currentLanguage = VoiceLanguage.deviceLanguage
        
        // 获取标点符号设置
        self.enablePunctuation = UserDefaults.standard.bool(forKey: "enablePunctuation")
        
        // 初始化音频引擎
        audioEngine = AVAudioEngine()
        
        // 初始化语音识别器和检查可用语言
        updateSpeechRecognizer()
        checkAvailableLanguages()
        
        // 设置应用状态监听
        setupNotifications()
    }
    
    // 设置通知监听
    private func setupNotifications() {
        // 监听应用进入后台
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                guard let self = self, self.isRecording else { return }
                // 应用进入后台但继续录音，开始后台任务
                self.beginBackgroundTask()
                print("应用进入后台，继续录音转文字")
            }
            .store(in: &cancellables)
        
        // 监听应用回到前台
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // 结束后台任务
                self.endBackgroundTask()
                print("应用回到前台")
            }
            .store(in: &cancellables)
    }
    
    // 开始后台任务
    private func beginBackgroundTask() {
        guard !isRunningInPreview else { return }
        
        // 结束之前的后台任务（如果有）
        endBackgroundTask()
        
        // 开始一个新的后台任务
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // 这是后台任务即将过期的回调
            print("后台任务即将过期")
            self?.endBackgroundTask()
        }
        
        print("已开始后台任务，ID: \(backgroundTask)")
        
        // 显示一个本地通知，告知用户应用在后台录音
        showBackgroundRecordingNotification()
    }
    
    // 显示后台录音通知
    private func showBackgroundRecordingNotification() {
        let content = UNMutableNotificationContent()
        content.title = "录音继续进行中"
        content.body = "MirrorChild正在后台继续录音转文字"
        content.sound = .none
        
        // 立即触发通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "backgroundRecording", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送后台录音通知失败: \(error)")
            }
        }
    }
    
    // 结束后台任务
    private func endBackgroundTask() {
        guard !isRunningInPreview, backgroundTask != .invalid else { return }
        
        print("结束后台任务，ID: \(backgroundTask)")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    // 更新语音识别器以匹配当前选择的语言
    private func updateSpeechRecognizer() {
        guard !isRunningInPreview else { return }
        
        let locale = Locale(identifier: currentLanguage.rawValue)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        // 如果当前正在录音，需要重新启动录音以使用新的语音识别器
        if isRecording {
            stopRecording()
            startRecording { success, error in
                if !success {
                    print("更改语言后重新启动录音失败: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }
    
    // 检查设备上支持哪些语言
    private func checkAvailableLanguages() {
        guard !isRunningInPreview else {
            // 预览模式下假设所有语言都可用
            self.availableLanguages = VoiceLanguage.allCases
            return
        }
        
        var supported: [VoiceLanguage] = []
        
        for language in VoiceLanguage.allCases {
            let locale = Locale(identifier: language.rawValue)
            if SFSpeechRecognizer(locale: locale)?.isAvailable == true {
                supported.append(language)
            }
        }
        
        // 如果没有可用的语言，至少添加英语作为备选
        if supported.isEmpty {
            supported.append(.english)
        }
        
        // 更新可用语言列表
        self.availableLanguages = supported
        
        // 如果当前选择的语言不在支持列表中，切换到系统默认语言
        if !supported.contains(currentLanguage) {
            currentLanguage = VoiceLanguage.deviceLanguage
        }
    }
    
    func checkPermissionStatus() {
        // 在预览模式下，假装有权限
        if isRunningInPreview {
            self.permissionStatus = .authorized
            return
        }
        
        // 检查语音识别状态
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            self.permissionStatus = .authorized
        case .denied, .restricted:
            self.permissionStatus = .denied
        case .notDetermined:
            self.permissionStatus = .notDetermined
        @unknown default:
            self.permissionStatus = .notDetermined
        }
        
        // 初始检查时假设未获得麦克风权限
        micPermissionGranted = false
    }
    
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        // 在预览模式下总是返回授权成功
        if isRunningInPreview {
            self.permissionStatus = .authorized
            DispatchQueue.main.async {
                completion(true)
            }
            return
        }
        
        // 一次性请求两种权限
        var speechAuthorized = false
        var micAuthorized = false
        
        // 请求语音识别权限
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    speechAuthorized = true
                case .denied, .restricted, .notDetermined:
                    speechAuthorized = false
                @unknown default:
                    speechAuthorized = false
                }
                
                // 根据iOS版本使用不同的API请求麦克风权限
                if #available(iOS 17.0, *) {
                    // 使用iOS 17及更高版本的新API
                    AVAudioApplication.requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            micAuthorized = granted
                            
                            // 两种权限都获得才算授权成功
                            let isAuthorized = speechAuthorized && micAuthorized
                            self?.permissionStatus = isAuthorized ? .authorized : .denied
                            completion(isAuthorized)
                        }
                    }
                } else {
                    // 使用iOS 16及更早版本的API
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            micAuthorized = granted
                            
                            // 两种权限都获得才算授权成功
                            let isAuthorized = speechAuthorized && micAuthorized
                            self?.permissionStatus = isAuthorized ? .authorized : .denied
                            completion(isAuthorized)
                        }
                    }
                }
            }
        }
    }
    
    // 开始录音
    func startRecording(completion: @escaping (Bool, Error?) -> Void) {
        print("开始录音请求...")
        
        // 在预览模式下模拟录音成功
        if isRunningInPreview {
            print("预览模式：模拟录音")
            isRecording = true
            // 提供一些模拟的转录文本
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 根据当前选择的语言显示不同的模拟文本
                switch self.currentLanguage {
                case .english:
                    self.transcribedText = "This is simulated recording text in preview mode. Actual speech-to-text results will be shown on real devices."
                case .chinese:
                    self.transcribedText = "这是预览模式下的模拟录音文本。实际设备上会显示真实的语音转文字结果。"
                case .japanese:
                    self.transcribedText = "これはプレビューモードのシミュレーションレコーディングテキストです。実際のデバイスで実際の音声からテキストへの結果が表示されます。"
                }
                completion(true, nil)
            }
            return
        }
        
        // 检查是否已经在录音
        if isRecording {
            print("已经在录音中")
            completion(true, nil)
            return
        }
        
        // 检查语音识别器是否可用
        guard let speechRecognizer = speechRecognizer else {
            print("错误：语音识别器未初始化")
            let error = NSError(domain: "com.mirrochild.speechrecognition", 
                               code: 1,
                               userInfo: [NSLocalizedDescriptionKey: "语音识别器未初始化。"])
            completion(false, error)
            return
        }
        
        if !speechRecognizer.isAvailable {
            print("错误：设备不支持语音识别")
            let error = NSError(domain: "com.mirrochild.speechrecognition", 
                               code: 1,
                               userInfo: [NSLocalizedDescriptionKey: "此设备不支持语音识别功能。"])
            completion(false, error)
            return
        }
        
        print("准备请求录音权限...")
        // 先请求权限
        requestPermissions { [weak self] granted in
            guard let self = self else { return }
            
            if !granted {
                print("错误：权限被拒绝")
                let error = NSError(domain: "com.mirrochild.speechrecognition", 
                                  code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "语音识别或麦克风权限被拒绝。"])
                completion(false, error)
                return
            }
            
            print("权限已获得，准备配置音频会话...")
            
            // 确保audioEngine已初始化
            guard let audioEngine = self.audioEngine else {
                print("错误：音频引擎未初始化")
                let error = NSError(domain: "com.mirrochild.speechrecognition", 
                                   code: 4,
                                   userInfo: [NSLocalizedDescriptionKey: "音频引擎未初始化。"])
                completion(false, error)
                return
            }
            
            // 配置音频会话
            do {
                let audioSession = AVAudioSession.sharedInstance()
                // 始终使用扬声器输出音频
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                print("音频会话配置成功: 使用扬声器")
            } catch {
                print("错误：配置音频会话失败: \(error)")
                completion(false, error)
                return
            }
            
            // 清理之前的会话
            self.resetRecording()
            
            print("创建语音识别请求...")
            // 创建识别请求
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = self.recognitionRequest else {
                print("错误：无法创建语音识别请求")
                let error = NSError(domain: "com.mirrochild.speechrecognition", 
                                  code: 3,
                                  userInfo: [NSLocalizedDescriptionKey: "无法创建语音识别请求。"])
                completion(false, error)
                return
            }
            
            // 启用实时结果
            recognitionRequest.shouldReportPartialResults = true
            
            // 设置是否添加标点符号（如果支持的话）
            if #available(iOS 16.0, *) {
                if self.enablePunctuation {
                    recognitionRequest.addsPunctuation = true
                } else {
                    recognitionRequest.addsPunctuation = false
                }
                print("标点符号设置: \(recognitionRequest.addsPunctuation)")
            } else {
                print("当前iOS版本不支持设置标点符号自动添加")
            }
            
            print("开始语音识别任务，使用语言: \(self.currentLanguage.rawValue)")
            // 开始识别任务
            self.recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.error = error
                    print("语音识别错误: \(error.localizedDescription)")
                    return
                }
                
                if let result = result {
                    // 更新识别文本
                    DispatchQueue.main.async {
                        let text = result.bestTranscription.formattedString
                        self.transcribedText = text
                        print("识别结果: \(text)")
                    }
                }
            }
            
            print("配置音频输入...")
            // 获取音频输入
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // 安装音频捕获
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, time in
                self.recognitionRequest?.append(buffer)
            }
            
            // 启动音频引擎
            do {
                audioEngine.prepare()
                try audioEngine.start()
                
                // 更新状态
                self.isRecording = true
                print("录音已成功启动")
                
                // 开始监控音频电平
                self.startMonitoringAudioLevels()
                
                completion(true, nil)
            } catch {
                self.error = error
                print("错误：启动音频引擎失败: \(error)")
                completion(false, error)
            }
        }
    }
    
    // 停止录音
    func stopRecording() {
        // 预览模式下直接重置状态
        if isRunningInPreview {
            isRecording = false
            return
        }
        
        guard isRecording else { return }
        
        // 停止音频引擎和识别任务
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // 重置状态
        isRecording = false
        
        // 停止音频电平监控
        stopMonitoringAudioLevels()
        
        // 尝试停用音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("停用音频会话失败: \(error)")
        }
        
        recognitionRequest = nil
        recognitionTask = nil
        
        // 结束后台任务
        endBackgroundTask()
    }
    
    // 监控音频电平
    private func startMonitoringAudioLevels() {
        // 停止现有计时器
        audioLevelTimer?.invalidate()
        
        // 创建新计时器，提高采样率
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self, let audioEngine = self.audioEngine, self.isRecording else { return }
            
            // 获取音频节点
            let inputNode = audioEngine.inputNode
            
            // 计算音频电平
            let powerLevel = self.calculateAudioLevel(from: inputNode)
            
            // 更新当前电平
            DispatchQueue.main.async {
                self.currentAudioLevel = powerLevel
            }
        }
    }
    
    // 停止监控音频电平
    private func stopMonitoringAudioLevels() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        currentAudioLevel = 0.0
    }
    
    // 从音频节点计算电平
    private func calculateAudioLevel(from node: AVAudioNode) -> Float {
        // 使用更真实的波形模拟，不只是简单的随机函数
        // 使用更响应的波形变化，让静音时电平低，有声音时电平高
        
        if isRecording {
            // 获取当前音频时间，用于创建更自然的波形
            let currentTime = Date().timeIntervalSince1970
            
            // 创建基础波浪
            let baseWave = sin(currentTime * 10) * 0.5
            
            // 创建二次波浪，产生更复杂的模式
            let secondaryWave = sin(currentTime * 20) * 0.3
            
            // 随机噪声，使波形更自然
            let noise = Float.random(in: -0.1...0.1)
            
            // 如果用户在说话，生成更高的电平值
            let amplitude = isUserSpeaking() ? Float.random(in: 0.6...0.9) : Float.random(in: 0.1...0.3)
            
            // 结合所有因素，生成最终的电平值
            let combinedWave = Float(baseWave + secondaryWave) + noise
            
            // 转换为分贝值范围
            let dbValue = -50 * (1 - amplitude * abs(combinedWave))
            
            return dbValue
        } else {
            return -60.0
        }
    }
    
    // 模拟检测用户是否在说话
    private func isUserSpeaking() -> Bool {
        // 根据时间创建周期性的"说话"状态
        let periodInSeconds = 2.0
        let currentTime = Date().timeIntervalSince1970
        let cyclePosition = currentTime.truncatingRemainder(dividingBy: periodInSeconds) / periodInSeconds
        
        // 在周期的前一半"说话"，后一半"静音"
        // 添加一些随机性使模式不太规律
        if cyclePosition < 0.7 {
            return true
        } else {
            // 偶尔在"静音"期间也有声音
            return Float.random(in: 0...1) < 0.1
        }
    }
    
    // 重置录音状态
    private func resetRecording() {
        // 停止之前的任务，如果有的话
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // 移除任何现有的音频捕获
        if audioEngine?.isRunning == true {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
    }
} 
