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
    case chinese = "zh-CN"
    case english = "en-US"
    
    var id: String { self.rawValue }
    
    // 语言的本地化显示名称
    var localizedName: String {
        switch self {
        case .english:
            return "英语"
        case .chinese:
            return "中文"
        }
    }
    
    // 默认使用中文，其次是英文
    static var deviceDefault: VoiceLanguage {
        // 直接返回中文作为默认选项
        return .chinese
    }
}

// 声音克隆API响应状态
enum VoiceCloneStatus {
    case notStarted
    case uploading
    case success(voiceId: String)
    case failed(error: Error)
    
    var isUploading: Bool {
        if case .uploading = self {
            return true
        }
        return false
    }
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var voiceId: String? {
        if case .success(let id) = self {
            return id
        }
        return nil
    }
}

// 录音文件模型
struct SavedRecording: Identifiable, Codable {
    var id: String
    var fileName: String
    var fileURL: URL
    var creationDate: Date
    var duration: TimeInterval
    var description: String
    
    // 自定义编码和解码以处理URL类型
    enum CodingKeys: String, CodingKey {
        case id, fileName, fileURLString, creationDate, duration, description
    }
    
    init(id: String = UUID().uuidString, fileName: String, fileURL: URL, duration: TimeInterval, description: String) {
        self.id = id
        self.fileName = fileName
        self.fileURL = fileURL
        self.creationDate = Date()
        self.duration = duration
        self.description = description
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        fileName = try container.decode(String.self, forKey: .fileName)
        let urlString = try container.decode(String.self, forKey: .fileURLString)
        fileURL = URL(fileURLWithPath: urlString)
        creationDate = try container.decode(Date.self, forKey: .creationDate)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        description = try container.decode(String.self, forKey: .description)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(fileURL.path, forKey: .fileURLString)
        try container.encode(creationDate, forKey: .creationDate)
        try container.encode(duration, forKey: .duration)
        try container.encode(description, forKey: .description)
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
    
    // 语音配置相关属性
    @Published var voiceSamples: [Data] = []
    @Published var hasCompletedVoiceSetup: Bool = UserDefaults.standard.bool(forKey: "hasCompletedVoiceSetup")
    
    // 声音文件和克隆相关属性
    @Published var voiceFileURL: URL?
    @Published var cloneStatus: VoiceCloneStatus = .notStarted
    @Published var currentRecordingDuration: TimeInterval = 0
    private var recordingStartTime: Date?
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    
    // 保存的录音列表
    @Published var savedRecordings: [SavedRecording] = []
    
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var error: Error?
    @Published var permissionStatus: PermissionStatus = .notDetermined
    private var enablePunctuation = true // 控制是否启用标点符号功能
    
    // Public accessor methods for enablePunctuation
    var isPunctuationEnabled: Bool {
        get { enablePunctuation }
        set { enablePunctuation = newValue }
    }
    
    // 语言相关属性
    @Published var currentLanguage: VoiceLanguage = .chinese {
        didSet {
            // 当语言改变时，更新语音识别器
            updateSpeechRecognizer()
            // 保存用户选择
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedVoiceLanguage")
        }
    }
    
    // 语音类型相关
    @Published var selectedVoiceType: String = UserDefaults.standard.string(forKey: "selectedVoiceType") ?? "shimmer" {
        didSet {
            // 保存用户选择的语音类型
            UserDefaults.standard.set(selectedVoiceType, forKey: "selectedVoiceType")
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
            
            // 加载保存的录音列表
            loadSavedRecordings()
            
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
        
        // 设置应用状态监听
        setupNotifications()
        
        // 加载保存的录音列表
        loadSavedRecordings()
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
    
    // 检查麦克风权限
    func checkPermissionStatus() {
        if isRunningInPreview {
            permissionStatus = .authorized
            return
        }
        
        #if os(iOS) && compiler(>=5.9)
        if #available(iOS 17.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            
            switch status {
            case .granted:
                permissionStatus = .authorized
                print("麦克风权限已授权")
            case .denied:
                permissionStatus = .denied
                print("麦克风权限被拒绝")
            case .undetermined:
                permissionStatus = .notDetermined
                print("麦克风权限未确定")
            @unknown default:
                permissionStatus = .notDetermined
                print("麦克风权限状态未知")
            }
        } else {
            let status = AVAudioSession.sharedInstance().recordPermission
            
            switch status {
            case .granted:
                permissionStatus = .authorized
                print("麦克风权限已授权")
            case .denied:
                permissionStatus = .denied
                print("麦克风权限被拒绝")
            case .undetermined:
                permissionStatus = .notDetermined
                print("麦克风权限未确定")
            @unknown default:
                permissionStatus = .notDetermined
                print("麦克风权限状态未知")
            }
        }
        #else
        let status = AVAudioSession.sharedInstance().recordPermission
        
        switch status {
        case .granted:
            permissionStatus = .authorized
            print("麦克风权限已授权")
        case .denied:
            permissionStatus = .denied
            print("麦克风权限被拒绝")
        case .undetermined:
            permissionStatus = .notDetermined
            print("麦克风权限未确定")
        @unknown default:
            permissionStatus = .notDetermined
            print("麦克风权限状态未知")
        }
        #endif
    }
    
    // 请求权限
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        if isRunningInPreview {
            completion(true)
            return
        }
        
        #if os(iOS) && compiler(>=5.9)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionStatus = granted ? .authorized : .denied
                    print("麦克风权限请求结果: \(granted ? "已授权" : "已拒绝")")
                    completion(granted)
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionStatus = granted ? .authorized : .denied
                    print("麦克风权限请求结果: \(granted ? "已授权" : "已拒绝")")
                    completion(granted)
                }
            }
        }
        #else
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.permissionStatus = granted ? .authorized : .denied
                print("麦克风权限请求结果: \(granted ? "已授权" : "已拒绝")")
                completion(granted)
            }
        }
        #endif
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
                    self.transcribedText = "这是预览模式下的英语模拟录音文本。实际设备上会显示真实的语音转文字结果。"
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
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                print("音频会话配置成功，已启用后台模式")
                
                // 开始后台任务以支持后台录音
                self.beginBackgroundTask()
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
        
        // 结束后台任务
        endBackgroundTask()
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
    
    // MARK: - 语音录制增强功能
    
    // 开始录制声音文件
    func startVoiceFileRecording() {
        // 如果在预览模式下，仅模拟
        if isRunningInPreview {
            isRecording = true
            recordingStartTime = Date()
            startTimerForRecording()
            return
        }
        
        // 请求必要的权限
        requestPermissions { [weak self] granted in
            guard let self = self, granted else {
                print("语音录制权限被拒绝")
                return
            }
            
            do {
                // 配置音频会话
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                // 创建唯一的文件名
                let fileName = "voice_recording_\(Date().timeIntervalSince1970).m4a"
                
                // 获取Documents目录路径
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsDirectory.appendingPathComponent(fileName)
                self.voiceFileURL = fileURL
                
                print("将录制保存到: \(fileURL.path)")
                
                // 设置录音参数 - 高质量设置
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
                
                // 创建并配置录音器
                self.audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
                self.audioRecorder?.delegate = self
                self.audioRecorder?.isMeteringEnabled = true
                
                // 开始录制
                let recordingSuccess = self.audioRecorder?.record() ?? false
                if recordingSuccess {
                    self.isRecording = true
                    self.recordingStartTime = Date()
                    self.startTimerForRecording()
                    print("开始录制声音文件")
                } else {
                    print("开始录制失败")
                }
                
            } catch {
                print("设置录音出错: \(error.localizedDescription)")
                self.error = error
            }
        }
    }
    
    // 启动计时器跟踪录制时长
    private func startTimerForRecording() {
        recordingTimer?.invalidate()
        currentRecordingDuration = 0
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.currentRecordingDuration = Date().timeIntervalSince(startTime)
        }
    }
    
    // 停止录制声音文件
    func stopVoiceFileRecording() -> URL? {
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard !isRunningInPreview else {
            isRecording = false
            return nil
        }
        
        // 停止录音
        audioRecorder?.stop()
        isRecording = false
        
        // 如果没有文件URL，说明录制可能失败了
        guard let fileURL = voiceFileURL else {
            print("录制失败：没有有效的文件URL")
            return nil
        }
        
        // 检查文件是否存在且有效
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("录制的文件不存在：\(fileURL.path)")
            return nil
        }
        
        // 获取文件大小
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? NSNumber {
                print("录制完成，文件大小：\(fileSize.intValue) 字节")
            }
        } catch {
            print("获取文件信息失败：\(error.localizedDescription)")
        }
        
        // 实际应用中，可以在这里处理音频文件，比如转换格式或压缩
        print("语音录制完成，文件保存在：\(fileURL.path)")
        
        return fileURL
    }
    
    // MARK: - 声音克隆API功能
    
    // 上传声音样本到声音克隆API
    func uploadVoiceToCloneAPI() {
        guard let fileURL = voiceFileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            let error = NSError(domain: "com.mirrochild.voiceclone", code: 1, userInfo: [NSLocalizedDescriptionKey: "没有有效的语音样本文件"])
            self.cloneStatus = .failed(error: error)
            return
        }
        
        // 更新状态为上传中
        self.cloneStatus = .uploading
        
        // 创建请求
        let apiURL = URL(string: "https://api.example.com/voice-clone")!
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        
        // 创建multipart请求
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 你可能需要添加API密钥
        request.setValue("YOUR_API_KEY", forHTTPHeaderField: "Authorization")
        
        // 创建请求体
        var body = Data()
        
        // 添加语音类型参数
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"voice_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(selectedVoiceType)\r\n".data(using: .utf8)!)
        
        // 添加语音文件
        do {
            let audioData = try Data(contentsOf: fileURL)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"voice_file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
        } catch {
            self.cloneStatus = .failed(error: error)
            print("读取语音文件失败：\(error.localizedDescription)")
            return
        }
        
        // 结束请求体
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // 设置请求体
        request.httpBody = body
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.cloneStatus = .failed(error: error)
                    print("上传失败：\(error.localizedDescription)")
                    return
                }
                
                guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "com.mirrochild.voiceclone", code: 2, userInfo: [NSLocalizedDescriptionKey: "无效的服务器响应"])
                    self.cloneStatus = .failed(error: error)
                    return
                }
                
                // 检查HTTP状态码
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    // 尝试解析响应
                    do {
                        // 假设API返回的是包含voice_id的JSON
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let voiceId = json["voice_id"] as? String {
                            // 保存返回的语音ID
                            UserDefaults.standard.set(voiceId, forKey: "clonedVoiceId")
                            self.cloneStatus = .success(voiceId: voiceId)
                            print("声音克隆成功！声音ID：\(voiceId)")
                            
                            // 标记为已完成语音设置
                            self.hasCompletedVoiceSetup = true
                            UserDefaults.standard.set(true, forKey: "hasCompletedVoiceSetup")
                        } else {
                            // 返回格式不正确
                            let error = NSError(domain: "com.mirrochild.voiceclone", code: 3, userInfo: [NSLocalizedDescriptionKey: "无效的API响应格式"])
                            self.cloneStatus = .failed(error: error)
                        }
                    } catch {
                        self.cloneStatus = .failed(error: error)
                        print("解析API响应失败：\(error.localizedDescription)")
                    }
                } else {
                    // 服务器返回错误
                    let error = NSError(domain: "com.mirrochild.voiceclone", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "服务器返回错误：\(httpResponse.statusCode)"])
                    self.cloneStatus = .failed(error: error)
                    print("服务器返回错误：\(httpResponse.statusCode)")
                }
            }
        }
        
        task.resume()
    }
    
    // 获取已克隆的声音ID
    func getClonedVoiceId() -> String? {
        return UserDefaults.standard.string(forKey: "clonedVoiceId")
    }
    
    // 重置声音克隆状态
    func resetVoiceCloneStatus() {
        cloneStatus = .notStarted
        voiceFileURL = nil
    }
    
    // MARK: - 保存的录音管理
    
    // 保存当前录音并添加到列表
    func saveCurrentRecording(description: String = "") {
        guard let fileURL = voiceFileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            print("没有有效的录音文件可保存")
            return
        }
        
        do {
            // 获取文件属性
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[FileAttributeKey.size] as? UInt64 ?? 0
            
            // 检查文件大小，确保文件不为空
            if fileSize == 0 {
                print("录音文件为空，不保存")
                return
            }
            
            // 获取实际录音时长
            var actualDuration: TimeInterval = currentRecordingDuration
            
            // 使用AVAudioPlayer获取确切的录音时长
            do {
                let player = try AVAudioPlayer(contentsOf: fileURL)
                actualDuration = player.duration
                print("从播放器获取到的实际录音时长: \(actualDuration) 秒")
            } catch {
                print("无法获取录音时长，使用计时器时长: \(currentRecordingDuration) 秒")
            }
            
            // 创建保存的录音对象
            let fileName = fileURL.lastPathComponent
            let savedRecording = SavedRecording(
                fileName: fileName,
                fileURL: fileURL,
                duration: actualDuration,
                description: description.isEmpty ? "录音 \(savedRecordings.count + 1)" : description
            )
            
            // 添加到列表
            savedRecordings.append(savedRecording)
            
            // 保存到本地存储
            saveSavedRecordingsToStorage()
            
            print("已保存录音: \(savedRecording.description)，文件大小: \(fileSize) 字节，时长: \(actualDuration) 秒")
            
            // 验证文件是否可播放
            verifyRecordingPlayability(fileURL: fileURL)
            
        } catch {
            print("获取文件属性错误: \(error.localizedDescription)")
        }
    }
    
    // 验证录音是否可播放
    private func verifyRecordingPlayability(fileURL: URL) {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            print("录音验证成功，文件时长: \(audioPlayer.duration) 秒")
        } catch {
            print("录音验证失败，文件可能损坏: \(error.localizedDescription)")
        }
    }
    
    // 获取所有保存的录音
    func getAllSavedRecordings() -> [SavedRecording] {
        return savedRecordings
    }
    
    // 删除指定录音
    func deleteRecording(id: String) {
        guard let index = savedRecordings.firstIndex(where: { $0.id == id }) else {
            return
        }
        
        let recording = savedRecordings[index]
        
        // 删除物理文件
        do {
            try FileManager.default.removeItem(at: recording.fileURL)
            print("已删除文件: \(recording.fileURL.path)")
        } catch {
            print("删除录音文件失败: \(error.localizedDescription)")
        }
        
        // 从列表中移除
        savedRecordings.remove(at: index)
        
        // 更新存储
        saveSavedRecordingsToStorage()
    }
    
    // 将录音列表保存到存储
    private func saveSavedRecordingsToStorage() {
        do {
            // 只保存文件路径和元数据，不保存文件内容
            let data = try JSONEncoder().encode(savedRecordings)
            UserDefaults.standard.set(data, forKey: "savedRecordings")
        } catch {
            print("保存录音列表失败: \(error.localizedDescription)")
        }
    }
    
    // 从存储加载录音列表
    private func loadSavedRecordings() {
        guard let data = UserDefaults.standard.data(forKey: "savedRecordings") else {
            return
        }
        
        do {
            let decodedRecordings = try JSONDecoder().decode([SavedRecording].self, from: data)
            
            // 验证文件是否存在
            let validRecordings = decodedRecordings.filter { recording in
                FileManager.default.fileExists(atPath: recording.fileURL.path)
            }
            
            savedRecordings = validRecordings
            print("已加载 \(validRecordings.count) 个保存的录音")
        } catch {
            print("加载录音列表失败: \(error.localizedDescription)")
        }
    }
    
    // 播放指定录音
    func playRecording(_ recording: SavedRecording, completion: @escaping (Bool) -> Void) {
        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            completion(true)
        } catch {
            print("播放录音失败: \(error.localizedDescription)")
            completion(false)
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceCaptureManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("录音未成功完成")
            
            // 如果录音失败，清除URL
            if let url = voiceFileURL, FileManager.default.fileExists(atPath: url.path) {
                do {
                    try FileManager.default.removeItem(at: url)
                    print("已删除不完整的录音文件")
                } catch {
                    print("删除不完整的录音文件失败：\(error.localizedDescription)")
                }
            }
            
            voiceFileURL = nil
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("录音编码错误：\(error.localizedDescription)")
            self.error = error
        }
    }
} 
