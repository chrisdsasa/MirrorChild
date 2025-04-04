import SwiftUI
import AVFoundation

struct VoiceProfileRecordingView: View {
    // 使用全局颜色常量
    private let accentColor = Color.accentRebeccaPurple
    private let surfaceColor = Color.surfaceThistle
    
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
    @State private var player: AVAudioPlayer?
    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var alertMessage = ""
    @State private var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    
    // 音频电平监控
    @State private var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    @State private var meterTimer: Timer?
    
    // 常量
    private let maxRecordingTime: TimeInterval = 30 // 30秒录音
    private let targetSampleTime = "targetRecordingTime".localized // 目标样本时间
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    // 检查30秒是否完成
    private var isRecordingComplete: Bool {
        return recordingTime >= 29.5
    }
    
    // 进度百分比
    private var progressPercentage: Double {
        return min(recordingTime / 30.0, 1.0)
    }
    
    var body: some View {
        ZStack {
            // 背景
            surfaceColor.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // 标题
                Text("声音录制")
                    .font(.system(size: 32, weight: .medium))
                    .tracking(2)
                    .foregroundColor(accentColor)
                    .padding(.top, 30)
                
                Spacer()
                
                // 波形视图
                waveformView
                    .padding(.horizontal, 20)
                    .opacity(isRecording || isPlayingBack ? 1 : 0.3)
                
                // 进度和时间信息
                VStack(spacing: 15) {
                    // 进度条
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(surfaceColor)
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isRecordingComplete ? 
                                  Color(red: 0.4, green: 0.7, blue: 0.5) : 
                                  accentColor)
                            .frame(width: max(CGFloat(progressPercentage) * UIScreen.main.bounds.width - 40, 0), 
                                   height: 8)
                    }
                    
                    // 时间文本
                    Text(String(format: "%.0f 秒", min(recordingTime, 30)))
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(accentColor.opacity(0.8))
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 录制/播放控制
                recordingControlButtons
                    .padding(.bottom, 20)
                
                // 上传按钮
                uploadButton
                    .padding(.bottom, 40)
            }
            .padding(.horizontal)
            
