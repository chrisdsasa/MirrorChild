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
    @State private var player: AVAudioPlayer?
    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var alertMessage = ""
    @State private var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    
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
            Color(red: 0.97, green: 0.97, blue: 0.98)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // 标题
                Text("声音录制")
                    .font(.system(size: 32, weight: .medium))
                    .tracking(2)
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
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
                            .fill(Color(red: 0.9, green: 0.9, blue: 0.95))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isRecordingComplete ? 
                                  Color(red: 0.4, green: 0.7, blue: 0.5) : 
                                  Color(red: 0.5, green: 0.5, blue: 0.8))
                            .frame(width: max(CGFloat(progressPercentage) * UIScreen.main.bounds.width - 40, 0), 
                                   height: 8)
                    }
                    
                    // 时间文本
                    Text(String(format: "%.0f 秒", min(recordingTime, 30)))
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
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
                            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.7))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
        .onAppear {
            checkPermission()
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
                                    .fill(Color(red: 0.5, green: 0.7, blue: 0.5))
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
                                    .fill(Color(red: 0.7, green: 0.5, blue: 0.5))
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
                            .fill(isRecording ? Color(red: 0.8, green: 0.4, blue: 0.4) : Color(red: 0.5, green: 0.5, blue: 0.8))
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
                            .fill(Color(red: 0.4, green: 0.6, blue: 0.8))
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
    
    // 波形视图 - 模拟音频波形
    private var waveformView: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<Int(geometry.size.width / 8), id: \.self) { index in
                    Capsule()
                        .fill(Color(red: 0.5, green: 0.5, blue: 0.8))
                        .frame(width: 6, height: getWaveHeight(at: index, width: geometry.size.width))
                        .animation(
                            Animation.easeInOut(duration: 0.3)
                                .repeatForever()
                                .delay(Double(index) * 0.05),
                            value: isRecording
                        )
                }
            }
            .frame(height: 120)
        }
        .frame(height: 120)
    }
    
    // 生成波形高度
    private func getWaveHeight(at index: Int, width: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = 20
        let maxAdditionalHeight: CGFloat = 100
        let seed = Date().timeIntervalSince1970 + Double(index)
        let randomFactor = sin(seed * 2) * 0.5 + 0.5 // 0.0-1.0
        
        return baseHeight + randomFactor * maxAdditionalHeight
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