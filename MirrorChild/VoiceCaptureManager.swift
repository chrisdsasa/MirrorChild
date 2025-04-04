import Foundation
import Speech
import AVFoundation
import AVFAudio
import Combine
import SwiftUI

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
    case english = "en-US"
    case japanese = "ja-JP"
    case chinese = "zh-CN"
    
    var id: String { self.rawValue }
    
    // 语言的本地化显示名称
    var localizedName: String {
        switch self {
        case .english:
            return "English".localized
        case .japanese:
            return "Japanese".localized
        case .chinese:
            return "Chinese".localized
        }
    }
    
    // 从设备当前语言获取默认语言
    static var deviceDefault: VoiceLanguage {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        
        switch languageCode {
        case "ja":
            return .japanese
        case "zh":
            return .chinese
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
    
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var error: Error?
    @Published var permissionStatus: PermissionStatus = .notDetermined
    @Published var enablePunctuation = true // 控制是否启用标点符号功能
    
    // 语言相关属性
    @Published var currentLanguage: VoiceLanguage = VoiceLanguage.deviceDefault {
        didSet {
            // 当语言改变时，更新语音识别器
            updateSpeechRecognizer()
            // 保存用户选择
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedVoiceLanguage")
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
            
            // 从用户默认设置中获取已保存的语言选择
            if let savedLanguageCode = UserDefaults.standard.string(forKey: "selectedVoiceLanguage"),
               let savedLanguage = VoiceLanguage(rawValue: savedLanguageCode) {
                self.currentLanguage = savedLanguage
            }
            
            return
        }
        
        // 从用户默认设置中获取已保存的语言选择
        if let savedLanguageCode = UserDefaults.standard.string(forKey: "selectedVoiceLanguage"),
           let savedLanguage = VoiceLanguage(rawValue: savedLanguageCode) {
            self.currentLanguage = savedLanguage
        }
        
        // 初始化音频引擎
        audioEngine = AVAudioEngine()
        
        // 初始化语音识别器和检查可用语言
        updateSpeechRecognizer()
        checkAvailableLanguages()
        
        // 监听应用进入后台（非预览模式）
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                guard let self = self, self.isRecording else { return }
                self.stopRecording()
            }
            .store(in: &cancellables)
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
        
        // 如果当前选择的语言不在支持列表中，切换到第一个可用语言
        if !supported.contains(currentLanguage) {
            currentLanguage = supported.first ?? .english
        }
    }
    
    // 切换语言
    func switchLanguage(to language: VoiceLanguage) {
        guard availableLanguages.contains(language) else {
            print("不支持的语言: \(language.localizedName)")
            return
        }
        
        currentLanguage = language
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
                case .japanese:
                    self.transcribedText = "これはプレビューモードでのシミュレーションされた録音テキストです。実際のデバイスでは、実際の音声からテキストへの結果が表示されます。"
                case .chinese:
                    self.transcribedText = "这是预览模式下的模拟录音文本。实际设备上会显示真实的语音转文字结果。"
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
                try audioSession.setCategory(.record, mode: .measurement)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                print("音频会话配置成功")
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
            
            // 启用实时结果和标点符号
            recognitionRequest.shouldReportPartialResults = true
            if #available(iOS 16.0, *) {
                recognitionRequest.addsPunctuation = self.enablePunctuation
                print("标点符号功能状态: \(self.enablePunctuation ? "已启用" : "已禁用")")
            } else {
                print("当前iOS版本不支持自动标点符号功能")
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
        
        // 尝试停用音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("停用音频会话失败: \(error)")
        }
        
        recognitionRequest = nil
        recognitionTask = nil
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
