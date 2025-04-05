import Foundation
import UIKit
import Combine
import AVFoundation

class OpenAIService: NSObject {
    static let shared = OpenAIService()
    
    // 定义错误类型
    enum OpenAIServiceError: Error {
        case apiKeyMissing
        case fileTooLarge
        case invalidResponse
    }
    
    // OpenAI API Key - 实际使用中应该从更安全的地方获取
    private var apiKey: String? {
        // 从UserDefaults获取，如果不存在则使用默认测试key
        // 注意：这仅用于测试/演示目的，生产环境中应通过更安全的方式管理API密钥
        if let savedKey = UserDefaults.standard.string(forKey: "openai_api_key"), !savedKey.isEmpty {
            return savedKey
        } else {
            // 默认测试用API密钥 - 仅用于演示，实际部署时应移除
            // Never try to use ur key, we are not dumb. HAHAAHAHAHAHHAAHAHHAHAHAHAAHAHHAHAAHHA

            return ""
        }
    }
    
    // API基础URL - 使用responses接口，它支持多模态输入
    private let baseURL = "https://api.openai.com/v1/responses"
    
    // 定时器和状态变量
    private var autoSendTimer: Timer?
    private var isAutoSendEnabled = false
    private var lastSentText = ""
    private var lastResponseText = ""
    private var isProcessing = false
    private var lastProcessingStartTime: Date?
    
    // 取消订阅
    private var cancellables = Set<AnyCancellable>()
    
    // 响应回调 - 外部可以设置这个回调来接收实时API响应
    var onNewResponse: ((String) -> Void)?
    
    // 音频播放器
    private var audioPlayer: AVAudioPlayer?
    
    // 状态重置定时器
    private var statusResetTimer: Timer?
    
    // 初始化时设置观察者
    private override init() {
        super.init()
        setupObservers()
        setupStatusResetTimer()
    }
    
    private func setupObservers() {
        // 监听VoiceCaptureManager和ScreenCaptureManager的状态
        NotificationCenter.default.publisher(for: .didStartRecording)
            .sink { [weak self] _ in
                self?.startAutoSend()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .didStopRecording)
            .sink { [weak self] _ in
                self?.stopAutoSend()
            }
            .store(in: &cancellables)
        
        // 监听应用进入后台的通知
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                // 应用进入后台时，确保所有处理正常停止
                self?.stopAutoSend()
            }
            .store(in: &cancellables)
        
