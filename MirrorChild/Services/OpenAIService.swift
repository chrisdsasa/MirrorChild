import Foundation
import UIKit
import Combine
import AVFoundation

class OpenAIService {
    static let shared = OpenAIService()
    
    // 定义错误类型
    enum OpenAIServiceError: Error {
        case apiKeyMissing
        case fileTooLarge
        case invalidResponse
        case audioFormatNotSupported
        case transcriptionFailed
    }
    
    // OpenAI API Key - 实际使用中应该从更安全的地方获取
    private var apiKey: String? {
        return UserDefaults.standard.string(forKey: "openai_api_key")
    }
    
    // API基础URL
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let transcriptionURL = "https://api.openai.com/v1/audio/transcriptions"
    
    // MARK: - 新增: 语音转文字 (Whisper API)
    
    /// 使用OpenAI Whisper API进行语音转文字
    /// - Parameters:
    ///   - audioFileURL: 音频文件URL
    ///   - prompt: 可选的提示词，帮助模型理解上下文
    ///   - language: 可选的语言代码，如"zh"表示中文
    ///   - model: 使用的模型，默认为"gpt-4o-transcribe"
    ///   - completion: 完成回调，返回转录文本或错误
    func transcribeAudio(
        from audioFileURL: URL,
        prompt: String? = nil,
        language: String? = nil,
        model: String = "gpt-4o-transcribe",
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // 验证API密钥
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            let error = NSError(
                domain: "com.mirrochild.openai", 
                code: 1, 
                userInfo: [NSLocalizedDescriptionKey: "OpenAI API密钥未设置"]
            )
            completion(.failure(error))
            return
        }
        
        // 检查文件是否支持的格式
        let supportedFormats = ["mp3", "mp4", "mpeg", "mpga", "m4a", "wav", "webm"]
        let fileExtension = audioFileURL.pathExtension.lowercased()
        
        guard supportedFormats.contains(fileExtension) else {
            completion(.failure(OpenAIServiceError.audioFormatNotSupported))
            return
        }
        
        // 读取音频文件数据
        do {
            let audioData = try Data(contentsOf: audioFileURL)
            
            // 检查文件大小（OpenAI限制为25MB）
            let fileSizeBytes = audioData.count
            let fileSizeMB = Double(fileSizeBytes) / 1_048_576
            
            guard fileSizeMB < 25 else {
                completion(.failure(OpenAIServiceError.fileTooLarge))
                return
            }
            
            // 创建multipart请求
            let boundary = UUID().uuidString
            var request = URLRequest(url: URL(string: transcriptionURL)!)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var httpBody = Data()
            
            // 添加模型参数
            httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            httpBody.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            httpBody.append("\(model)\r\n".data(using: .utf8)!)
            
            // 如果有提示词，添加prompt参数
            if let prompt = prompt, !prompt.isEmpty {
                httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
                httpBody.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
                httpBody.append("\(prompt)\r\n".data(using: .utf8)!)
            }
            
            // 如果有语言代码，添加language参数
            if let language = language, !language.isEmpty {
                httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
                httpBody.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
                httpBody.append("\(language)\r\n".data(using: .utf8)!)
            }
            
            // 添加响应格式参数
            httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            httpBody.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
            httpBody.append("json\r\n".data(using: .utf8)!)
            
            // 添加音频文件数据
            let fileName = audioFileURL.lastPathComponent
            httpBody.append("--\(boundary)\r\n".data(using: .utf8)!)
            httpBody.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
            httpBody.append("Content-Type: audio/\(fileExtension)\r\n\r\n".data(using: .utf8)!)
            httpBody.append(audioData)
            httpBody.append("\r\n".data(using: .utf8)!)
            
            // 结束boundary
            httpBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = httpBody
            
            // 发送请求
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(
                        domain: "com.mirrochild.openai", 
                        code: 4, 
                        userInfo: [NSLocalizedDescriptionKey: "没有接收到响应数据"]
                    )
                    completion(.failure(error))
                    return
                }
                
