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
            return
        }
        
        // 只在非预览模式下初始化实际服务
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
        audioEngine = AVAudioEngine()
        
        // 监听应用进入后台（非预览模式）
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                guard let self = self, self.isRecording else { return }
                self.stopRecording()
            }
            .store(in: &cancellables)
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
                self.transcribedText = "这是预览模式下的模拟录音文本。实际设备上会显示真实的语音转文字结果。"
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
            
            // 启用实时结果
            recognitionRequest.shouldReportPartialResults = true
            
            print("开始语音识别任务...")
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
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            print("启动音频引擎...")
            // 启动音频引擎
            do {
                audioEngine.prepare()
                try audioEngine.start()
                self.isRecording = true
                print("录音已开始")
                completion(true, nil)
            } catch {
                self.resetRecording()
                print("启动音频引擎错误: \(error)")
                completion(false, error)
            }
        }
    }
    
    func stopRecording() {
        // 在预览模式下仅重置状态
        if isRunningInPreview {
            isRecording = false
            return
        }
        
        // 停止录音
        if isRecording {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            isRecording = false
        }
        
        // 重置
        resetRecording()
        
        // 关闭音频会话
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    private func resetRecording() {
        // 在预览模式下不进行任何操作
        if isRunningInPreview {
            return
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
} 
