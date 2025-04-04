//
//  SampleHandler.swift
//  MirrorChildBroadcast
//
//  Created by 赵嘉策 on 2025/4/4.
//

import ReplayKit
import Foundation
import UIKit
import CoreImage

class SampleHandler: RPBroadcastSampleHandler {
    
    // MARK: - Properties
    
    // The shared app group identifier
    private let appGroupIdentifier = "group.com.mirrochild.screensharing"
    
    // URLs for communication with the main app
    private var broadcastStartedURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            // Log error if we can't get the container URL - this is critical for debugging
            NSLog("ERROR: Failed to get container URL for group: \(appGroupIdentifier)")
            return FileManager.default.temporaryDirectory.appendingPathComponent("broadcastStarted.txt")
        }
        return url.appendingPathComponent("broadcastStarted.txt")
    }
    
    private var broadcastBufferURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            // Log error if we can't get the container URL - this is critical for debugging
            NSLog("ERROR: Failed to get container URL for group: \(appGroupIdentifier)")
            return FileManager.default.temporaryDirectory.appendingPathComponent("broadcastBuffer.txt")
        }
        return url.appendingPathComponent("broadcastBuffer.txt")
    }
    
    // 添加图片保存目录
    private var framesDirectoryURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            NSLog("ERROR: Failed to get container URL for frames directory")
            return FileManager.default.temporaryDirectory.appendingPathComponent("frames")
        }
        return url.appendingPathComponent("frames", isDirectory: true)
    }
    
    // 添加最新图片帧的URL
    private var latestFrameURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            NSLog("ERROR: Failed to get container URL for latest frame")
            return FileManager.default.temporaryDirectory.appendingPathComponent("latest_frame.jpg")
        }
        return url.appendingPathComponent("latest_frame.jpg")
    }
    
    // 添加帧处理相关变量
    private var frameCount: Int = 0
    private let maxStoredFrames = 10
    private let frameProcessingInterval = 6  // 每6帧处理一次，降低CPU使用率
    private let ciContext = CIContext()
    
    // MARK: - Lifecycle
    
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // 创建帧保存目录
        do {
            if !FileManager.default.fileExists(atPath: framesDirectoryURL.path) {
                try FileManager.default.createDirectory(at: framesDirectoryURL, withIntermediateDirectories: true)
            } else {
                // 清空已有帧
                let contents = try FileManager.default.contentsOfDirectory(at: framesDirectoryURL, includingPropertiesForKeys: nil)
                for file in contents {
                    try FileManager.default.removeItem(at: file)
                }
            }
        } catch {
            NSLog("Error setting up frames directory: \(error.localizedDescription)")
        }
        
        // Notify the main app that broadcast has started
        do {
            try "started".write(to: broadcastStartedURL, atomically: true, encoding: .utf8)
            
            // Delete any previous buffer data
            if FileManager.default.fileExists(atPath: broadcastBufferURL.path) {
                try FileManager.default.removeItem(at: broadcastBufferURL)
            }
        } catch {
            print("Error writing broadcast started file: \(error.localizedDescription)")
        }
        
        // 重置帧计数
        frameCount = 0
        
        // User has requested to start the broadcast, setup any required resources
        print("Broadcast started")
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast, update UI accordingly
        print("Broadcast paused")
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast, update UI accordingly
        print("Broadcast resumed")
    }
    
    override func broadcastFinished() {
        // User has requested to finish the broadcast, clean up resources
        print("Broadcast finished")
        
        // Notify the main app that broadcast has ended
        do {
            try "ended".write(to: broadcastStartedURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing broadcast ended file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sample Processing
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            // Process video sample buffer
            processVideoFrame(sampleBuffer)
            
        case .audioApp:
            // Process app audio sample buffer (audio of the application)
            break
            
        case .audioMic:
            // Process mic audio sample buffer (audio from microphone)
            break
            
        @unknown default:
            // Handle future buffer types
            break
        }
    }
    
    // MARK: - Helper Methods
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        // 增加计数器
        frameCount += 1
        
        // 为了节省资源，只处理每几帧中的一帧
        guard frameCount % frameProcessingInterval == 0 else {
            return
        }
        
        // Extract image from buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // 将CVPixelBuffer转换为UIImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            NSLog("Failed to create CGImage from CIImage")
            return
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        
        // 获取图片尺寸
        let width = uiImage.size.width
        let height = uiImage.size.height
        
        // 保存帧信息到文本文件
        let timestamp = Date().timeIntervalSince1970
        let frameInfo = "Frame: \(Int(width))x\(Int(height)) @ \(String(format: "%.3f", timestamp))"
        
        do {
            // 保存帧信息到文本文件
            try frameInfo.write(to: broadcastBufferURL, atomically: true, encoding: .utf8)
            
            // 保存当前帧为图片
            saveFrameAsImage(uiImage)
            
            // 记录日志
            NSLog("Broadcast frame captured: \(Int(width))x\(Int(height))")
        } catch {
            NSLog("Error writing frame data: \(error.localizedDescription)")
        }
    }
    
    // 保存帧为图片文件
    private func saveFrameAsImage(_ image: UIImage) {
        // 创建一个缩小版本的图像以减少内存和存储使用
        let maxDimension: CGFloat = 800
        let scaledImage = scaleImage(image, toMaxDimension: maxDimension)
        
        guard let jpegData = scaledImage.jpegData(compressionQuality: 0.7) else {
            NSLog("Failed to convert image to JPEG data")
            return
        }
        
        do {
            // 保存为最新帧
            try jpegData.write(to: latestFrameURL)
            
            // 可选：按时间顺序保存多个帧
            let frameURL = framesDirectoryURL.appendingPathComponent("frame_\(Date().timeIntervalSince1970).jpg")
            try jpegData.write(to: frameURL)
            
            // 清理旧帧以节省空间
            cleanupOldFrames()
        } catch {
            NSLog("Error saving image: \(error.localizedDescription)")
        }
    }
    
    // 缩放图像
    private func scaleImage(_ image: UIImage, toMaxDimension maxDimension: CGFloat) -> UIImage {
        let originalSize = image.size
        
        // 如果图像已经小于最大尺寸，则返回原图
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            return image
        }
        
        // 计算新尺寸，保持宽高比
        let ratio = max(originalSize.width, originalSize.height) / maxDimension
        let newSize = CGSize(width: originalSize.width / ratio, height: originalSize.height / ratio)
        
        // 进行缩放绘制
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    // 清理旧的帧图像
    private func cleanupOldFrames() {
        do {
            let fileManager = FileManager.default
            let frameFiles = try fileManager.contentsOfDirectory(at: framesDirectoryURL, includingPropertiesForKeys: [.contentModificationDateKey])
            
            // 如果帧数量小于最大值，不需要清理
            if frameFiles.count <= maxStoredFrames {
                return
            }
            
            // 按修改日期排序
            let sortedFiles = frameFiles.sorted { (file1, file2) -> Bool in
                do {
                    let attrs1 = try file1.resourceValues(forKeys: [.contentModificationDateKey])
                    let attrs2 = try file2.resourceValues(forKeys: [.contentModificationDateKey])
                    
                    guard let date1 = attrs1.contentModificationDate,
                          let date2 = attrs2.contentModificationDate else {
                        return false
                    }
                    
                    return date1 < date2  // 较早的日期在前
                } catch {
                    return false
                }
            }
            
            // 删除最旧的文件
            let filesToRemove = sortedFiles.prefix(frameFiles.count - maxStoredFrames)
            for fileURL in filesToRemove {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            NSLog("Error cleaning up old frames: \(error.localizedDescription)")
        }
    }
}
