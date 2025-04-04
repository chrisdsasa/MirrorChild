import Foundation
import SwiftUI
import Combine

// 声明通知名称常量
extension Notification.Name {
    static let voiceProfileRecordingStarted = Notification.Name("voiceProfileRecordingStarted")
    static let voiceProfileRecordingStopped = Notification.Name("voiceProfileRecordingStopped")
    static let voiceProfileDismissed = Notification.Name("voiceProfileDismissed")
}

// 用于在VoiceProfileView和ContentView之间通信的工具类
class VoiceProfileCoordinator {
    static let shared = VoiceProfileCoordinator()
    
    // 当开始在VoiceProfileView中录音时发送通知
    func notifyRecordingStarted() {
        NotificationCenter.default.post(name: .voiceProfileRecordingStarted, object: nil)
    }
    
    // 当在VoiceProfileView中停止录音时发送通知
    func notifyRecordingStopped() {
        NotificationCenter.default.post(name: .voiceProfileRecordingStopped, object: nil)
    }
    
    // 当关闭语音配置页面时发送通知，确保主界面状态更新
    func notifyDismissed() {
        NotificationCenter.default.post(name: .voiceProfileDismissed, object: nil)
    }
}

// 用于ContentView的扩展，设置监听VoiceProfileView状态变化
extension View {
    func listenToVoiceProfileRecording(onStart: @escaping () -> Void, onStop: @escaping () -> Void, onDismiss: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .voiceProfileRecordingStarted)) { _ in
            onStart()
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceProfileRecordingStopped)) { _ in
            onStop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceProfileDismissed)) { _ in
            onDismiss()
        }
    }
} 