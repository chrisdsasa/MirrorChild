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
import AVFoundation
import Photos

class SampleHandler: RPBroadcastSampleHandler {
    
    // MARK: - Properties
    
    // The shared app group identifier
    private let appGroupIdentifier = "group.name.KrypotoZ.MirrorChild"
    
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
    
    // 视频文件目录
    private var videosDirectoryURL: URL {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            NSLog("ERROR: Failed to get container URL for videos directory")
            return FileManager.default.temporaryDirectory.appendingPathComponent("videos")
        }
        return url.appendingPathComponent("videos", isDirectory: true)
    }
    
    // 当前视频文件URL
    private var currentVideoURL: URL?
    
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
    
    // 视频编码相关
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioAppInput: AVAssetWriterInput?
    private var audioMicInput: AVAssetWriterInput?
    private var sessionStarted = false
    private var sessionBeginTime: CMTime?
    
    // 通知名称
    private let recordingFinishedNotificationName = "com.mirrochild.broadcasting.finished"
    
    // MARK: - Lifecycle
    
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        // 创建视频和帧保存目录
        setupDirectories()
        
        // 设置视频编码器
        setupAssetWriter()
        
        // 开始写入视频
        assetWriter?.startWriting()
        
        // 通知主应用录制已开始
        do {
            try "started".write(to: broadcastStartedURL, atomically: true, encoding: .utf8)
            
            // 删除之前的缓冲数据
            if FileManager.default.fileExists(atPath: broadcastBufferURL.path) {
                try FileManager.default.removeItem(at: broadcastBufferURL)
            }
        } catch {
            NSLog("Error writing broadcast started file: \(error.localizedDescription)")
        }
        
        // 重置帧计数
        frameCount = 0
        
        // User has requested to start the broadcast, setup any required resources
        NSLog("Broadcast started")
    }
    
    override func broadcastPaused() {
        NSLog("Broadcast paused")
    }
    
    override func broadcastResumed() {
        NSLog("Broadcast resumed")
    }
    
    override func broadcastFinished() {
        NSLog("Broadcast finished")
        
        // 结束视频编码
        finishRecording()
        
        // 通知主应用录制已结束
        do {
            try "ended".write(to: broadcastStartedURL, atomically: true, encoding: .utf8)
        } catch {
            NSLog("Error writing broadcast ended file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Sample Processing
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        // 确保可以写入
        guard canWrite() else {
            return
        }
        
        // 获取当前样本的时间
        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // 开始会话（仅第一次）
        if !sessionStarted {
            sessionBeginTime = sampleTime
            assetWriter?.startSession(atSourceTime: sampleTime)
            sessionStarted = true
            NSLog("Video session started at time: \(sampleTime.seconds)")
        }
        
        switch sampleBufferType {
        case .video:
            // 处理视频帧
            processVideoSample(sampleBuffer)
            
            // 为了兼容原有功能，也保存部分帧为图片
            frameCount += 1
            if frameCount % frameProcessingInterval == 0 {
                processVideoFrameAsImage(sampleBuffer)
            }
            
        case .audioApp:
            // 处理应用音频
            if let audioInput = audioAppInput, audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
            }
            
        case .audioMic:
            // 处理麦克风音频
            if let micInput = audioMicInput, micInput.isReadyForMoreMediaData {
                micInput.append(sampleBuffer)
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Video Processing Methods
    
    private func processVideoSample(_ sampleBuffer: CMSampleBuffer) {
        if let videoInput = videoInput, videoInput.isReadyForMoreMediaData {
            videoInput.append(sampleBuffer)
        }
    }
    
    private func processVideoFrameAsImage(_ sampleBuffer: CMSampleBuffer) {
        // 从样本缓冲区提取图像
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
        } catch {
            NSLog("Error writing frame data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupDirectories() {
        do {
            // 创建视频目录
            if !FileManager.default.fileExists(atPath: videosDirectoryURL.path) {
                try FileManager.default.createDirectory(at: videosDirectoryURL, withIntermediateDirectories: true)
            }
            
            // 创建帧保存目录
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
            NSLog("Error setting up directories: \(error.localizedDescription)")
        }
    }
    
    private func setupAssetWriter() {
        // 创建视频文件URL
        let timestamp = Int(Date().timeIntervalSince1970)
        let videoFileName = "recording_\(timestamp).mp4"
        currentVideoURL = videosDirectoryURL.appendingPathComponent(videoFileName)
        
        guard let fileURL = currentVideoURL else {
            NSLog("Failed to create video file URL")
            return
        }
        
        // 移除可能存在的同名文件
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                NSLog("Failed to remove existing video file: \(error.localizedDescription)")
            }
        }
        
        // 创建Asset Writer
        do {
            assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
        } catch {
            NSLog("Failed to create AVAssetWriter: \(error.localizedDescription)")
            return
        }
        
        // 获取屏幕尺寸
        let screenScale = UIScreen.main.scale
        var screenWidth = UIScreen.main.bounds.width * screenScale
        var screenHeight = UIScreen.main.bounds.height * screenScale
        
        // 处理iPad特殊情况（宽高可能颠倒）
        if UIDevice.current.userInterfaceIdiom == .pad {
            let temp = screenWidth
            screenWidth = screenHeight
            screenHeight = temp
        }
        
        // 设置视频编码参数
        let videoCompressionProps: [String: Any] = [
            AVVideoAverageBitRateKey: Int(screenWidth * screenHeight * 10.1)
        ]
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: screenWidth,
            AVVideoHeightKey: screenHeight,
            AVVideoCompressionPropertiesKey: videoCompressionProps
        ]
        
        // 创建视频输入
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        
        // 设置音频编码参数
        var audioChannelLayout = AudioChannelLayout()
        memset(&audioChannelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
        audioChannelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000,
            AVChannelLayoutKey: Data(bytes: &audioChannelLayout, count: MemoryLayout<AudioChannelLayout>.size)
        ]
        
        // 创建应用音频输入
        audioAppInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioAppInput?.expectsMediaDataInRealTime = true
        
        // 创建麦克风音频输入
        audioMicInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioMicInput?.expectsMediaDataInRealTime = true
        
        // 添加输入到写入器
        if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
            assetWriter?.add(videoInput)
        }
        
        if let audioAppInput = audioAppInput, assetWriter?.canAdd(audioAppInput) == true {
            assetWriter?.add(audioAppInput)
        }
        
        if let audioMicInput = audioMicInput, assetWriter?.canAdd(audioMicInput) == true {
            assetWriter?.add(audioMicInput)
        }
    }
    
    private func canWrite() -> Bool {
        return assetWriter?.status == .writing
    }
    
    private func finishRecording() {
        guard sessionStarted else { return }
        
        NSLog("Finishing video recording...")
        
        // 标记所有输入为完成
        videoInput?.markAsFinished()
        audioAppInput?.markAsFinished()
        audioMicInput?.markAsFinished()
        
        // 完成写入
        assetWriter?.finishWriting { [weak self] in
            guard let self = self else { return }
            
            if let error = self.assetWriter?.error {
                NSLog("Error during video writing: \(error.localizedDescription)")
            } else if let fileURL = self.currentVideoURL {
                NSLog("Successfully finished recording video at: \(fileURL.path)")
                
                // 创建完成标记文件
                self.createFinishFlagFile(for: fileURL)
                
                // 发送通知到主应用
                self.postRecordingFinishedNotification(videoPath: fileURL.path)
            }
        }
    }
    
    private func createFinishFlagFile(for videoURL: URL) {
        let fileName = videoURL.deletingPathExtension().lastPathComponent
        let finishFlagURL = videosDirectoryURL.appendingPathComponent("\(fileName).finish")
        
        FileManager.default.createFile(atPath: finishFlagURL.path, contents: nil)
    }
    
    private func postRecordingFinishedNotification(videoPath: String) {
        // 写入文件完成信息，包含视频路径
        let finishInfo = ["status": "completed", "videoPath": videoPath]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: finishInfo)
            let finishURL = videosDirectoryURL.appendingPathComponent("recording_finished.json")
            try data.write(to: finishURL)
            NSLog("Wrote recording finished info to: \(finishURL.path)")
        } catch {
            NSLog("Failed to write recording finished info: \(error.localizedDescription)")
        }
    }
    
    // 保存帧为图片文件（保留原有功能）
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
            
            // 保存帧序列
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
                    
                    return date1 > date2
                } catch {
                    return false
                }
            }
            
            // 删除最旧的文件，直到文件数量符合要求
            let filesToDelete = sortedFiles.suffix(from: maxStoredFrames)
            for file in filesToDelete {
                try fileManager.removeItem(at: file)
            }
        } catch {
            NSLog("Error cleaning up old frames: \(error.localizedDescription)")
        }
    }
}
