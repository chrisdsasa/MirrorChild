import Foundation
import ReplayKit
import UIKit
import Combine

class BroadcastManager: NSObject, ObservableObject {
    static let shared = BroadcastManager()
    
    // MARK: - Properties
    
    // The shared app group identifier - must match with the extension
    private let appGroupIdentifier = "group.com.mirrochild.screensharing"
    
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
    
    // Published properties for SwiftUI
    @Published var isBroadcasting = false
    @Published var currentFrame: UIImage? = nil
    @Published var frameInfos: [String] = []
    @Published var capturedFrames: [UIImage] = []
    @Published var isLoadingFrames = false
    
    // Timer to check broadcast status regularly
    private var broadcastStatusTimer: Timer?
    private var frameCheckTimer: Timer?
    private var imageLoadTimer: Timer?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Start monitoring for broadcast status changes
        startBroadcastMonitoring()
    }
    
    // MARK: - Private Methods
    
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
        
        // Start the timers immediately
        broadcastStatusTimer?.fire()
        frameCheckTimer?.fire()
        imageLoadTimer?.fire()
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
} 