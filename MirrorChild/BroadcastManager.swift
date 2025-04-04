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
    
    // Published properties for SwiftUI
    @Published var isBroadcasting = false
    @Published var currentFrame: UIImage? = nil
    @Published var frameInfos: [String] = []
    
    // Timer to check broadcast status regularly
    private var broadcastStatusTimer: Timer?
    private var frameCheckTimer: Timer?
    
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
        
        // Start the timers immediately
        broadcastStatusTimer?.fire()
        frameCheckTimer?.fire()
    }
    
    private func checkBroadcastStatus() {
        guard FileManager.default.fileExists(atPath: broadcastStartedURL.path) else {
            // No broadcast status file exists yet
            if isBroadcasting {
                // If we thought we were broadcasting but file is gone, update state
                DispatchQueue.main.async {
                    self.isBroadcasting = false
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
} 