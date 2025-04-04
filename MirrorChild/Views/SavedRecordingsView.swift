import SwiftUI
import AVFoundation


struct SavedRecordingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceCaptureManager = VoiceCaptureManager.shared
    @State private var playingRecordingId: String? = nil
    @State private var showingDeleteAlert = false
    @State private var recordingToDelete: SavedRecording? = nil
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    
    // 日期格式化器
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // 时长格式化器
    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.95, blue: 0.98),
                        Color(red: 0.98, green: 0.98, blue: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if voiceCaptureManager.savedRecordings.isEmpty {
                    // 空状态
                    VStack(spacing: 20) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("没有保存的录音")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("当你录制语音时，它们将显示在这里")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    // 录音列表
                    List {
                        ForEach(voiceCaptureManager.savedRecordings) { recording in
                            recordingRow(recording)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        recordingToDelete = recording
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("已保存的录音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("确认删除", isPresented: $showingDeleteAlert) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let recording = recordingToDelete {
                        // 停止播放如果正在播放被删除的录音
                        if playingRecordingId == recording.id {
                            stopPlayback()
                        }
                        
                        // 执行删除
                        voiceCaptureManager.deleteRecording(id: recording.id)
                    }
                }
            } message: {
                Text("确定要删除这个录音吗？此操作无法撤销。")
            }
        }
    }
    
    // 录音行视图
    private func recordingRow(_ recording: SavedRecording) -> some View {
        HStack(spacing: 12) {
            // 播放/停止按钮
            Button(action: {
                togglePlayback(recording)
            }) {
                ZStack {
                    Circle()
                        .fill(playingRecordingId == recording.id ? Color.red : Color.accentColor)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: playingRecordingId == recording.id ? "stop.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(DesignSystem.ButtonStyles.ScaleButton())
            
            // 录音信息
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.description)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(dateFormatter.string(from: recording.creationDate))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    Text("·")
                        .foregroundColor(.secondary)
                    
                    Text(formattedDuration(recording.duration))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 播放状态指示
            if playingRecordingId == recording.id {
                Image(systemName: "waveform")
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }
        }
        .padding(.vertical, 6)
    }
    
    // 播放/停止录音
    private func togglePlayback(_ recording: SavedRecording) {
        if playingRecordingId == recording.id {
            // 停止当前播放
            stopPlayback()
            print("停止播放: \(recording.description)")
        } else {
            // 停止当前播放（如果有）
            stopPlayback()
            
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: recording.fileURL.path) else {
                print("文件不存在: \(recording.fileURL.path)")
                // 从列表中移除不存在的文件
                voiceCaptureManager.deleteRecording(id: recording.id)
                return
            }
            
            print("开始播放: \(recording.description) - \(recording.fileURL.path)")
            
            // 开始播放新录音
            do {
                // 重置音频会话
                let audioSession = AVAudioSession.sharedInstance()
                do {
                    try audioSession.setCategory(.playback)
                    try audioSession.setActive(true)
                } catch {
                    print("设置音频会话失败: \(error.localizedDescription)")
                }
                
                // 打印文件信息
                let fileSize = try FileManager.default.attributesOfItem(atPath: recording.fileURL.path)[.size] as? UInt64 ?? 0
                print("文件大小: \(fileSize) 字节")
                
                // 创建并配置播放器
                audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
                
                guard let player = audioPlayer else {
                    print("无法创建音频播放器")
                    return
                }
                
                // 打印音频信息
                print("音频时长: \(player.duration) 秒")
                print("音频格式: \(player.format)")
                print("音频通道数: \(player.numberOfChannels)")
                
                // 设置音量并准备播放
                player.volume = 1.0
                player.delegate = audioPlayerDelegate
                player.prepareToPlay()
                
                // 尝试播放
                let playSuccess = player.play()
                if playSuccess {
                    // 更新状态
                    DispatchQueue.main.async {
                        self.playingRecordingId = recording.id
                        self.isPlaying = true
                        print("播放成功开始")
                    }
                } else {
                    print("播放启动失败")
                }
            } catch {
                print("播放录音失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 停止播放
    private func stopPlayback() {
        if let player = audioPlayer, player.isPlaying {
            player.stop()
            print("已停止播放")
        }
        
        // 尝试关闭音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("关闭音频会话失败: \(error)")
        }
        
        audioPlayer = nil
        
        DispatchQueue.main.async {
            self.playingRecordingId = nil
            self.isPlaying = false
        }
    }
    
    // 音频播放器代理，用于处理播放完成事件
    private var audioPlayerDelegate: AVAudioPlayerDelegate? {
        return Delegate(onDidFinishPlaying: { _ in
            DispatchQueue.main.async {
                self.stopPlayback()
            }
        })
    }
    
    // 处理音频播放器代理事件的内部类
    private class Delegate: NSObject, AVAudioPlayerDelegate {
        var onDidFinishPlaying: (Bool) -> Void
        
        init(onDidFinishPlaying: @escaping (Bool) -> Void) {
            self.onDidFinishPlaying = onDidFinishPlaying
            super.init()
        }
        
        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            onDidFinishPlaying(flag)
        }
    }
}

struct SavedRecordingsView_Previews: PreviewProvider {
    static var previews: some View {
        SavedRecordingsView()
    }
} 