        // 监听应用恢复前台的通知
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                // 应用恢复前台时，确保状态是干净的
                self?.reset()
            }
            .store(in: &cancellables)
    }
    
    // 设置状态重置定时器，确保服务状态不会长时间卡住
    private func setupStatusResetTimer() {
        // 取消现有定时器
        statusResetTimer?.invalidate()
        
        // 创建新定时器，每30秒检查一次状态
        statusResetTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.isProcessing {
                // 检查处理开始时间
                if let startTime = self.lastProcessingStartTime, Date().timeIntervalSince(startTime) > 30 {
                    print("⏰ 定时检查发现isProcessing长时间为true，强制重置")
                    self.isProcessing = false
                    self.lastProcessingStartTime = nil
                } else if self.lastProcessingStartTime == nil {
                    print("⏰ 定时检查发现isProcessing为true但无开始时间，重置状态")
                    self.isProcessing = false
                }
            }
        }
        
        // 确保定时器在滚动等情况下仍然触发
        if let timer = statusResetTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // 启动自动发送功能
    func startAutoSend() {
        // 确保在主线程上操作UI和Timer
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.startAutoSend()
            }
            return
        }
        
        guard !isAutoSendEnabled else { return }
        
        isAutoSendEnabled = true
        lastSentText = ""
        
        // 创建一个定时器，每2秒发送一次请求
        autoSendTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.autoSendDataToAPI()
        }
        
        // 确保定时器在滚动等情况下仍然触发
        if let timer = autoSendTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        
        print("已启动自动发送功能，将每2秒发送一次数据到OpenAI")
    }
    
    // 停止自动发送功能
    func stopAutoSend() {
        // 确保在主线程上操作UI和Timer
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.stopAutoSend()
            }
            return
        }
        
        guard isAutoSendEnabled else { return }
        
        autoSendTimer?.invalidate()
        autoSendTimer = nil
        isAutoSendEnabled = false
        lastSentText = ""
        lastResponseText = ""
        
        // 重置所有处理状态，确保不会卡住
        isProcessing = false
        lastProcessingStartTime = nil
        
        print("已停止自动发送功能")
    }
    
    // 自动发送数据到API
    private func autoSendDataToAPI() {
        // 检查是否有一个超时的处理过程（超过15秒，从20秒减少为15秒）
        if isProcessing, let startTime = lastProcessingStartTime, Date().timeIntervalSince(startTime) > 15.0 {
            print("⚠️ 检测到卡住的请求处理状态，已超过15秒，强制重置状态")
            isProcessing = false
        }
        
        // 避免重复处理
        guard !isProcessing else {
            print("❌ 上一次请求仍在处理中，跳过本次发送 (isProcessing = \(isProcessing))")
            
            // 如果lastProcessingStartTime为nil，这可能是一个未正确初始化的状态
            if lastProcessingStartTime == nil {
                print("🔄 检测到潜在的状态不一致，强制重置isProcessing")
                isProcessing = false
                // 尝试再次执行方法，现在isProcessing已被重置
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.autoSendDataToAPI()
                }
                return
            }
            return
        }
        
        // 获取当前的截图和文本
        let screenCaptureManager: ScreenCaptureManager = ScreenCaptureManager.shared
        let voiceCaptureManager: VoiceCaptureManager = VoiceCaptureManager.shared
        
        // 确保至少一种录制在进行中
        if !screenCaptureManager.isRecording && !voiceCaptureManager.isRecording {
            print("录制未在进行中，停止自动发送")
            stopAutoSend()
            return
        }
        
        // 获取当前文本
        let currentText = voiceCaptureManager.transcribedText
        
        // 如果文本为空，也跳过但不停止发送（可能在等待用户开始说话）
        if currentText.isEmpty {
            print("文本为空，等待用户输入...")
            return
        }
        
        // 移除文本变化检查，确保无论文本是否变化都发送请求
        // 记录是否有变化，仅用于日志
        let hasTextChanged = currentText != lastSentText
        if hasTextChanged {
            print("文本已变化，发送新请求")
        } else {
            print("文本未变化，继续发送请求...")
        }
        
        // 更新最后发送的文本
        lastSentText = currentText
        
        // 记录处理开始时间
        lastProcessingStartTime = Date()
        
        // 获取当前帧
        screenCaptureManager.prepareDataForOpenAI { [weak self] frames, error in
            guard let self = self else { return }
            
            // 如果出现错误或没有可用帧，切换到仅文本模式
            if let error = error {
                print("准备数据时出错: \(error.localizedDescription)")
                // 设置处理标志，避免其他请求插入
                self.isProcessing = true
                
                // 使用仅文本模式发送请求
                self.sendTextOnlyToOpenAI(text: currentText) { result in
                    // 处理完成，重置标志
                    self.isProcessing = false
                    
                    switch result {
                    case .success(let responseText):
                        // 如果响应有变化，更新并通知
                        if responseText != self.lastResponseText {
                            self.lastResponseText = responseText
                            DispatchQueue.main.async {
                                self.onNewResponse?(responseText)
                                print("收到仅文本模式新响应: \(responseText.prefix(100))...")
                            }
                        } else {
                            print("仅文本模式API响应未变化")
                        }
                    case .failure(let error):
                        print("仅文本模式API请求失败: \(error.localizedDescription)")
                    }
                }
                return
            }
            
            // 检查frames是否为空
            if frames == nil || frames!.isEmpty {
                print("没有可用的屏幕帧，切换到仅文本模式")
                // 设置处理标志，避免其他请求插入
                self.isProcessing = true
                
                // 使用仅文本模式发送请求
                self.sendTextOnlyToOpenAI(text: currentText) { result in
                    // 处理完成，重置标志
                    self.isProcessing = false
                    
                    switch result {
                    case .success(let responseText):
                        // 如果响应有变化，更新并通知
                        if responseText != self.lastResponseText {
                            self.lastResponseText = responseText
                            DispatchQueue.main.async {
                                self.onNewResponse?(responseText)
                                print("收到仅文本模式新响应: \(responseText.prefix(100))...")
                            }
                        } else {
                            print("仅文本模式API响应未变化")
                        }
                    case .failure(let error):
                        print("仅文本模式API请求失败: \(error.localizedDescription)")
                    }
                }
                return
            }
            
            // 开始处理，设置标志
            self.isProcessing = true
            print("🔒 设置处理标志 isProcessing = true, 时间: \(Date())")
            
            // 执行API请求
            print("正在发送数据到OpenAI API: \(frames?.count ?? 0)个帧, 文本: \(currentText)")
            self.sendScreenCaptureAndVoiceData(frames: frames ?? [], transcribedText: currentText) { result in
                // 处理完成，重置标志
                self.isProcessing = false
                
                switch result {
                case .success(let responseText):
                    // 如果响应有变化，更新并通知
                    if responseText != self.lastResponseText {
                        self.lastResponseText = responseText
                        DispatchQueue.main.async {
                            self.onNewResponse?(responseText)
                            print("收到新响应: \(responseText.prefix(100))...")
                        }
                    } else {
                        print("API响应未变化")
                    }
                case .failure(let error):
                    print("API请求失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 添加一个仅发送文本的方法，当没有可用的截图时使用
    private func sendTextOnlyToOpenAI(text: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("开始执行仅文本模式请求...")
        
        // 验证API密钥
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            let error = NSError(domain: "com.mirrochild.openai", 
                               code: 1, 
                               userInfo: [NSLocalizedDescriptionKey: "OpenAI API密钥未设置"])
            completion(.failure(error))
            return
        }
        
        // 设置处理标志
        isProcessing = true
        
        // 创建请求URL
        guard let url = URL(string: baseURL) else {
            isProcessing = false
            let error = NSError(domain: "com.mirrochild.openai", 
                               code: 3, 
                               userInfo: [NSLocalizedDescriptionKey: "无效的API URL"])
            completion(.failure(error))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建系统指令
        let instructions = """
        你是一个帮助老年人使用手机的助手。用户提出了问题但没有提供屏幕截图。
        请根据用户的语音输入，以简单易懂的方式回答他们的问题。
        可能的问题包括：
        1. 关于手机功能的基本问答
        2. 城市、地点或常识类问题
        3. 如何使用某项功能或应用
        4. 日常生活中的各种咨询
        
        请用简洁、亲切、耐心的语言回答，避免使用技术术语。如果问题涉及手机操作，可以提供通用的步骤指导。
        """
        
        // 准备仅文本输入内容
        let textContent: [[String: Any]] = [
            [
                "type": "input_text",
                "text": "用户问题: \(text)"
            ]
        ]
        
        // 准备请求体 - 使用Responses API格式
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "instructions": instructions,
            "input": [
                [
                    "role": "user",
                    "content": textContent
                ]
            ],
            "max_output_tokens": 1000
        ]
        
        // 序列化请求体
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            isProcessing = false
            let serializationError = NSError(domain: "com.mirrochild.openai", 
                                           code: 8, 
                                           userInfo: [NSLocalizedDescriptionKey: "序列化请求体失败: \(error.localizedDescription)"])
            completion(.failure(serializationError))
            return
        }
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 重置处理标志
            self.isProcessing = false
            print("🔓 重置处理标志 isProcessing = false (文本模式), 时间: \(Date())")
            
            if let error = error {
                let networkError = NSError(domain: "com.mirrochild.openai", 
                                          code: 9, 
                                          userInfo: [NSLocalizedDescriptionKey: "网络请求错误: \(error.localizedDescription)"])
                completion(.failure(networkError))
                return
            }
            
            guard let data = data else {
                let noDataError = NSError(domain: "com.mirrochild.openai", 
                                         code: 4, 
                                         userInfo: [NSLocalizedDescriptionKey: "没有接收到响应数据"])
                completion(.failure(noDataError))
                return
            }
            
            // 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = json["output"] as? [[String: Any]],
                   let message = output.first(where: { ($0["type"] as? String) == "message" }),
                   let content = message["content"] as? [[String: Any]],
                   let textOutput = content.first(where: { ($0["type"] as? String) == "output_text" }),
                   let text = textOutput["text"] as? String {
                    
                    print("OpenAI仅文本模式响应成功! 输出文本:\n\(text)")
                    
                    // 使用TTS朗读响应文本
                    self.textToSpeech(text: text) { ttsResult in
                        switch ttsResult {
                        case .success:
                            print("TTS朗读成功")
                        case .failure(let ttsError):
                            print("TTS朗读失败: \(ttsError.localizedDescription)")
                        }
                    }
                    
                    completion(.success(text))
                } else {
                    // 尝试获取错误信息
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        
                        let apiError = NSError(domain: "com.mirrochild.openai", 
                                             code: 5, 
                                             userInfo: [NSLocalizedDescriptionKey: "API错误: \(message)"])
                        completion(.failure(apiError))
                    } else {
                        // 打印原始响应以便调试
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("无法解析的API响应:\n\(jsonString)")
                        }
                        
                        let parseError = NSError(domain: "com.mirrochild.openai", 
                                               code: 6, 
                                               userInfo: [NSLocalizedDescriptionKey: "无法解析API响应"])
                        completion(.failure(parseError))
                    }
                }
            } catch {
                let parseError = NSError(domain: "com.mirrochild.openai", 
                                       code: 7, 
                                       userInfo: [NSLocalizedDescriptionKey: "解析响应时出错: \(error.localizedDescription)"])
                completion(.failure(parseError))
            }
        }
        
        task.resume()
    }
    
    // 发送屏幕捕获数据和语音文本到OpenAI
    func sendScreenCaptureAndVoiceData(frames: [ScreenCaptureManager.CapturedFrame], 
                                       transcribedText: String, 
                                       completion: @escaping (Result<String, Error>) -> Void) {
        // 验证API密钥
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            let error = NSError(domain: "com.mirrochild.openai", 
                               code: 1, 
                               userInfo: [NSLocalizedDescriptionKey: "OpenAI API密钥未设置"])
            completion(.failure(error))
            return
        }
        
        // 直接处理和发送帧
        prepareFramesForResponsesAPI(frames, transcribedText: transcribedText) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let content):
                // 使用多模态输入创建请求
                self.createResponsesRequest(content: content) { result in
                    // 确保在完成回调中也重置处理标志
                    DispatchQueue.main.async {
                        if self.isProcessing {
                            print("🔓 在请求完成后确保重置 isProcessing = false, 时间: \(Date())")
                            self.isProcessing = false
                        }
                        completion(result)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("🔓 因错误重置 isProcessing = false, 时间: \(Date())")
                    self.isProcessing = false
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 处理帧以准备用于Responses API的输入
    private func prepareFramesForResponsesAPI(_ frames: [ScreenCaptureManager.CapturedFrame], 
                                            transcribedText: String,
                                            completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        // 选择代表性帧（最多5帧，以符合API限制并减少数据量）
        let selectedFrames = selectRepresentativeFrames(frames)
        
        // 将图像转换为多模态内容数组
        var contentItems: [[String: Any]] = []
        
        // 首先添加文本消息
        contentItems.append([
            "type": "input_text",
            "text": "以下是我手机屏幕的截图，请帮我理解如何使用这个应用。"
        ])
        
        // 最多处理5个帧，避免请求过大
        for frame in selectedFrames.prefix(5) {
            if let imageData = frame.image.jpegData(compressionQuality: 0.5) {
                let base64String = imageData.base64EncodedString()
                
                // 添加图像内容
                let imageContent: [String: Any] = [
                    "type": "input_image",
                    "image_url": "data:image/jpeg;base64,\(base64String)",
                    "detail": "high"  // 使用高详细度来获取更好的分析
                ]
                
                contentItems.append(imageContent)
            }
        }
        
        // 如果有语音文本，添加到最后
        if !transcribedText.isEmpty {
            contentItems.append([
                "type": "input_text",
                "text": "我的问题是: \(transcribedText)"
            ])
        }
        
        // 如果没有有效的帧，返回错误
        if contentItems.count <= 1 { // 只有初始文本消息
            let error = NSError(domain: "com.mirrochild.openai", 
                               code: 2, 
                               userInfo: [NSLocalizedDescriptionKey: "没有有效的屏幕捕获数据可处理"])
            completion(.failure(error))
            return
        }
        
        completion(.success(contentItems))
    }
    
    // 选择代表性帧以减少数据量
    private func selectRepresentativeFrames(_ frames: [ScreenCaptureManager.CapturedFrame]) -> [ScreenCaptureManager.CapturedFrame] {
        guard !frames.isEmpty else { return [] }
        
        // 如果帧少于5个，全部返回
        if frames.count <= 5 {
            return frames
        }
        
        // 否则，选择时间间隔均匀的5个帧
        var selectedFrames: [ScreenCaptureManager.CapturedFrame] = []
        let step = frames.count / 5
        
        for i in stride(from: 0, to: frames.count, by: step) {
            if i < frames.count {
                selectedFrames.append(frames[i])
            }
            
            if selectedFrames.count >= 5 {
                break
            }
        }
        
        // 确保包含最新的帧
        if let lastFrame = frames.last, !selectedFrames.contains(where: { $0.timestamp == lastFrame.timestamp }) {
            selectedFrames.append(lastFrame)
        }
        
        return selectedFrames
    }
    
    // 创建并发送Responses API请求
    private func createResponsesRequest(content: [[String: Any]], 
                                      completion: @escaping (Result<String, Error>) -> Void) {
        // 创建请求URL
        guard let url = URL(string: baseURL) else {
            let error = NSError(domain: "com.mirrochild.openai", 
                               code: 3, 
                               userInfo: [NSLocalizedDescriptionKey: "无效的API URL"])
            completion(.failure(error))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey!)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建系统指令
        let instructions = """
        你是一个帮助老年人使用手机的助手。请根据用户提供的屏幕截图和语音输入，提供简单易懂的指导，帮助用户完成他们想要的操作。
        请用简洁明了的语言，避免使用技术术语。给出步骤清晰的指示。
        """
        
        // 准备请求体 - 使用Responses API格式
        let requestBody: [String: Any] = [
            "model": "gpt-4o",  // 使用支持图像的模型
            "instructions": instructions,
            "input": [
                [
                    "role": "user",
                    "content": content
                ]
            ],
            "max_output_tokens": 1000
        ]
        
        // 序列化请求体
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 确保重置处理标志
            DispatchQueue.main.async {
                self.isProcessing = false
                print("🔓 API响应后重置处理标志 isProcessing = false, 时间: \(Date())")
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "com.mirrochild.openai", 
                                   code: 4, 
                                   userInfo: [NSLocalizedDescriptionKey: "没有接收到响应数据"])
                completion(.failure(error))
                return
            }
            
            // 解析响应 - Responses API的响应格式
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let output = json["output"] as? [[String: Any]],
                   let message = output.first(where: { ($0["type"] as? String) == "message" }),
                   let content = message["content"] as? [[String: Any]],
                   let textOutput = content.first(where: { ($0["type"] as? String) == "output_text" }),
                   let text = textOutput["text"] as? String {
                    
                    // 记录完整响应到控制台，以便调试
                    print("OpenAI响应成功! 输出文本:\n\(text)")
                    
                    // 使用TTS朗读响应文本
                    self.textToSpeech(text: text) { ttsResult in
                        switch ttsResult {
                        case .success:
                            print("TTS朗读成功")
                        case .failure(let ttsError):
                            print("TTS朗读失败: \(ttsError.localizedDescription)")
                        }
                    }
                    
                    completion(.success(text))
                } else {
                    // 尝试获取错误信息
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        
                        let apiError = NSError(domain: "com.mirrochild.openai", 
                                             code: 5, 
                                             userInfo: [NSLocalizedDescriptionKey: "API错误: \(message)"])
                        completion(.failure(apiError))
                    } else {
                        // 打印原始响应以便调试
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("无法解析的API响应:\n\(jsonString)")
                        }
                        
                        let parseError = NSError(domain: "com.mirrochild.openai", 
                                               code: 6, 
                                               userInfo: [NSLocalizedDescriptionKey: "无法解析API响应"])
                        completion(.failure(parseError))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    // 设置API密钥
    func setApiKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "openai_api_key")
    }
    
    // 检查是否有API密钥
    func hasApiKey() -> Bool {
        return apiKey != nil && !apiKey!.isEmpty
    }
    
    // 上传语音样本到OpenAI API
    func uploadVoiceFile(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            completion(.failure(OpenAIServiceError.apiKeyMissing))
            return
        }
        
        // TODO: 实现实际的文件上传功能
        // 目前这是一个占位方法，通知调用者功能尚未实现
        let notImplementedError = NSError(domain: "com.mirrochild.openai", 
                                         code: 7, 
                                         userInfo: [NSLocalizedDescriptionKey: "语音文件上传功能尚未实现"])
        completion(.failure(notImplementedError))
    }
    
    // 将文本转换为语音
    func textToSpeech(text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // 验证API密钥
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            let error = NSError(domain: "com.mirrochild.openai", 
                               code: 1, 
                               userInfo: [NSLocalizedDescriptionKey: "OpenAI API密钥未设置"])
            completion(.failure(error))
            return
        }
        
        // 创建请求URL
        guard let url = URL(string: "https://api.openai.com/v1/audio/speech") else {
            let error = NSError(domain: "com.mirrochild.openai", 
                               code: 3, 
                               userInfo: [NSLocalizedDescriptionKey: "无效的TTS API URL"])
            completion(.failure(error))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 设置TTS参数
        let parameters: [String: Any] = [
            "model": "tts-1",
            "voice": "alloy", // 可选: alloy, echo, fable, onyx, nova, shimmer
            "input": text,
            "response_format": "mp3",
            "speed": 1.0 // 语速，范围0.25-4.0
        ]
        
        // 序列化请求体
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            let serializationError = NSError(domain: "com.mirrochild.openai", 
                                           code: 8, 
                                           userInfo: [NSLocalizedDescriptionKey: "序列化TTS请求体失败: \(error.localizedDescription)"])
            completion(.failure(serializationError))
            return
        }
        
        print("开始发送TTS请求...")
        
        // 发送请求并获取音频数据
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                let networkError = NSError(domain: "com.mirrochild.openai", 
                                          code: 9, 
                                          userInfo: [NSLocalizedDescriptionKey: "TTS网络请求错误: \(error.localizedDescription)"])
                DispatchQueue.main.async {
                    completion(.failure(networkError))
                }
                return
            }
            
            guard let data = data else {
                let noDataError = NSError(domain: "com.mirrochild.openai", 
                                         code: 4, 
                                         userInfo: [NSLocalizedDescriptionKey: "没有接收到TTS响应数据"])
                DispatchQueue.main.async {
                    completion(.failure(noDataError))
                }
                return
            }
            
            // 收到音频数据，准备播放
            print("收到TTS响应，音频数据大小: \(data.count)字节")
            
            // 播放音频
            DispatchQueue.main.async {
                self.playAudio(data: data, completion: completion)
            }
        }
        
        task.resume()
    }
    
    // 播放音频数据
    private func playAudio(data: Data, completion: @escaping (Result<Void, Error>) -> Void) {
        // 通知VoiceCaptureManager暂停录音
        NotificationCenter.default.post(name: .willPlayTTS, object: nil)
        
        // 等待一小段时间让录音停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            do {
                // 创建音频播放器
                self.audioPlayer = try AVAudioPlayer(data: data)
                
                // 设置音频会话，允许混音和播放
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                // 设置播放完成回调
                self.audioPlayer?.delegate = self
                self.audioPlayer?.volume = 1.0
                
                // 开始播放
                if self.audioPlayer?.play() == true {
                    print("开始播放TTS音频")
                    completion(.success(()))
                } else {
                    let playError = NSError(domain: "com.mirrochild.openai", 
                                          code: 10, 
                                          userInfo: [NSLocalizedDescriptionKey: "无法播放TTS音频"])
                    completion(.failure(playError))
                }
            } catch {
                let audioError = NSError(domain: "com.mirrochild.openai", 
                                       code: 11, 
                                       userInfo: [NSLocalizedDescriptionKey: "音频播放初始化错误: \(error.localizedDescription)"])
                completion(.failure(audioError))
            }
        }
    }
    
    // 完全重置所有状态
    func reset() {
        // 确保在主线程执行
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.reset()
            }
            return
        }
        
        print("🔄 开始完全重置OpenAIService状态")
        
        // 停止自动发送
        stopAutoSend()
        
        // 清除音频播放器
        if audioPlayer != nil {
            print("🔊 停止并清除音频播放器")
            audioPlayer?.stop()
            audioPlayer = nil
        }
        
        // 重置所有状态变量
        let wasProcessing = isProcessing
        isProcessing = false
        lastProcessingStartTime = nil
        lastSentText = ""
        lastResponseText = ""
        
        if wasProcessing {
            print("⚠️ 重置时发现isProcessing=true，已强制清除")
        }
        
        // 重置定时器
        setupStatusResetTimer()
        
        print("✅ OpenAIService已完全重置")
    }
    
    deinit {
        // 清理定时器
        statusResetTimer?.invalidate()
        statusResetTimer = nil
    }
}

