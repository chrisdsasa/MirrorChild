import Foundation
import ReplayKit
import UIKit
import Combine
import AVFoundation
import Photos

class BroadcastManager: NSObject, ObservableObject {
    static let shared = BroadcastManager()
    
    // MARK: - Properties
    
    // The shared app group identifier - must match with the extension
    private let appGroupIdentifier = "group.name.KrypotoZ.MirrorChild"
    
    // URLs for communication with the broadcast extension
    private var broadcastStartedURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appendingPathComponent("broadcastStarted.txt")
    }
    
    private var broadcastBufferURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appendingPathComponent("broadcastBuffer.txt")
    }
    
    // 图像帧相关URL
    private var latestFrameURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appendingPathComponent("latest_frame.jpg")
    }
    
    private var framesDirectoryURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appendingPathComponent("frames", isDirectory: true)
    }
    
    // 视频文件相关URL
    private var videosDirectoryURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appendingPathComponent("videos", isDirectory: true)
    }
    
    private var recordingFinishedURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)!
            .appendingPathComponent("videos/recording_finished.json")
    }
    
    // Published properties for SwiftUI
    @Published var isBroadcasting = false
    @Published var currentFrame: UIImage? = nil
    @Published var frameInfos: [String] = []
    @Published var capturedFrames: [UIImage] = []
    @Published var isLoadingFrames = false
    @Published var recordedVideos: [RecordedVideo] = []
    @Published var latestRecordedVideo: RecordedVideo? = nil
    
    // Timer to check broadcast status regularly
    private var broadcastStatusTimer: Timer?
    private var frameCheckTimer: Timer?
    private var imageLoadTimer: Timer?
    private var videoCheckTimer: Timer?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // 创建必要的目录
        setupDirectories()
        
        // 加载已有的视频文件
        loadExistingVideos()
        
        // Start monitoring for broadcast status changes
        startBroadcastMonitoring()
    }
    
    // MARK: - Private Methods
    
    private func setupDirectories() {
        let fileManager = FileManager.default
        
        // 确保视频目录存在
        if !fileManager.fileExists(atPath: videosDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: videosDirectoryURL, withIntermediateDirectories: true)
            } catch {
                print("Failed to create videos directory: \(error.localizedDescription)")
            }
        }
        
        // 确保帧目录存在
        if !fileManager.fileExists(atPath: framesDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: framesDirectoryURL, withIntermediateDirectories: true)
            } catch {
                print("Failed to create frames directory: \(error.localizedDescription)")
            }
        }
    }
    
    private func startBroadcastMonitoring() {
        // Check broadcast status every second
        broadcastStatusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkBroadcastStatus()
        }
        
        // Check for new frames every 0.5 seconds
        frameCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForNewFrames()
        }
        
        // Load images every 0.3 seconds when broadcasting
        imageLoadTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self, self.isBroadcasting else { return }
            self.loadLatestImage()
        }
        
        // Check for new videos every 2 seconds
        videoCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForNewVideos()
        }
        
        // Start the timers immediately
        broadcastStatusTimer?.fire()
        frameCheckTimer?.fire()
        imageLoadTimer?.fire()
        videoCheckTimer?.fire()
    }
    
    private func checkBroadcastStatus() {
        guard FileManager.default.fileExists(atPath: broadcastStartedURL.path) else {
            // No broadcast status file exists yet
            if isBroadcasting {
                // If we thought we were broadcasting but file is gone, update state
                DispatchQueue.main.async {
                    self.isBroadcasting = false
                    // 清空图像数据
                    self.capturedFrames.removeAll()
                    self.currentFrame = nil
                }
            }
            return
        }
        
        do {
            let status = try String(contentsOf: broadcastStartedURL, encoding: .utf8)
            let newBroadcastingState = (status == "started")
            
            // Update UI on main thread if state changed
            if newBroadcastingState != isBroadcasting {
                DispatchQueue.main.async {
                    self.isBroadcasting = newBroadcastingState
                    
                    // 如果广播结束，清空图像数据
                    if !newBroadcastingState {
                        self.capturedFrames.removeAll()
                        self.currentFrame = nil
                        
                        // 当广播结束时，检查是否有新视频
                        self.checkForNewVideos()
                    }
                }
            }
        } catch {
            print("Error reading broadcast status: \(error.localizedDescription)")
        }
    }
    
    private func checkForNewFrames() {
        guard isBroadcasting, FileManager.default.fileExists(atPath: broadcastBufferURL.path) else {
            return
        }
        
        do {
            let frameInfo = try String(contentsOf: broadcastBufferURL, encoding: .utf8)
            
            // Update the frame info list
            DispatchQueue.main.async {
                if !self.frameInfos.contains(frameInfo) {
                    self.frameInfos.insert(frameInfo, at: 0)
                    
                    // Keep only the last 10 frames
                    if self.frameInfos.count > 10 {
                        self.frameInfos.removeLast()
                    }
                }
            }
        } catch {
            print("Error reading frame data: \(error.localizedDescription)")
        }
    }
    
    private func checkForNewVideos() {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: videosDirectoryURL.path) else {
            return
        }
        
        do {
            let videoFiles = try fileManager.contentsOfDirectory(at: videosDirectoryURL, includingPropertiesForKeys: [.contentModificationDateKey])
                .filter { $0.pathExtension == "mp4" }
            
            // 处理完成标记文件
            let finishFlags = try fileManager.contentsOfDirectory(at: videosDirectoryURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "finish" }
                .map { $0.deletingPathExtension().lastPathComponent }
            
            // 有完成标记的视频文件
            let completedVideoFiles = videoFiles.filter { 
                finishFlags.contains($0.deletingPathExtension().lastPathComponent)
            }
            
            // 处理新完成的视频
            for videoURL in completedVideoFiles {
                let fileName = videoURL.lastPathComponent
                
                // 检查是否已经在记录中
                if !recordedVideos.contains(where: { $0.fileName == fileName }) {
                    do {
                        let attributes = try fileManager.attributesOfItem(atPath: videoURL.path)
                        let creationDate = attributes[.creationDate] as? Date ?? Date()
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        
                        // 异步处理缩略图生成
                        Task {
                            // 创建视频缩略图
                            let thumbnail = await self.createThumbnail(for: videoURL)
                            
                            // 创建新的视频记录
                            let video = RecordedVideo(
                                url: videoURL,
                                fileName: fileName,
                                creationDate: creationDate,
                                fileSize: fileSize,
                                thumbnail: thumbnail
                            )
                            
                            // 添加到列表
                            await MainActor.run {
                                self.recordedVideos.append(video)
                                self.recordedVideos.sort { $0.creationDate > $1.creationDate }
                                self.latestRecordedVideo = video
                            }
                        }
                    } catch {
                        print("Error processing video file: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("Error checking for new videos: \(error.localizedDescription)")
        }
    }
    
    private func createThumbnail(for videoURL: URL) async -> UIImage? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // 设置缩略图的最大尺寸
        let width = 300.0
        imageGenerator.maximumSize = CGSize(width: width, height: width)
        
        do {
            // 获取视频中间点的时间
            let duration = try await asset.load(.duration)
            let time = CMTime(seconds: duration.seconds / 2, preferredTimescale: 600)
            
            return await withCheckedContinuation { continuation in
                imageGenerator.generateCGImageAsynchronously(for: time) { cgImage, actualTime, error in
                    if let error = error {
                        print("Error generating thumbnail: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    if let cgImage = cgImage {
                        continuation.resume(returning: UIImage(cgImage: cgImage))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 加载最新的图片帧
    private func loadLatestImage() {
        guard isBroadcasting, FileManager.default.fileExists(atPath: latestFrameURL.path) else {
            return
        }
        
        do {
            // 读取图像数据
            let imageData = try Data(contentsOf: latestFrameURL)
            if let image = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    self.currentFrame = image
                    
                    // 保持最多10张图片在内存中
                    if self.capturedFrames.count >= 10 {
                        self.capturedFrames.removeLast()
                    }
                    self.capturedFrames.insert(image, at: 0)
                }
            }
        } catch {
            print("Error loading latest frame: \(error.localizedDescription)")
        }
    }
    
    private func loadExistingVideos() {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: videosDirectoryURL.path) else {
            return
        }
        
        do {
            let videoFiles = try fileManager.contentsOfDirectory(at: videosDirectoryURL, includingPropertiesForKeys: [.contentModificationDateKey])
                .filter { $0.pathExtension == "mp4" }
            
            // 处理完成标记文件
            let finishFlags = try fileManager.contentsOfDirectory(at: videosDirectoryURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "finish" }
                .map { $0.deletingPathExtension().lastPathComponent }
            
            // 有完成标记的视频文件
            let completedVideoFiles = videoFiles.filter { 
                finishFlags.contains($0.deletingPathExtension().lastPathComponent)
            }
            
            for videoURL in completedVideoFiles {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: videoURL.path)
                    let creationDate = attributes[.creationDate] as? Date ?? Date()
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    // 异步处理缩略图生成
                    Task {
                        // 创建视频缩略图
                        let thumbnail = await self.createThumbnail(for: videoURL)
                        
                        let video = RecordedVideo(
                            url: videoURL,
                            fileName: videoURL.lastPathComponent,
                            creationDate: creationDate,
                            fileSize: fileSize,
                            thumbnail: thumbnail
                        )
                        
                        await MainActor.run {
                            self.recordedVideos.append(video)
                            self.recordedVideos.sort { $0.creationDate > $1.creationDate }
                        }
                    }
                } catch {
                    print("Error loading video: \(error.localizedDescription)")
                }
            }
        } catch {
            print("Error loading existing videos: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    // 加载所有保存的帧
    func loadAllCapturedFrames() {
        guard FileManager.default.fileExists(atPath: framesDirectoryURL.path) else {
            return
        }
        
        DispatchQueue.main.async {
            self.isLoadingFrames = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                var frameFiles = try fileManager.contentsOfDirectory(at: self.framesDirectoryURL, 
                                                                   includingPropertiesForKeys: [.contentModificationDateKey])
                
                // 按修改日期排序，最新的优先
                frameFiles.sort { (file1, file2) -> Bool in
                    do {
                        let attrs1 = try file1.resourceValues(forKeys: [.contentModificationDateKey])
                        let attrs2 = try file2.resourceValues(forKeys: [.contentModificationDateKey])
                        
                        guard let date1 = attrs1.contentModificationDate,
                              let date2 = attrs2.contentModificationDate else {
                            return false
                        }
                        
                        return date1 > date2  // 较新的日期在前
                    } catch {
                        return false
                    }
                }
                
                // 限制加载数量
                let filesToLoad = frameFiles.prefix(20)
                var loadedImages: [UIImage] = []
                
                for fileURL in filesToLoad {
                    do {
                        let imageData = try Data(contentsOf: fileURL)
                        if let image = UIImage(data: imageData) {
                            loadedImages.append(image)
                        }
                    } catch {
                        print("Error loading frame from \(fileURL): \(error.localizedDescription)")
                    }
                }
                
                // 更新UI
                DispatchQueue.main.async {
                    self.capturedFrames = loadedImages
                    self.isLoadingFrames = false
                }
                
            } catch {
                print("Error loading captured frames: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingFrames = false
                }
            }
        }
    }
    
    // 保存视频到相册
    func saveVideoToPhotos(videoURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: videoURL, options: nil)
                }) { success, error in
                    DispatchQueue.main.async {
                        completion(success, error)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "BroadcastManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Photos access denied"]))
                }
            }
        }
    }
    
    // 删除视频文件
    func deleteVideo(video: RecordedVideo) {
        let fileManager = FileManager.default
        
        do {
            try fileManager.removeItem(at: video.url)
            
            // 同时删除对应的完成标记文件
            let finishFlagURL = video.url.deletingPathExtension().appendingPathExtension("finish")
            if fileManager.fileExists(atPath: finishFlagURL.path) {
                try fileManager.removeItem(at: finishFlagURL)
            }
            
            // 更新视频列表
            DispatchQueue.main.async {
                self.recordedVideos.removeAll(where: { $0.url == video.url })
            }
        } catch {
            print("Error deleting video: \(error.localizedDescription)")
        }
    }
    
    // 检查录制功能是否可用
    func isScreenRecordingAvailable() -> Bool {
        if #available(iOS 12.0, *) {
            return true
        }
        return false
    }
}

// 录制的视频模型
struct RecordedVideo: Identifiable {
    let id = UUID()
    let url: URL
    let fileName: String
    let creationDate: Date
    let fileSize: Int64
    let thumbnail: UIImage?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
    
    var formattedFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useMB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: fileSize)
    }
} 