                // 解析响应
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let text = json["text"] as? String {
                        completion(.success(text))
                    } else {
                        // 尝试获取错误信息
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            
                            let apiError = NSError(
                                domain: "com.mirrochild.openai", 
                                code: 5, 
                                userInfo: [NSLocalizedDescriptionKey: "API错误: \(message)"]
                            )
                            completion(.failure(apiError))
                        } else {
                            let parseError = NSError(
                                domain: "com.mirrochild.openai", 
                                code: 6, 
                                userInfo: [NSLocalizedDescriptionKey: "无法解析API响应"]
                            )
                            completion(.failure(parseError))
                        }
                    }
                } catch {
                    completion(.failure(error))
                }
            }
            
            task.resume()
            
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - 音频处理辅助方法
    
    /// 将录音文件转换为兼容Whisper API的格式（如果需要）
    /// - Parameters:
    ///   - inputURL: 输入音频文件URL
    ///   - completion: 完成回调，返回转换后的文件URL或错误
    func convertAudioToWhisperCompatibleFormat(
        inputURL: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let fileExtension = inputURL.pathExtension.lowercased()
        let supportedFormats = ["mp3", "mp4", "mpeg", "mpga", "m4a", "wav", "webm"]
        
        // 如果已经是支持的格式，直接返回
        if supportedFormats.contains(fileExtension) {
            completion(.success(inputURL))
            return
        }
        
        // 获取临时目录
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        
        // 创建音频会话
        let asset = AVAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            let error = NSError(
                domain: "com.mirrochild.openai", 
                code: 7, 
                userInfo: [NSLocalizedDescriptionKey: "无法创建音频导出会话"]
            )
            completion(.failure(error))
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp3
        exportSession.shouldOptimizeForNetworkUse = true
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(.success(outputURL))
            case .failed:
                completion(.failure(exportSession.error ?? OpenAIServiceError.transcriptionFailed))
            case .cancelled:
                let error = NSError(
                    domain: "com.mirrochild.openai", 
                    code: 8, 
                    userInfo: [NSLocalizedDescriptionKey: "音频转换取消"]
                )
                completion(.failure(error))
            default:
                let error = NSError(
                    domain: "com.mirrochild.openai", 
                    code: 9, 
                    userInfo: [NSLocalizedDescriptionKey: "音频转换未知错误"]
                )
                completion(.failure(error))
            }
        }
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
        
        // 准备要发送的帧
        prepareFramesForUpload(frames) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let frameDescriptions):
                // 使用帧描述和文本创建请求
                self.createChatCompletionRequest(frameDescriptions: frameDescriptions, 
                                               transcribedText: transcribedText,
                                               completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 处理帧以准备上传到OpenAI
    private func prepareFramesForUpload(_ frames: [ScreenCaptureManager.CapturedFrame], 
                                        completion: @escaping (Result<[String], Error>) -> Void) {
        // 选择代表性帧（例如，每隔5秒选择一帧）
        let selectedFrames = selectRepresentativeFrames(frames)
        
        // 将图像转换为base64字符串
        var frameDescriptions: [String] = []
        
        for frame in selectedFrames {
            if let imageData = frame.image.jpegData(compressionQuality: 0.5) {
                // 将图像转换为base64字符串(但在这里不需要存储它)
                _ = imageData.base64EncodedString()
                
                // 创建带时间戳的帧描述
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                let timeString = formatter.string(from: frame.timestamp)
                
                // 添加帧描述
                let description = "时间点 \(timeString)的屏幕截图: [BASE64_IMAGE_DATA]"
                frameDescriptions.append(description)
                
                // 如果帧有关联的文本，也添加进去
                if let text = frame.transcribedText, !text.isEmpty {
                    frameDescriptions.append("用户在\(timeString)说: \"\(text)\"")
                }
            }
        }
        
        // 如果没有有效的帧，返回错误
        if frameDescriptions.isEmpty {
            let error = NSError(domain: "com.mirrochild.openai", 
                               code: 2, 
                               userInfo: [NSLocalizedDescriptionKey: "没有有效的屏幕捕获数据可处理"])
            completion(.failure(error))
            return
        }
        
        completion(.success(frameDescriptions))
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
    
    // 创建并发送聊天完成请求
    private func createChatCompletionRequest(frameDescriptions: [String], 
                                             transcribedText: String,
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
        let systemPrompt = """
        你是一个帮助老年人使用手机的助手。请根据以下屏幕截图和用户语音输入，提供简单易懂的指导，帮助用户完成他们想要的操作。
        请用简洁明了的语言，避免使用技术术语。给出步骤清晰的指示。
        """
        
        // 准备请求体
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": "以下是我的手机屏幕截图和我说的话，请帮我理解如何使用这个应用: \n\n" + frameDescriptions.joined(separator: "\n\n") + "\n\n我说的话: " + transcribedText]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-vision-preview",  // 使用支持图像的模型
            "messages": messages,
            "max_tokens": 1000
        ]
        
        // 序列化请求体
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
            
            // 解析响应
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    completion(.success(content))
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
        
        // 将语音文件转换为Whisper API支持的格式，然后使用新的transcribeAudio方法处理
        convertAudioToWhisperCompatibleFormat(inputURL: fileURL) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let convertedFileURL):
                self.transcribeAudio(from: convertedFileURL) { transcriptionResult in
                    switch transcriptionResult {
                    case .success(let transcribedText):
                        completion(.success(transcribedText))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
} 