            // 关闭按钮
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(accentColor.opacity(0.7))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            checkPermission()
        }
        .onDisappear {
            stopRecording()
            stopPlayback()
            meterTimer?.invalidate()
        }
        .onReceive(timer) { _ in
            updateTimer()
        }
        .alert(isPresented: $showingPermissionAlert) {
            Alert(
                title: Text("错误"),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    // 录制控制按钮
    private var recordingControlButtons: some View {
        Group {
            if recordingURL != nil && !isRecording {
                HStack(spacing: 40) {
                    // 播放按钮
                    Button(action: togglePlayback) {
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.4, green: 0.7, blue: 0.5))
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                
                                Image(systemName: isPlayingBack ? "pause.fill" : "play.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // 重新录制按钮
                    Button(action: resetRecording) {
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.8))
                                    .frame(width: 80, height: 80)
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                                
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            } else {
                // 录制按钮
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color(red: 0.8, green: 0.4, blue: 0.4) : accentColor)
                            .frame(width: 100, height: 100)
                            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                        
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // 上传按钮
    private var uploadButton: some View {
        Group {
            if recordingURL != nil && !isRecording {
                Button(action: uploadRecording) {
                    ZStack {
                        Capsule()
                            .fill(accentColor)
                            .frame(height: 60)
                            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                        
                        HStack(spacing: 15) {
                            Image(systemName: uploadSuccess ? "checkmark.circle" : "arrow.up.circle")
                                .font(.system(size: 26))
                            
                            Text(uploadSuccess ? "已上传" : "上传声音")
                                .font(.system(size: 24, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: 250)
                }
                .disabled(uploadSuccess)
                .opacity(uploadSuccess ? 0.7 : 1)
            }
        }
    }
    
    // 波形视图 - 根据音频电平调整
    private var waveformView: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景网格线
                VStack(spacing: 30) {
                    ForEach(0..<4) { _ in
                        Rectangle()
                            .fill(accentColor.opacity(0.1))
                            .frame(height: 1)
                    }
                }
                .frame(maxHeight: .infinity)
                
                // 波形图
                HStack(spacing: 4) {
                    ForEach(0..<audioLevels.count, id: \.self) { index in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        accentColor.opacity(0.7),
                                        accentColor,
                                        accentColor.opacity(0.8)
                                    ]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 6, height: audioLevels[index])
                            .animation(
                                Animation.easeInOut(duration: 0.2),
                                value: audioLevels[index]
                            )
                            .shadow(color: accentColor.opacity(0.2), radius: 3, x: 0, y: 0)
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 120)
    }
    
    // 更新音频电平显示
    private func updateAudioLevels() {
        // 使用更高的采样率，0.03秒更新一次
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            if let recorder = audioRecorder {
                recorder.updateMeters()
                // 使用峰值电平而不是平均电平，让波形更明显
                let normalizedValue = self.normalizedPowerLevel(fromDecibels: recorder.peakPower(forChannel: 0))
                
                // 将新的电平添加到数组末尾，并移除最旧的
                audioLevels.append(normalizedValue)
                if audioLevels.count > 30 {
                    audioLevels.removeFirst()
                }
            } else if let player = audioPlayer, isPlayingBack {
                player.updateMeters()
                // 使用峰值电平而不是平均电平，让波形更明显
                let normalizedValue = self.normalizedPowerLevel(fromDecibels: player.peakPower(forChannel: 0))
                
                audioLevels.append(normalizedValue)
                if audioLevels.count > 30 {
                    audioLevels.removeFirst()
                }
            } else if !isRecording && !isPlayingBack {
                // 逐渐降低所有条形高度
                for i in 0..<audioLevels.count {
                    audioLevels[i] = max(0, audioLevels[i] - 5)
                }
            }
        }
    }
    
    // 将分贝值转换为适合显示的高度
    private func normalizedPowerLevel(fromDecibels decibels: Float) -> CGFloat {
        // 分贝范围通常是 -160 到 0，转换为视觉高度
        let minDb: Float = -50.0  // 最小检测分贝值
        let maxHeight: CGFloat = 120.0 // 最大波形高度
        let minHeight: CGFloat = 5.0   // 最小波形高度
        
        var normalizedValue: CGFloat
        if decibels < minDb {
            normalizedValue = minHeight
        } else {
            // 将分贝值映射到0-1的范围，增强小音量的视觉效果
            let dbRange = abs(minDb)
            let normalizedDb = 1.0 - abs(decibels) / dbRange
            
            // 使用更强的非线性变换，让小声音也能产生明显波形
            normalizedValue = minHeight + (pow(CGFloat(normalizedDb), 1.5) * (maxHeight - minHeight))
        }
        
        return normalizedValue
    }
    
    // 检查麦克风权限
    private func checkPermission() {
        permissionStatus = AVAudioSession.sharedInstance().recordPermission
        if permissionStatus == .denied {
            showingPermissionAlert = true
            alertMessage = "microphonePermissionMessage".localized
        } else if permissionStatus == .undetermined {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if !granted {
                    DispatchQueue.main.async {
                        self.showingPermissionAlert = true
                        self.alertMessage = "microphonePermissionMessage".localized
                    }
                }
            }
        }
        
        // 初始化音频电平数组
        audioLevels = Array(repeating: minHeight, count: 30)
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
        
        // 设置音频会话
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("设置音频会话失败: \(error)")
        }
        
        // 录音设置
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            // 重置状态
            isRecording = true
            recordingTime = 0
            recordingProgress = 0
            
            // 开始监控音频电平
            updateAudioLevels()
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
            // 设置音频会话以支持播放
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            
            // 创建播放器
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            
            // 确保启用音频电平监控
            audioPlayer?.isMeteringEnabled = true
            
            // 设置代理以处理播放结束事件
            audioPlayer?.delegate = AVPlayerObserver(onDidFinishPlaying: {
                DispatchQueue.main.async {
                    self.isPlayingBack = false
                }
            })
            
            // 开始播放
            audioPlayer?.play()
            isPlayingBack = true
            
            // 开始监控播放时的音频电平
            updateAudioLevels()
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
        audioLevels = Array(repeating: minHeight, count: 30)
    }
    
    // 上传录音
    private func uploadRecording() {
        // 这里是模拟上传
        // TODO: 实现实际的API上传功能
        
        // 模拟上传延迟
        withAnimation {
            uploadSuccess = true
        }
    }
    
    private func updateTimer() {
        if isRecording {
            recordingTime += 0.1
            recordingProgress = min(recordingTime / maxRecordingTime, 1.0)
            
            // 达到最大录制时间时自动停止
            if recordingTime >= maxRecordingTime {
                stopRecording()
            }
        }
    }
    
    // 最小高度常量
    private let minHeight: CGFloat = 5.0
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