import SwiftUI
import AVFoundation

struct VoiceCloneView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceCaptureManager = VoiceCaptureManager.shared
    
    // UI状态
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showHelp = false
    
    // 格式化录音时间
    private var formattedTime: String {
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
                
                VStack(spacing: 30) {
                    // 顶部说明
                    infoCard
                    
                    Spacer()
                    
                    // 录音状态指示
                    if voiceCaptureManager.isRecording {
                        recordingAnimation
                    } else if case .uploading = voiceCaptureManager.cloneStatus {
                        uploadingAnimation
                    } else if case .success = voiceCaptureManager.cloneStatus {
                        successView
                    } else if voiceCaptureManager.voiceFileURL != nil {
                        readyToUploadView
                    } else {
                        readyToRecordView
                    }
                    
                    Spacer()
                    
                    // 控制按钮
                    controlButtons
                    
                    // 时间显示
                    if voiceCaptureManager.isRecording {
                        Text(formattedTime)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(.top, 10)
                    }
                }
                .padding()
            }
            .navigationTitle("自定义语音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showHelp = true
                    }) {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("好的"))
                )
            }
            .sheet(isPresented: $showHelp) {
                helpView
            }
            .onAppear {
                checkPermission()
            }
        }
    }
    
    // MARK: - 组件视图
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("创建你的个性化声音")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("请录制一段至少30秒的清晰语音。录制完成后，我们会将其上传到服务器进行声音克隆。这个过程可能需要几分钟时间。")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var recordingAnimation: some View {
        VStack(spacing: 25) {
            Image(systemName: "waveform")
                .font(.system(size: 80))
                .foregroundColor(.red)
                .symbolEffect(.variableColor.iterative, options: .repeating)
            
            Text("正在录音...")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("请清晰地朗读一段内容")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
    
    private var uploadingAnimation: some View {
        VStack(spacing: 25) {
            ProgressView()
                .scaleEffect(2)
                .padding()
            
            Text("正在上传并处理语音...")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("这可能需要几分钟时间")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
    
    private var successView: some View {
        VStack(spacing: 25) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("声音克隆成功！")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            if let voiceId = voiceCaptureManager.cloneStatus.voiceId {
                Text("声音ID: \(voiceId)")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Button("完成") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 20)
        }
    }
    
    private var readyToUploadView: some View {
        VStack(spacing: 25) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("录音完成")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("点击上传按钮将声音上传到服务器进行克隆")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var readyToRecordView: some View {
        VStack(spacing: 25) {
            Image(systemName: "mic.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            Text("准备录音")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("点击下方按钮开始录制你的声音")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.secondary)
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 30) {
            if voiceCaptureManager.isRecording {
                // 仅显示停止按钮
                Button(action: {
                    _ = voiceCaptureManager.stopVoiceFileRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 70, height: 70)
                            .shadow(radius: 5)
                        
                        Image(systemName: "stop.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
            } else if case .uploading = voiceCaptureManager.cloneStatus {
                // 上传中，不显示按钮
                EmptyView()
            } else if case .success = voiceCaptureManager.cloneStatus {
                // 成功，不显示按钮
                EmptyView()
            } else if voiceCaptureManager.voiceFileURL != nil {
                // 显示重录和上传按钮
                Button(action: {
                    voiceCaptureManager.resetVoiceCloneStatus()
                }) {
                    VStack {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 24))
                                .foregroundColor(.primary)
                        }
                        
                        Text("重录")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                }
                
                Button(action: {
                    voiceCaptureManager.uploadVoiceToCloneAPI()
                }) {
                    VStack {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 60, height: 60)
                                .shadow(radius: 5)
                            
                            Image(systemName: "icloud.and.arrow.up.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        
                        Text("上传")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                }
            } else {
                // 显示录音按钮
                Button(action: {
                    voiceCaptureManager.startVoiceFileRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 70, height: 70)
                            .shadow(radius: 5)
                        
                        Image(systemName: "mic.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
                .disabled(voiceCaptureManager.permissionStatus != .authorized)
            }
        }
    }
    
    private var helpView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("如何获得最佳效果")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        
                        Text("1. 在安静的环境中录音")
                            .font(.headline)
                        Text("确保录音环境没有背景噪音，如风扇声、交通声或其他人说话的声音。")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("2. 保持适当距离")
                            .font(.headline)
                        Text("将手机或麦克风保持在距离嘴部约15-20厘米的位置，不要太近或太远。")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("3. 说话清晰自然")
                            .font(.headline)
                        Text("以自然的语速和音量朗读，不要刻意改变声音风格。")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Group {
                        Text("4. 录制足够长度")
                            .font(.headline)
                        Text("至少录制30秒的声音样本，更长的样本有助于提高克隆效果。")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("5. 多样化的内容")
                            .font(.headline)
                        Text("尝试朗读包含不同情感和语调的内容，这有助于系统捕捉你声音的多样性。")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Text("关于隐私")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.top, 10)
                        
                        Text("你的声音样本将被上传到我们的服务器进行处理。我们会保护你的隐私，不会将样本用于其他目的。你可以随时删除你的声音样本。")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("语音克隆帮助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showHelp = false
                    }
                }
            }
        }
    }
    
    // MARK: - 功能方法
    
    private func checkPermission() {
        voiceCaptureManager.checkPermissionStatus()
        
        if voiceCaptureManager.permissionStatus == .notDetermined {
            voiceCaptureManager.requestPermissions { granted in
                if !granted {
                    showPermissionAlert()
                }
            }
        } else if voiceCaptureManager.permissionStatus == .denied {
            showPermissionAlert()
        }
    }
    
    private func showPermissionAlert() {
        alertTitle = "需要麦克风权限"
        alertMessage = "请在设置中允许应用访问麦克风，以便录制你的声音。"
        showAlert = true
    }
}

// MARK: - 预览

struct VoiceCloneView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceCloneView()
    }
} 