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
    
    var id: String { self.rawValue }
    
    // 语言的本地化显示名称
    var localizedName: String {
        return "中文"
    }
    
    // 默认使用中文
    static var deviceDefault: VoiceLanguage {
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
        
        // 从相对路径构建URL，确保在应用更新后路径依然有效
        let urlString = try container.decode(String.self, forKey: .fileURLString)
        if urlString.hasPrefix("/") {
            // 旧版存储的绝对路径 - 尝试修复
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            fileURL = documentsDirectory.appendingPathComponent(fileName)
        } else {
            // 新版相对路径格式
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            fileURL = documentsDirectory.appendingPathComponent(urlString)
        }
        
        creationDate = try container.decode(Date.self, forKey: .creationDate)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        description = try container.decode(String.self, forKey: .description)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileName, forKey: .fileName)
        
        // 存储相对于Documents目录的路径，而不是完整路径
        // 这样在应用更新后路径依然有效
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if fileURL.path.hasPrefix(documentsDirectory.path) {
            let relativePath = fileURL.lastPathComponent
            try container.encode(relativePath, forKey: .fileURLString)
        } else {
            // 为了兼容性，仍然存储完整路径
            try container.encode(fileURL.lastPathComponent, forKey: .fileURLString)
        }
        
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
    
    // 音频会话互斥锁，防止多个录音过程同时启动
    private let audioSessionLock = NSLock()
    private var isAudioSessionActive = false
    
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
    @Published var currentLanguage: VoiceLanguage = .chinese
    
    // 语音类型相关
    @Published var selectedVoiceType: String = UserDefaults.standard.string(forKey: "selectedVoiceType") ?? "shimmer" {
        didSet {
            // 保存用户选择的语音类型
            UserDefaults.standard.set(selectedVoiceType, forKey: "selectedVoiceType")
        }
    }
    
    // 获取所有可用的语音识别语言
    @Published var availableLanguages: [VoiceLanguage] = [.chinese]
    
    private var cancellables = Set<AnyCancellable>()
    private var micPermissionGranted = false
    
    enum PermissionStatus {
        case notDetermined, denied, authorized
    }
    
    // 添加一个标记来跟踪后台任务的状态
    private var voiceBackgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    @Published var voiceCloneName: String = ""
    
    // 初始化
    private override init() {
        super.init()
        
        // 检查是否在预览环境中
        isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        
        if isRunningInPreview {
            print("VoiceCaptureManager 在预览模式下运行")
            permissionStatus = .authorized
            return
        }
        
        print("初始化 VoiceCaptureManager")
        
        // 创建音频引擎
        audioEngine = AVAudioEngine()
        
        // 固定使用中文
        currentLanguage = .chinese
        
        // 根据设备语言初始化语音识别器
        updateSpeechRecognizer()
        
        // 检查语音识别权限
        checkPermissions()
        
        // 清理任何可能的旧音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("清理旧音频会话失败: \(error.localizedDescription)，但将继续初始化")
        }
        
        // 加载保存的录音
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
        // 如果已经有一个活跃的后台任务，先结束它
        endBackgroundTask()
        
        // 开始一个新的后台任务
        voiceBackgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            // 这是后台任务即将过期的回调
            print("语音录制后台任务即将过期")
            self?.endBackgroundTask()
        }
        
        print("已开始语音录制后台任务，ID: \(voiceBackgroundTaskId)")
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
        guard voiceBackgroundTaskId != .invalid else { return }
        
        print("结束语音录制后台任务，ID: \(voiceBackgroundTaskId)")
        UIApplication.shared.endBackgroundTask(voiceBackgroundTaskId)
        voiceBackgroundTaskId = .invalid
    }
    
    // 更新语音识别器
    private func updateSpeechRecognizer() {
        // 使用中文语言识别器
        let locale = Locale(identifier: "zh-CN")
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.delegate = self
        
        // 检查识别器是否可用
        let isAvailable = speechRecognizer?.isAvailable ?? false
        if !isAvailable {
            print("中文语音识别器不可用")
        } else {
            print("中文语音识别器已准备就绪")
        }
    }
    
    // 检查设备上支持哪些语言
    private func checkAvailableLanguages() {
        // 只支持中文
        self.availableLanguages = [.chinese]
        
        // 确保当前语言设置为中文
        currentLanguage = .chinese
    }
    
    // 切换语言函数保留但内部实现为空，以免其他地方调用出错
    func switchLanguage(to language: VoiceLanguage) {
        // 始终保持中文，不做任何切换
        currentLanguage = .chinese
    }
    
    // 检查权限状态
    private func checkPermissions() {
        // 在预览模式下跳过实际检查
        if isRunningInPreview {
            permissionStatus = .authorized
            return
        }
        
        if #available(iOS 17.0, *) {
            // 使用推荐的 iOS 17 API
            let recordPermission = AVAudioApplication.shared.recordPermission
            
            switch recordPermission {
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
            // iOS 16及以下版本使用旧API
            let recordPermission = AVAudioSession.sharedInstance().recordPermission
            
            switch recordPermission {
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
    }
    
    // 检查旧版iOS的权限
    private func checkLegacyPermissions() {
        #if DEBUG
        // Silence deprecation warnings for iOS 16 and below compatibility
        #endif
        
        if #available(iOS 17.0, *) {
            // Use the new API for iOS 17 and later
            let recordPermission = AVAudioApplication.shared.recordPermission
            
            switch recordPermission {
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
            // Use the deprecated API for iOS 16 and below
            let recordPermission = AVAudioSession.sharedInstance().recordPermission
            
            switch recordPermission {
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
    }
    
    // 公开方法：检查权限状态
    func checkPermissionStatus() {
        // 调用私有方法检查权限
        checkPermissions()
    }
    
    // 包装 AVAudioApplication requestRecordPermission 方法，解决静态成员调用警告
    @available(iOS 17.0, *)
    private func requestPermissionWrapper(completion: @escaping (Bool) -> Void) {
        // 使用静态方法而不是实例方法，并使用正确的方法名
        AVAudioApplication.requestRecordPermission(completionHandler: { (granted: Bool) in
            completion(granted)
        })
    }
    
    // 公共方法：检查权限并通过完成处理程序返回结果
    func checkPermissions(completion: @escaping (PermissionStatus, Error?) -> Void) {
        // 在预览模式中，直接返回授权状态
        if isRunningInPreview {
            DispatchQueue.main.async {
                self.permissionStatus = .authorized
                completion(.authorized, nil)
            }
            return
        }
        
        // 检查麦克风权限
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                self.permissionStatus = .authorized
                checkSpeechRecognitionPermission(completion: completion)
            case .denied:
                self.permissionStatus = .denied
                completion(.denied, nil)
            case .undetermined:
                requestPermissionWrapper { [weak self] granted in
                    guard let self = self else { return }
                    if granted {
                        // 继续检查语音识别权限
                        self.checkSpeechRecognitionPermission(completion: completion)
                    } else {
                        DispatchQueue.main.async {
                            self.permissionStatus = .denied
                            completion(.denied, nil)
                        }
                    }
                }
            @unknown default:
                let error = NSError(domain: "com.mirrochild.permission", 
                                   code: 1, 
                                   userInfo: [NSLocalizedDescriptionKey: "未知的麦克风权限状态"])
                completion(.denied, error)
            }
        } else {
            let audioSession = AVAudioSession.sharedInstance()
            #if DEBUG
            // Silence deprecation warnings for iOS 16 and below compatibility
            #endif
            switch audioSession.recordPermission {
            case .granted:
                self.permissionStatus = .authorized
                checkSpeechRecognitionPermission(completion: completion)
            case .denied:
                self.permissionStatus = .denied
                completion(.denied, nil)
            case .undetermined:
                audioSession.requestRecordPermission { [weak self] granted in
                    guard let self = self else { return }
                    if granted {
                        // 继续检查语音识别权限
                        self.checkSpeechRecognitionPermission(completion: completion)
                    } else {
                        DispatchQueue.main.async {
                            self.permissionStatus = .denied
                            completion(.denied, nil)
                        }
                    }
                }
            @unknown default:
                let error = NSError(domain: "com.mirrochild.permission", 
                                   code: 1, 
                                   userInfo: [NSLocalizedDescriptionKey: "未知的麦克风权限状态"])
                completion(.denied, error)
            }
        }
    }
    
    // 检查语音识别权限
    private func checkSpeechRecognitionPermission(completion: @escaping (PermissionStatus, Error?) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.permissionStatus = .authorized
                    completion(.authorized, nil)
                case .denied, .restricted:
                    self.permissionStatus = .denied
                    completion(.denied, nil)
                case .notDetermined:
                    self.permissionStatus = .notDetermined
                    completion(.notDetermined, nil)
                @unknown default:
                    let error = NSError(domain: "com.mirrochild.permission", 
                                       code: 2, 
                                       userInfo: [NSLocalizedDescriptionKey: "未知的语音识别权限状态"])
                    completion(.denied, error)
                }
            }
        }
    }
    
    // 请求权限
    func requestPermissions(completion: @escaping (Bool) -> Void) {
        if isRunningInPreview {
            completion(true)
            return
        }
        
        if #available(iOS 17.0, *) {
            requestPermissionWrapper { granted in
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
                self.transcribedText = "这是预览模式下的中文模拟录音文本。实际设备上会显示真实的语音转文字结果。"
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
        
        // 使用互斥锁保护音频会话配置
        audioSessionLock.lock()
        
        // 检查音频会话是否已经被其他实例激活
        if isAudioSessionActive {
            print("警告：音频会话已被激活，尝试重置...")
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                // 短暂等待让系统完全释放资源
                Thread.sleep(forTimeInterval: 0.1)
                isAudioSessionActive = false
            } catch {
                print("重置活跃音频会话失败: \(error)")
                // 即使重置失败也继续尝试
            }
        }
        
        // 检查语音识别器是否可用
        guard let speechRecognizer = speechRecognizer else {
            audioSessionLock.unlock()
            print("错误：语音识别器未初始化")
            let error = NSError(domain: "com.mirrochild.speechrecognition", 
                               code: 1,
                               userInfo: [NSLocalizedDescriptionKey: "语音识别器未初始化。"])
            completion(false, error)
            return
        }
        
        if !speechRecognizer.isAvailable {
            audioSessionLock.unlock()
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
            guard let self = self else { 
                completion(false, NSError(domain: "com.mirrochild.speechrecognition", code: 999, userInfo: [NSLocalizedDescriptionKey: "内部错误: self被释放"]))
                return 
            }
            
            if !granted {
                self.audioSessionLock.unlock()
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
                self.audioSessionLock.unlock()
                print("错误：音频引擎未初始化")
                let error = NSError(domain: "com.mirrochild.speechrecognition", 
                                   code: 4,
                                   userInfo: [NSLocalizedDescriptionKey: "音频引擎未初始化。"])
                completion(false, error)
                return
            }
            
            // 配置音频会话
            do {
                // 先尝试停止任何可能正在进行的音频活动
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                
                // 等待一小段时间让系统释放音频资源
                Thread.sleep(forTimeInterval: 0.1)
                
                let audioSession = AVAudioSession.sharedInstance()
                
                // 先设置为最简单的类别，避免冲突
                try audioSession.setCategory(.record, mode: .default)
                
                // 尝试激活会话
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                self.isAudioSessionActive = true
                
                // 如果成功激活，再设置具体的选项
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                
                print("音频会话配置成功")
                
                // 开始后台任务以支持后台录音
                self.beginBackgroundTask()
            } catch let error as NSError {
                self.audioSessionLock.unlock()
                print("错误：配置音频会话失败: \(error), 代码: \(error.code)")
                
                // 尝试使用更简单的配置作为备选方案
                do {
                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.record)
                    try audioSession.setActive(true)
                    self.isAudioSessionActive = true
                    print("使用备选音频会话配置")
                } catch let fallbackError {
                    print("备选音频会话配置也失败: \(fallbackError.localizedDescription)")
                    completion(false, error)
                    return
                }
            }
            
            // 清理之前的会话
            self.resetRecording()
            
            print("创建语音识别请求...")
            // 创建识别请求
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            guard let recognitionRequest = self.recognitionRequest else {
                self.audioSessionLock.unlock()
                print("错误：无法创建语音识别请求")
                let error = NSError(domain: "com.mirrochild.speechrecognition", 
                                  code: 3,
                                  userInfo: [NSLocalizedDescriptionKey: "无法创建语音识别请求。"])
                completion(false, error)
                return
            }
            
            // 安装音频输入节点
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // 配置请求选项
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = false // 使用在线识别提升精度
            recognitionRequest.taskHint = .dictation // 以听写模式优化,更适合正常对话识别
            
            if self.enablePunctuation {
                if #available(iOS 16.0, *) {
                    recognitionRequest.addsPunctuation = true
                }
            }
            
            // 创建识别任务
            self.recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else {
                    return
                }
                
                var isFinal = false
                
                if let result = result {
                    // 根据识别结果更新转录文本
                    print("识别结果: \(result.bestTranscription.formattedString)")
                    let text = result.bestTranscription.formattedString
                    
                    // 确保在主线程更新UI
                    DispatchQueue.main.async {
                        self.transcribedText = text
                    }
                    
                    isFinal = result.isFinal
                    
                    // 如果这是最终结果，记录任务完成
                    if isFinal {
                        print("语音识别完成，最终结果：\(text)")
                    }
                }
                
                // 如果是最终结果或有错误，则停止识别任务
                if isFinal || error != nil {
                    // 停止语音识别,但保持录音状态
                    if error != nil {
                        print("语音识别出错: \(error!.localizedDescription)")
                        self.error = error
                    } else {
                        print("语音识别完成")
                    }
                    
                    // 仅终止识别任务，但保持audioEngine运行
                    self.recognitionTask = nil
                    self.recognitionRequest = nil
                    
                    // 创建新的识别请求以继续录音
                    self.restartSpeechRecognition()
                }
            }
            
            // 配置音频输入
            // 将音频输入连接到请求
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, when in
                self?.recognitionRequest?.append(buffer)
            }
            
            // 启动音频引擎
            print("启动音频引擎")
            audioEngine.prepare()
            
            do {
                try audioEngine.start()
                self.isRecording = true
                self.error = nil
                
                // 发送已开始录音的通知
                NotificationCenter.default.post(name: .didStartRecording, object: nil)
                
                print("音频引擎启动成功，录音开始")
                self.audioSessionLock.unlock()
                completion(true, nil)
            } catch {
                print("启动音频引擎失败: \(error.localizedDescription)")
                self.isRecording = false
                self.audioSessionLock.unlock()
                
                // 释放音频资源
                self.resetRecording()
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    self.isAudioSessionActive = false
                } catch {
                    print("重置音频会话失败: \(error.localizedDescription)")
                }
                
                completion(false, error)
            }
        }
    }
    
    // 停止录音
    func stopRecording() {
        print("停止录音...")
        
        // 在预览模式下简单切换状态，无需处理实际资源
        if isRunningInPreview {
            self.isRecording = false
            // 发送已停止录音的通知
            NotificationCenter.default.post(name: .didStopRecording, object: nil)
            return
        }
        
        // 确保结束后台任务
        endBackgroundTask()
        
        // 使用互斥锁保护音频会话释放过程
        audioSessionLock.lock()
        defer { audioSessionLock.unlock() }
        
        // 重置录音状态
        self.isRecording = false
        
        // 停止录音相关任务和引擎
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        // 停止音频引擎和移除输入节点上的tap
        if let audioEngine = audioEngine, audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
            print("音频引擎已停止")
        }
        
        // 重置音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = false
            print("音频会话已停用")
        } catch {
            print("停用音频会话时出错: \(error.localizedDescription)")
        }
        
        // 清除转录文本
        DispatchQueue.main.async {
            self.transcribedText = ""
        }
        
        // 清除错误
        self.error = nil
        
        // 发送已停止录音的通知
        NotificationCenter.default.post(name: .didStopRecording, object: nil)
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
        
        // 如果正在进行语音识别，先停止它
        if isRecording {
            stopRecording()
            // 短暂延迟让音频会话完全释放
            Thread.sleep(forTimeInterval: 0.2)
        }
        
        // 停止之前的任何录音
        if audioRecorder?.isRecording == true {
            audioRecorder?.stop()
        }
        
        // 请求必要的权限
        requestPermissions { [weak self] granted in
            guard let self = self, granted else {
                print("语音录制权限被拒绝")
                return
            }
            
            do {
                // 确保文件目录存在
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                
                // 打印当前路径，确认权限
                print("文档目录路径: \(documentsDirectory.path)")
                
                // 创建唯一的文件名
                let fileName = "voice_recording_\(Date().timeIntervalSince1970).m4a"
                let fileURL = documentsDirectory.appendingPathComponent(fileName)
                
                // 尝试创建一个测试文件，确认有写入权限
                let testString = "Test"
                let testURL = documentsDirectory.appendingPathComponent("test.txt")
                try testString.write(to: testURL, atomically: true, encoding: .utf8)
                try FileManager.default.removeItem(at: testURL)
                print("写入权限测试成功")
                
                // 配置音频会话
                let audioSession = AVAudioSession.sharedInstance()
                
                // 重置音频会话
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                
                // 设置录音类别并激活
                try audioSession.setCategory(.record, mode: .default)
                try audioSession.setActive(true)
                
                print("音频会话设置完成")
                
                // 设置录音参数 - 使用更通用的设置
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100.0,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue
                ]
                
                // 保存文件URL
                self.voiceFileURL = fileURL
                print("将录音保存到: \(fileURL.path)")
                
                // 创建并配置录音器
                self.audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
                guard let recorder = self.audioRecorder else {
                    throw NSError(domain: "com.mirrochild.recording", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建录音机"])
                }
                
                recorder.delegate = self
                recorder.isMeteringEnabled = true
                
                // 确保录音器准备好
                if !recorder.prepareToRecord() {
                    throw NSError(domain: "com.mirrochild.recording", code: 2, userInfo: [NSLocalizedDescriptionKey: "录音准备失败"])
                }
                
                print("录音器已准备完毕")
                
                // 开始录制，并设置最长录音时间（例如60秒）
                if !recorder.record(forDuration: 60) {
                    throw NSError(domain: "com.mirrochild.recording", code: 3, userInfo: [NSLocalizedDescriptionKey: "开始录音失败"])
                }
                
                // 更新状态
                self.isRecording = true
                self.recordingStartTime = Date()
                self.startTimerForRecording()
                
                print("录音已成功启动: \(self.isRecording ? "正在录音" : "录音失败")")
                print("录音器状态: \(recorder.isRecording ? "正在录音" : "未录音")")
                
            } catch {
                print("录音设置失败: \(error.localizedDescription)")
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
    
    // 停止录音并返回录音文件URL
    func stopVoiceFileRecording() -> URL? {
        guard isRecording else {
            print("stopVoiceFileRecording: 没有正在进行的录音")
            return nil
        }
        
        print("停止文件录音")
        audioRecorder?.stop()
        audioRecorder = nil
        
        guard let fileURL = voiceFileURL else {
            print("停止录音失败：没有有效的文件URL")
            return nil
        }
        
        // 验证文件是否存在以及大小是否合理
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path),
              let fileAttributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let fileSize = fileAttributes[.size] as? Int,
              fileSize > 1000 else { // 确保文件至少有1KB
            print("录音文件无效或太小: \(fileURL.path)")
            isRecording = false
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        // 停止录音后，重置录音状态但保留文件URL
        isRecording = false
        
        // 重置音频会话，为播放做准备
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("重置音频会话失败: \(error.localizedDescription)")
        }
        
        // 验证录音文件可以播放
        do {
            // 配置音频会话为播放模式
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 尝试加载音频文件
            let audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            
            // 验证音频长度大于0.5秒
            let duration = audioPlayer.duration
            if duration < 0.5 {
                print("录音时长太短: \(duration)秒")
                resetVoiceCloneStatus()
                return nil
            }
            
            print("成功创建录音文件，时长: \(duration)秒")
            
            // 更新录音时长
            currentRecordingDuration = duration
            
        } catch {
            print("验证录音文件失败: \(error.localizedDescription)")
            resetVoiceCloneStatus()
            return nil
        }
        
        // 返回录音文件的URL
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
        
        // 确保名称不为空
        if voiceCloneName.isEmpty {
            voiceCloneName = "我的声音_\(Date().timeIntervalSince1970)"
        }
        
        // 更新状态为上传中
        self.cloneStatus = .uploading
        
        // 首先将音频文件上传到服务器获取URL
        uploadAudioFile(fileURL) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let audioFileURL):
                // 音频文件上传成功，调用声音克隆API
                self.callCloneVoiceAPI(audioFileURL: audioFileURL, name: self.voiceCloneName)
            case .failure(let error):
                // 上传失败
                DispatchQueue.main.async {
                    self.cloneStatus = .failed(error: error)
                    print("上传音频文件失败：\(error.localizedDescription)")
                }
            }
        }
    }
    
    // 上传音频文件到服务器获取URL
    private func uploadAudioFile(_ fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // 由于我们没有实际的文件上传服务器，这里直接使用本地文件
        // 在实际应用中，这里应该实现将文件上传到公开可访问的服务器并获取URL的逻辑
        // 临时示例 - 模拟成功情况，将本地文件直接传递给API
        do {
            // 读取文件数据
            let audioData = try Data(contentsOf: fileURL)
            
            // 记录文件大小
            print("音频文件大小: \(audioData.count) 字节")
            
            // 假设文件已上传并返回URL
            let temporaryURL = "https://example.com/audio/\(UUID().uuidString).m4a"
            
            // 模拟网络延迟
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                completion(.success(temporaryURL))
            }
        } catch {
            print("读取音频文件失败: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    // 调用声音克隆API
    private func callCloneVoiceAPI(audioFileURL: String, name: String) {
        // 使用API文档中的端点
        guard let apiURL = URL(string: "https://mapi.yunmaovideo.com/api-v1/clone-voice") else {
            let error = NSError(domain: "com.mirrochild.voiceclone", code: 2, userInfo: [NSLocalizedDescriptionKey: "无效的API URL"])
            self.cloneStatus = .failed(error: error)
            return
        }
        
        // 创建请求
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加API密钥
        request.addValue("5VcLUCJDjDass67EnZDBrADB", forHTTPHeaderField: "Authorization")
        
        // 准备请求参数
        let parameters: [String: Any] = [
            "url": audioFileURL,
            "lang": "zh-cn",
            "notify": "https://example.com/api/voice-clone-callback",
            "type": "ins",
            "name": name
        ]
        
        // 序列化请求参数
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            self.cloneStatus = .failed(error: error)
            print("准备请求参数失败：\(error.localizedDescription)")
            return
        }
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.cloneStatus = .failed(error: error)
                    print("API请求失败：\(error.localizedDescription)")
                    return
                }
                
                guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "com.mirrochild.voiceclone", code: 3, userInfo: [NSLocalizedDescriptionKey: "无效的服务器响应"])
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
                            
                            // 保存声音名称
                            UserDefaults.standard.set(self.voiceCloneName, forKey: "clonedVoiceName")
                            
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
        // 注意：不重置currentRecordingDuration，以保持波形图状态
    }
    
    // MARK: - 保存的录音管理
    
    // 保存当前录音并添加到列表
    func saveCurrentRecording(description: String = "") {
        guard let fileURL = voiceFileURL else {
            print("没有有效的录音文件URL可保存")
            return
        }
        
        print("尝试保存录音文件: \(fileURL.path)")
        
        // 检查文件是否存在
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("录音文件不存在: \(fileURL.path)")
            return
        }
        
        do {
            // 获取文件属性
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            let fileSize = attributes[FileAttributeKey.size] as? UInt64 ?? 0
            
            print("录音文件大小: \(fileSize) 字节")
            
            // 检查文件大小，确保文件不为空
            if fileSize == 0 {
                print("录音文件为空，不保存")
                return
            }
            
            // 创建一个永久保存的文件副本
            let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMddHHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let permanentFileName = "recording_\(timestamp).m4a"
            var permanentFileURL = documentsDir.appendingPathComponent(permanentFileName)
            
            print("复制录音文件到: \(permanentFileURL.path)")
            
            // 确保目标文件不存在
            if fileManager.fileExists(atPath: permanentFileURL.path) {
                try fileManager.removeItem(at: permanentFileURL)
            }
            
            // 复制文件
            try fileManager.copyItem(at: fileURL, to: permanentFileURL)
            
            // 确认文件已复制
            guard fileManager.fileExists(atPath: permanentFileURL.path) else {
                print("文件复制失败，目标文件不存在")
                return
            }
            
            // 设置文件属性，确保不被iCloud备份（可选）
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try permanentFileURL.setResourceValues(resourceValues)
            
            // 获取实际录音时长
            var actualDuration: TimeInterval = currentRecordingDuration
            
            // 尝试获取更准确的录音时长
            do {
                let player = try AVAudioPlayer(contentsOf: permanentFileURL)
                actualDuration = player.duration
                print("从播放器获取到的录音时长: \(actualDuration) 秒")
            } catch {
                print("无法获取录音时长，使用计时器时长: \(currentRecordingDuration) 秒")
            }
            
            // 创建保存的录音对象
            let savedRecording = SavedRecording(
                fileName: permanentFileName,
                fileURL: permanentFileURL,
                duration: actualDuration,
                description: description.isEmpty ? "录音_\(timestamp)" : description
            )
            
            // 添加到列表
            print("添加录音到列表: \(savedRecording.description)")
            DispatchQueue.main.async {
                self.savedRecordings.append(savedRecording)
                // 确保按创建时间排序，最新的排在最前面
                self.savedRecordings.sort { $0.creationDate > $1.creationDate }
                self.saveSavedRecordingsToStorage()
            }
            
            print("录音保存成功: \(savedRecording.description)")
            
        } catch {
            print("保存录音文件失败: \(error.localizedDescription)")
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
            print("没有找到保存的录音记录")
            return
        }
        
        do {
            let decodedRecordings = try JSONDecoder().decode([SavedRecording].self, from: data)
            
            var migratedRecordings: [SavedRecording] = []
            var needsSave = false
            
            // 验证文件是否存在并尝试修复路径
            for recording in decodedRecordings {
                if FileManager.default.fileExists(atPath: recording.fileURL.path) {
                    migratedRecordings.append(recording)
                } else {
                    // 尝试在文档目录中查找该文件（以防录音对象使用了错误的路径）
                    let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let alternativeURL = documentsDirectory.appendingPathComponent(recording.fileName)
                    
                    if FileManager.default.fileExists(atPath: alternativeURL.path) {
                        // 创建修复的录音对象
                        var fixedRecording = SavedRecording(
                            id: recording.id,
                            fileName: recording.fileName,
                            fileURL: alternativeURL,
                            duration: recording.duration,
                            description: recording.description
                        )
                        fixedRecording.creationDate = recording.creationDate
                        migratedRecordings.append(fixedRecording)
                        needsSave = true
                        print("已修复录音文件路径: \(recording.fileName)")
                    } else {
                        print("无法找到录音文件，已忽略: \(recording.fileName)")
                    }
                }
            }
            
            // 按创建日期排序，最新的排在前面
            savedRecordings = migratedRecordings.sorted { $0.creationDate > $1.creationDate }
            
            // 如果有录音记录被修复，重新保存更新后的列表
            if needsSave {
                saveSavedRecordingsToStorage()
                print("已更新录音列表存储")
            }
            
            print("已加载 \(migratedRecordings.count) 个保存的录音")
        } catch {
            print("加载录音列表失败: \(error.localizedDescription)")
            // 如果解码失败，尝试清除可能已损坏的数据
            UserDefaults.standard.removeObject(forKey: "savedRecordings")
        }
    }
    
    // 播放指定录音 - 修改此方法来提供更好的音频播放支持
    func playRecording(_ recording: SavedRecording, completion: @escaping (Bool) -> Void) {
        do {
            // 确保正确配置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            let audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            audioPlayer.volume = 1.0 // 确保音量最大
            
            let playSuccess = audioPlayer.play()
            print("播放录音 '\(recording.description)': \(playSuccess ? "成功" : "失败")")
            
            completion(playSuccess)
        } catch {
            print("播放录音失败: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // 提供公共方法重新加载录音列表
    func reloadSavedRecordings() {
        loadSavedRecordings()
    }
    
    // 重启语音识别，保持录音连续性
    private func restartSpeechRecognition() {
        // 如果不再录音，不重启
        guard isRecording, let speechRecognizer = speechRecognizer else {
            return
        }
        
        // 创建新的识别请求
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = self.recognitionRequest else {
            print("创建新的语音识别请求失败")
            return
        }
        
        // 配置请求选项
        recognitionRequest.shouldReportPartialResults = true
        if #available(iOS 16.0, *), self.enablePunctuation {
            recognitionRequest.addsPunctuation = true
        }
        
        // 创建新的识别任务
        self.recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                // 更新转录文本
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcribedText = text
                }
                
                if result.isFinal {
                    print("语音识别片段完成：\(text)")
                    // 当前片段完成后，重新启动一个新的识别请求
                    self.recognitionTask = nil
                    self.recognitionRequest = nil
                    self.restartSpeechRecognition()
                }
            }
            
            if let error = error {
                print("语音识别过程出错：\(error.localizedDescription)")
                // 出错时也尝试重启
                self.recognitionTask = nil
                self.recognitionRequest = nil
                self.restartSpeechRecognition()
            }
        }
        
        // 重新连接音频输入
        if let audioEngine = self.audioEngine, audioEngine.isRunning {
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // 注意：需要先移除旧的tap，再安装新的tap
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, when in
                self?.recognitionRequest?.append(buffer)
            }
        }
    }
    
    // 重置音频会话，确保释放所有资源
    private func resetAudioSession() {
        audioSessionLock.lock()
        defer { audioSessionLock.unlock() }
        
        // 停止录音相关任务和引擎
        if let audioEngine = audioEngine, audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        // 重置音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = false
            print("音频会话已完全重置")
            
            // 短暂等待让系统完全释放资源
            Thread.sleep(forTimeInterval: 0.2)
        } catch {
            print("重置音频会话失败: \(error.localizedDescription)")
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

// MARK: - AVAudioPlayerDelegate

extension VoiceCaptureManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("音频播放结束, 成功: \(flag)")
        
        // 播放结束后重新设置音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("重置音频会话出错: \(error.localizedDescription)")
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("音频播放解码错误: \(error.localizedDescription)")
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension VoiceCaptureManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            print("语音识别器可用")
        } else {
            print("语音识别器不可用")
            
            // 如果正在录音，但识别器变得不可用，通知用户
            if isRecording {
                DispatchQueue.main.async {
                    self.error = NSError(domain: "com.mirrochild.speechrecognition", 
                                        code: 4, 
                                        userInfo: [NSLocalizedDescriptionKey: "语音识别器不可用，请稍后再试。"])
                }
            }
        }
    }
} 


