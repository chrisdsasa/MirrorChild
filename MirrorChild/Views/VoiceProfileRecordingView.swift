import SwiftUI
import AVFoundation

struct VoiceProfileRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var voiceCaptureManager = VoiceCaptureManager.shared
    @State private var recordedSamples = 0
    @State private var recordingProgress: Double = 0
    @State private var isCompleted = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSavedRecordings = false
    @State private var showSaveDialog = false
    @State private var recordingDescription = ""
    @State private var remainingSeconds: Int = 15 // 倒计时15秒
    @State private var countdownTimer: Timer?
    
    // 标准句子示例，用于录制
    private let sampleSentences = [
        "你好，我是你的AI助手",
        "今天天气真不错",
        "请告诉我你想了解什么"
    ]
    
    @State private var currentSentenceIndex = 0
    
    private var currentSentence: String {
        sampleSentences[currentSentenceIndex]
    }
    
    // 点击按钮
    @State private var isSaving = false
    @State private var savedRecordingId: String? = nil
    
    // 格式化录音时间
    private var formattedRecordingTime: String {
        let minutes = Int(voiceCaptureManager.currentRecordingDuration) / 60
        let seconds = Int(voiceCaptureManager.currentRecordingDuration) % 60
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
                
                VStack(spacing: 25) {
                    // 顶部信息区域
                    VStack(spacing: 15) {
                        Text("录制语音配置")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        
                        Text("朗读以下句子，帮助我们捕捉你的声音特点")
                            .font(.system(size: 17, design: .rounded))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // 进度指示器
                    ProgressView(value: recordingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                        .padding(.horizontal, 20)
                    
                    // 当前句子显示
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        VStack(spacing: 15) {
                            Text("朗读句子 \(currentSentenceIndex + 1)/\(sampleSentences.count)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            Text(currentSentence)
                                .font(.system(size: 22, weight: .medium, design: .rounded))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(25)
                    }
                    .frame(height: 180)
                    .padding(.horizontal, 20)
                    
                    // 倒计时和录音时长显示
                    if voiceCaptureManager.isRecording {
                        HStack(spacing: 30) {
                            // 倒计时显示
                            HStack(spacing: 5) {
                                Image(systemName: "timer")
                                    .foregroundColor(.orange)
                                Text("剩余: \(remainingSeconds)秒")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.15))
                            )
                            
                            // 录音时长显示
                            HStack(spacing: 5) {
                                Image(systemName: "waveform")
                                    .foregroundColor(.blue)
                                Text("录制: \(formattedRecordingTime)")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.15))
                            )
                        }
                        .font(.system(size: 14, design: .rounded))
                    }
                    
                    // 录音按钮
                    Button(action: {
                        if voiceCaptureManager.isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(voiceCaptureManager.isRecording ? Color.red : Color.accentColor)
                                .frame(width: 80, height: 80)
                                .shadow(radius: 5)
                            
                            Image(systemName: voiceCaptureManager.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(voiceCaptureManager.permissionStatus != .authorized)
                    .padding(.vertical, 10)
                    
                    // 录音状态提示
                    Text(statusText)
                        .font(.system(size: 17, design: .rounded))
                        .foregroundColor(statusColor)
                        .padding(.bottom, 10)
                    
                    // 按钮区域
                    HStack(spacing: 20) {
                        // 查看已保存录音按钮
                        Button(action: {
                            showSavedRecordings = true
                        }) {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("已保存的录音")
                            }
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                            )
                        }
                        
                        // 完成按钮
                        if isCompleted {
                            Button("完成") {
                                dismiss()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSavedRecordings) {
                SavedRecordingsView()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("权限提示"),
                    message: Text(alertMessage),
                    primaryButton: .default(Text("设置")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
            .alert("保存录音", isPresented: $showSaveDialog) {
                TextField("录音描述", text: $recordingDescription)
                    .font(.system(size: 15))
                
                Button("取消", role: .cancel) {
                    recordingDescription = ""
                }
                
                Button("保存") {
                    // 保存录音
                    isSaving = true
                    
                    // 显示保存中的提示
                    // 因为alert不能显示进度，我们可以在控制台打印
                    print("正在保存录音...")
                    
                    voiceCaptureManager.saveCurrentRecording(description: recordingDescription)
                    
                    // 获取刚保存的录音ID作为最后一个录音
                    if let lastRecording = voiceCaptureManager.savedRecordings.last {
                        savedRecordingId = lastRecording.id
                        print("已保存录音，ID: \(lastRecording.id)")
                    }
                    
                    recordingDescription = ""
                    isSaving = false
                    
                    // 在保存后显示确认
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        alertMessage = "录音已保存！您可以在「已保存的录音」中查看。"
                        showAlert = true
                    }
                }
            } message: {
                VStack {
                    Text("请为这段录音添加描述")
                    
                    if !recordingDescription.isEmpty {
                        Text("当前长度: \(recordingDescription.count) 字符")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                checkPermission()
            }
            .onDisappear {
                // 停止任何正在进行的录音和计时器
                stopRecording()
                countdownTimer?.invalidate()
                countdownTimer = nil
            }
        }
    }
    
    private var statusText: String {
        if voiceCaptureManager.permissionStatus != .authorized {
            return "需要麦克风权限才能录制语音"
        }
        
        if voiceCaptureManager.isRecording {
            return "正在录音..."
        }
        
        if isCompleted {
            return "录音完成！你的语音配置已保存"
        }
        
        return "点击按钮开始录音"
    }
    
    private var statusColor: Color {
        if voiceCaptureManager.permissionStatus != .authorized {
            return .red
        }
        
        if voiceCaptureManager.isRecording {
            return .blue
        }
        
        if isCompleted {
            return .green
        }
        
        return .secondary
    }
    
    private func checkPermission() {
        voiceCaptureManager.checkPermissionStatus()
        
        if voiceCaptureManager.permissionStatus == .notDetermined {
            voiceCaptureManager.requestPermissions { granted, error in
                if !granted {
                    alertMessage = "需要麦克风权限才能使用语音功能。请在设置中允许访问麦克风。"
                    showAlert = true
                }
            }
        } else if voiceCaptureManager.permissionStatus == .denied {
            alertMessage = "麦克风权限已被拒绝。请在设置中允许访问麦克风。"
            showAlert = true
        }
    }
    
    private func startRecording() {
        // 重置倒计时
        remainingSeconds = 15
        
        // 开始录制
        voiceCaptureManager.startRecording { success, error in
            if !success, let error = error {
                print("录音启动失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.alertMessage = "录音启动失败: \(error.localizedDescription)"
                    self.showAlert = true
                }
            }
        }
        
        // 显示录音状态
        print("正在录制语音，等待15秒...")
        
        // 开始倒计时
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                // 倒计时结束，停止录音
                stopRecording()
                timer.invalidate()
            }
        }
        
        // 更新进度动画
        withAnimation(.linear(duration: 15)) {
            recordingProgress = Double(currentSentenceIndex + 1) / Double(sampleSentences.count)
        }
    }
    
    private func stopRecording() {
        print("停止录音")
        
        // 停止倒计时
        countdownTimer?.invalidate()
        countdownTimer = nil
        
        // 停止录音
        voiceCaptureManager.stopRecording()
        
        // 获取当前录音文件URL
        if let fileURL = voiceCaptureManager.voiceFileURL {
            print("录音完成，保存在: \(fileURL.path)")
            
            // 显示保存对话框
            recordingDescription = "朗读句子 \(currentSentenceIndex + 1): \(currentSentence.prefix(20))..."
            showSaveDialog = true
        } else {
            print("录音保存失败")
            alertMessage = "录音保存失败，请重试"
            showAlert = true
            return
        }
        
        // 更新录制状态
        recordedSamples += 1
        
        // 如果还有更多句子需要录制
        if currentSentenceIndex < sampleSentences.count - 1 {
            currentSentenceIndex += 1
        } else {
            // 全部录制完成
            isCompleted = true
            
            // 标记为已完成语音设置
            UserDefaults.standard.set(true, forKey: "hasCompletedVoiceSetup")
        }
    }
}

// MARK: - Supporting Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor)
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct VoiceProfileRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceProfileRecordingView()
    }
} 