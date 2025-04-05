import ReplayKit
import Foundation
import UIKit

class SampleHandler: RPBroadcastSampleHandler {
    
    // 共享的App Group标识符 - 必须与主应用匹配
    private let appGroupIdentifier = "group.com.mirrochild.screensharing"
    
    // 用于通信的文件URLs
    private var broadcastStartedURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appendingPathComponent("broadcastStarted.txt")
    }
    
    private var latestFrameURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appendingPathComponent("latest_frame.jpg")
    }
    
    private var framesDirectoryURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appendingPathComponent("frames", isDirectory: true)
    }
    
    // 广播开始时间
    private var broadcastStartTime: Date?
    
    // 计数器
    private var frameCount: Int = 0
    private var lastSavedFrameTime: Date = Date()
    
    // 视频编码器
    private var videoEncoder: VideoEncoder?
    
    // 实现广播开始时的逻辑
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // 广播开始
        broadcastStartTime = Date()
        
        // 创建存储帧的目录
        do {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: framesDirectoryURL.path) {
                try fileManager.createDirectory(at: framesDirectoryURL, withIntermediateDirectories: true)
            }
        } catch {
            finishBroadcastWithError(NSError(domain: "MirrorChild", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法创建帧存储目录"]))
            return
        }
        
        // 写入广播状态
        do {
            try "started".write(to: broadcastStartedURL, atomically: true, encoding: .utf8)
        } catch {
            finishBroadcastWithError(NSError(domain: "MirrorChild", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法写入广播状态"]))
            return
        }
        
        // 初始化视频编码器
        videoEncoder = VideoEncoder()
        
        print("MirrorChild广播已开始")
    }
    
    // 处理接收到的视频样本
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            // 处理视频帧
            processVideoSampleBuffer(sampleBuffer)
        case .audioApp:
            // 处理应用音频（可选）
            break
        case .audioMic:
            // 处理麦克风音频（可选）
            break
        @unknown default:
            break
        }
    }
    
    // 广播暂停时的处理
    override func broadcastPaused() {
        // 通知主应用广播已暂停
        do {
            try "paused".write(to: broadcastStartedURL, atomically: true, encoding: .utf8)
        } catch {
            print("无法写入暂停状态: \(error.localizedDescription)")
        }
    }
    
    // 广播恢复时的处理
    override func broadcastResumed() {
        // 通知主应用广播已恢复
        do {
            try "started".write(to: broadcastStartedURL, atomically: true, encoding: .utf8)
        } catch {
            print("无法写入恢复状态: \(error.localizedDescription)")
        }
    }
    
    // 广播结束时的处理
    override func broadcastFinished() {
        // 通知主应用广播已结束
        do {
            try "stopped".write(to: broadcastStartedURL, atomically: true, encoding: .utf8)
        } catch {
            print("无法写入结束状态: \(error.localizedDescription)")
        }
        
        // 清理资源
        videoEncoder = nil
        
        print("MirrorChild广播已结束")
    }
    
    // 处理视频样本缓冲区
    private func processVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // 每秒最多保存2帧
        let now = Date()
        let timeSinceLastSave = now.timeIntervalSince(lastSavedFrameTime)
        if timeSinceLastSave < 0.5 {
            return
        }
        
        // 每5帧处理一次图像，减轻负担
        frameCount += 1
        if frameCount % 5 != 0 {
            return
        }
        
        // 转换为图像并保存
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // 将CVPixelBuffer转换为UIImage
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
            let uiImage = UIImage(cgImage: cgImage)
            
            // 降低图像分辨率以节省空间
            guard let resizedImage = self.resizeImage(uiImage, targetSize: CGSize(width: 540, height: 960)) else { return }
            
            // 将图像保存到文件
            self.saveImageToFile(resizedImage)
            
            // 更新最后一次保存时间
            self.lastSavedFrameTime = now
        }
    }
    
    // 调整图像大小
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage? {
        let size = image.size
        
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        // 使用较小的比例以保持纵横比
        let ratio = min(widthRatio, heightRatio)
        
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    // 保存图像到文件
    private func saveImageToFile(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        
        // 保存最新帧供主应用显示
        do {
            try imageData.write(to: latestFrameURL)
        } catch {
            print("无法保存最新帧: \(error.localizedDescription)")
        }
        
        // 同时保存到帧文件夹，用于历史记录
        let timestamp = Date().timeIntervalSince1970
        let frameURL = framesDirectoryURL.appendingPathComponent("frame_\(Int(timestamp)).jpg")
        
        do {
            try imageData.write(to: frameURL)
        } catch {
            print("无法保存帧到文件夹: \(error.localizedDescription)")
        }
    }
}

// 简单的视频编码器
class VideoEncoder {
    // 这里可以添加更复杂的视频编码逻辑
    init() {
        // 初始化编码器
    }
    
    func encodeVideo(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        // 实现视频编码
    }
} 