import Foundation
import UIKit
import Combine

class OpenAIService {
    static let shared = OpenAIService()
    
    // OpenAI API Key - 实际使用中应该从更安全的地方获取
    private var apiKey: String {
        return UserDefaults.standard.string(forKey: "openai_api_key") ?? ""
    }
    
    // API基础URL
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    // 发送屏幕捕获数据和语音文本到OpenAI
    func sendScreenCaptureAndVoiceData(frames: [ScreenCaptureManager.CapturedFrame], 
                                       transcribedText: String, 
                                       completion: @escaping (Result<String, Error>) -> Void) {
        // 验证API密钥
        guard !apiKey.isEmpty else {
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
                let base64String = imageData.base64EncodedString()
                
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
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
        return !apiKey.isEmpty
    }
} 