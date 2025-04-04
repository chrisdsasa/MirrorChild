import SwiftUI
import AVFoundation

struct VoiceProfileRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    
    // 录音状态
    @State private var isRecording = false
    @State private var isPlayingBack = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingProgress: CGFloat = 0
    @State private var showingUploadSuccess = false
    @State private var showingPermissionAlert = false
    
    // 音频相关
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var recordingURL: URL?
    
    // 常量
    private let maxRecordingTime: TimeInterval = 30 // 30秒录音
    private let targetSampleTime = "targetRecordingTime".localized // 目标样本时间
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.97, green: 0.97, blue: 0.98),
                    Color(red: 0.96, green: 0.96, blue: 0.98),
                    Color(red: 0.95, green: 0.95, blue: 0.98)
                ]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            // 樱花装饰元素（微妙）
            GeometryReader { geometry in
                ZStack {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.pink.opacity(0.2))
                        .position(x: geometry.size.width - 40, y: 60)
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.pink.opacity(0.15))
                        .position(x: 30, y: geometry.size.height - 100)
                }
            }
            
            VStack(spacing: 25) {
                // 标题
                HStack {
                    Text("voiceProfileTitle".localized)
                        .font(.system(size: 24, weight: .medium))
                        .tracking(1)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    
                    Spacer()
                    
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        }
                        dismiss()
                    }) {
                        Text("doneButton".localized)
                            .font(.system(size: 16, weight: .medium))
                            .tracking(1)
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 15)
                            .background(
                                Capsule()
                                    .stroke(Color(red: 0.5, green: 0.5, blue: 0.7).opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                // 说明文本
                Text("voiceProfileInstructions".localized)
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 25)
                
                // 录音可视化和进度
                ZStack {
                    // 进度条背景
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.9))
                        .frame(height: 200)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color(red: 0.7, green: 0.7, blue: 0.9).opacity(0.3), lineWidth: 1)
                        )
                    
                    VStack(spacing: 20) {
                        // 声波可视化
                        if isRecording {
                            waveformView
                        } else if recordingURL != nil {
                            // 已录制完成的状态
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.5))
                        } else {
                            // 未开始录制的状态
                            Image(systemName: "mic.circle")
                                .font(.system(size: 40))
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                        }
                        
                        // 进度指示器
                        VStack(spacing: 8) {
                            // 进度条
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color(red: 0.9, green: 0.9, blue: 0.95))
                                        .frame(height: 10)
                                    
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 0.5, green: 0.5, blue: 0.8),
                                                    Color(red: 0.6, green: 0.5, blue: 0.8)
                                                ]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * recordingProgress, height: 10)
                                }
                            }
                            .frame(height: 10)
                            
                            // 时间指示器
                            HStack {
                                Text(String(format: "recordingTime".localized, recordingTime))
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                                
                                Spacer()
                                
                                Text(targetSampleTime)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, 20)
                
                // 按钮区域
                VStack(spacing: 15) {
                    // 录制/播放控制
                    HStack(spacing: 30) {
                        if recordingURL != nil && !isRecording {
                            // 播放按钮
                            Button(action: togglePlayback) {
                                HStack {
                                    Image(systemName: isPlayingBack ? "pause.fill" : "play.fill")
                                        .font(.system(size: 15))
                                    Text(isPlayingBack ? "pausePlayback".localized : "playRecording".localized)
                                        .font(.system(size: 16))
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.5, green: 0.7, blue: 0.5))
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            }
                            
                            // 重新录制按钮
                            Button(action: resetRecording) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 15))
                                    Text("recordAgain".localized)
                                        .font(.system(size: 16))
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.7, green: 0.5, blue: 0.5))
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            }
                        } else {
                            // 录制按钮
                            Button(action: toggleRecording) {
                                HStack {
                                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 15))
                                    Text(isRecording ? "stopRecording".localized : "startRecording".localized)
                                        .font(.system(size: 16))
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(
                                    Capsule()
                                        .fill(isRecording ? Color(red: 0.8, green: 0.4, blue: 0.4) : Color(red: 0.5, green: 0.5, blue: 0.8))
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            }
                        }
                    }
                    
                    // 上传按钮 - 只在有录音且未正在录制时显示
                    if recordingURL != nil && !isRecording {
                        Button(action: uploadRecording) {
                            HStack {
                                Image(systemName: "arrow.up.circle")
                                    .font(.system(size: 15))
                                Text("uploadVoiceProfile".localized)
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(width: 220)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.4, green: 0.6, blue: 0.8))
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                    }
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .padding()
            
            // 上传成功提示
            if showingUploadSuccess {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("uploadSuccess".localized)
                                .font(.title2)
                                .foregroundColor(.white)
                                .fontWeight(.medium)
                            
                            Button(action: {
                                withAnimation {
                                    showingUploadSuccess = false
                                }
                                // 上传成功后返回前一个界面
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    dismiss()
                                }
                            }) {
                                Text("confirm".localized)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 30)
                                    .background(Capsule().fill(Color.blue))
                            }
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(white: 0.2))
                        )
                        .padding(30)
                    )
                    .transition(.opacity)
            }
        }
        .onAppear {
            checkMicrophonePermission()
            setupAudioSession()
        }
        .onDisappear {
            stopRecording()
            stopPlayback()
        }
        .onReceive(timer) { _ in
            if isRecording {
                recordingTime += 0.1
                recordingProgress = min(recordingTime / maxRecordingTime, 1.0)
                
                // 达到最大录制时间时自动停止
                if recordingTime >= maxRecordingTime {
                    stopRecording()
                }
            }
        }
        .alert(isPresented: $showingPermissionAlert) {
            Alert(
                title: Text("permissionRequired".localized),
                message: Text("microphonePermissionMessage".localized),
                primaryButton: .default(Text("openSettingsButton".localized)) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // 波形视图 - 模拟音频波形
    private var waveformView: some View {
        GeometryReader { geometry in
            HStack(spacing: 3) {
                ForEach(0..<Int(geometry.size.width / 6), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 0.5, green: 0.5, blue: 0.8))
                        .frame(width: 3, height: getWaveHeight(at: index, width: geometry.size.width))
                        .animation(
                            Animation.easeInOut(duration: 0.2)
                                .repeatForever()
                                .delay(Double(index) * 0.01),
                            value: isRecording
                        )
                }
            }
            .frame(height: 80)
        }
        .frame(height: 80)
    }
    
    // 生成波形高度
    private func getWaveHeight(at index: Int, width: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = 20
        let maxAdditionalHeight: CGFloat = 60
        let seed = Date().timeIntervalSince1970 + Double(index)
        let randomFactor = sin(seed) * 0.5 + 0.5 // 0.0-1.0
        
        return baseHeight + randomFactor * maxAdditionalHeight
    }
    
    // 检查麦克风权限
    private func checkMicrophonePermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .denied:
            showingPermissionAlert = true
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if !granted {
                    DispatchQueue.main.async {
                        showingPermissionAlert = true
                    }
                }
            }
        case .granted:
            // 已授权，可以继续
            break
        @unknown default:
            break
        }
    }
    
    // 设置音频会话
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)
        } catch {
            print("设置音频会话失败: \(error)")
        }
    }
    
    // 开始/停止录制
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    // 开始录制
    private func startRecording() {
        // 准备录音文件路径
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("voiceProfile_\(Date().timeIntervalSince1970).m4a")
        recordingURL = audioFilename
        
        // 录音设置
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            
            // 重置状态
            isRecording = true
            recordingTime = 0
            recordingProgress = 0
        } catch {
            print("录音启动失败: \(error)")
        }
    }
    
    // 停止录制
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
    }
    
    // 播放/暂停
    private func togglePlayback() {
        if isPlayingBack {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    // 开始播放
    private func startPlayback() {
        guard let url = recordingURL else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = AVPlayerObserver(onDidFinishPlaying: {
                isPlayingBack = false
            })
            audioPlayer?.play()
            isPlayingBack = true
        } catch {
            print("播放录音失败: \(error)")
        }
    }
    
    // 停止播放
    private func stopPlayback() {
        audioPlayer?.stop()
        isPlayingBack = false
    }
    
    // 重置录制
    private func resetRecording() {
        stopPlayback()
        recordingURL = nil
        recordingTime = 0
        recordingProgress = 0
    }
    
    // 上传录音
    private func uploadRecording() {
        // 这里是模拟上传
        // TODO: 实现实际的API上传功能
        
        // 模拟上传延迟
        withAnimation {
            // 模拟上传进度
            let uploadDuration = 1.5 // 1.5秒模拟上传
            
            // 模拟上传完成后显示成功提示
            DispatchQueue.main.asyncAfter(deadline: .now() + uploadDuration) {
                withAnimation {
                    showingUploadSuccess = true
                }
            }
        }
    }
}

// 辅助类：监听音频播放结束
class AVPlayerObserver: NSObject, AVAudioPlayerDelegate {
    let onDidFinishPlaying: () -> Void
    
    init(onDidFinishPlaying: @escaping () -> Void) {
        self.onDidFinishPlaying = onDidFinishPlaying
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onDidFinishPlaying()
    }
}

#Preview {
    VoiceProfileRecordingView()
} 