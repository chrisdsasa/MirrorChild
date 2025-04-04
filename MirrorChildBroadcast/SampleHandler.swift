//
//  SampleHandler.swift
//  MirrorChildBroadcast
//
//  Created by 赵嘉策 on 2025/4/4.
//

import ReplayKit
import Foundation

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
    
    // MARK: - Lifecycle
    
    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
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
        // Extract image from buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Get image dimensions
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        // In production, we should save more detailed frame data
        let timestamp = Date().timeIntervalSince1970
        let frameInfo = "Frame: \(width)x\(height) @ \(String(format: "%.3f", timestamp))"
        
        do {
            try frameInfo.write(to: broadcastBufferURL, atomically: true, encoding: .utf8)
            
            // Log successful frame capture
            NSLog("Broadcast frame captured: \(width)x\(height)")
        } catch {
            NSLog("Error writing frame data: \(error.localizedDescription)")
        }
    }
}