// 添加通知名称扩展
extension Notification.Name {
    static let didStartRecording = Notification.Name("didStartRecording")
    static let didStopRecording = Notification.Name("didStopRecording")
    static let willPlayTTS = Notification.Name("willPlayTTS") // 新增的通知
}

// 添加AVAudioPlayerDelegate扩展
extension OpenAIService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🔊 TTS音频播放结束")
        
        // 清理资源
        self.audioPlayer = nil
        
        // 重置处理标志，确保下一个请求可以继续
        self.isProcessing = false
        print("🔓 音频播放结束，重置isProcessing = false")
        
        // 确保lastProcessingStartTime也被重置
        self.lastProcessingStartTime = nil
        
        // 恢复音频会话（如果需要）
        do {
            // 注意：setActive方法可能会抛出错误，例如当音频会话被其他应用控制
            // 此方法的声明：func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions = []) throws
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            // 通知录音可以恢复（如果需要）
            NotificationCenter.default.post(name: .didFinishPlayingTTS, object: nil)
            
            // 强制延迟再次重置，确保所有状态都被清除
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isProcessing = false
                self?.lastProcessingStartTime = nil
                print("🔓 音频播放后延迟强制重置isProcessing = false")
            }
        } catch let sessionError {
            print("❌ 重置音频会话时出错: \(sessionError.localizedDescription)")
        }
    }
}

// 新增通知名称
extension Notification.Name {
    static let didFinishPlayingTTS = Notification.Name("didFinishPlayingTTS")
} 
