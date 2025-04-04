import SwiftUI
import Speech

struct VoiceCaptureView: View {
    @StateObject private var voiceCaptureManager = VoiceCaptureManager.shared
    @State private var showingPermissionAlert = false
    @State private var alertMessage = ""
    @State private var showingSettingsAlert = false
    
    // 检测是否在预览模式下运行
    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Title
                Text("语音识别")
                    .font(.system(size: 22, weight: .medium))
                    .tracking(1)
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    .padding(.top, 20)
                
                // 标点符号开关
                Toggle(isOn: $voiceCaptureManager.enablePunctuation) {
                    Text("自动添加标点符号")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
                }
                .padding(.horizontal, 25)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                .padding(.horizontal, 20)
                .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.5, green: 0.5, blue: 0.8)))
                
                // Status indicator
                HStack {
                    Circle()
                        .fill(voiceCaptureManager.isRecording ? 
                              Color.green.opacity(0.8) : Color.red.opacity(0.5))
                        .frame(width: 12, height: 12)
                    
                    Text(voiceCaptureManager.isRecording ? 
                         "正在聆听" : "未在录音")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                
                // Transcription area
                VStack {
                    if voiceCaptureManager.isRecording || !voiceCaptureManager.transcribedText.isEmpty {
                        transcriptionView
                            .padding()
                    } else {
                        emptyStateView
                    }
                }
                .frame(height: 400)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 20)
                
                // Control buttons
                HStack(spacing: 30) {
                    if voiceCaptureManager.isRecording {
                        // Stop button
                        Button(action: stopRecording) {
                            Text("停止聆听")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 30)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.8))
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                    } else {
                        // Start button
                        Button(action: startRecording) {
                            Text("开始聆听")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 30)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.5, green: 0.5, blue: 0.8))
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                    }
                }
                .padding(.top, 20)
                
                // Open settings button (if permission denied)
                if voiceCaptureManager.permissionStatus == .denied {
                    Button(action: {
                        showingSettingsAlert = true
                    }) {
                        Text("打开设置")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                            .padding(.top, 10)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .alert(isPresented: $showingPermissionAlert) {
            Alert(
                title: Text("需要权限"),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .alert(isPresented: $showingSettingsAlert) {
            Alert(
                title: Text("启用麦克风和语音识别"),
                message: Text("要使用语音识别功能，请在设备设置中启用麦克风和语音识别权限。"),
                primaryButton: .default(Text("打开设置")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    private var transcriptionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if voiceCaptureManager.isRecording {
                    HStack {
                        Text("正在聆听...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.5))
                        
                        // Animated dots
                        HStack(spacing: 3) {
                            ForEach(0..<3) { index in
                                Circle()
                                    .fill(Color(red: 0.4, green: 0.6, blue: 0.5))
                                    .frame(width: 5, height: 5)
                                    .opacity(0.5)
                                    .animation(
                                        Animation.easeInOut(duration: 0.5)
                                            .repeatForever()
                                            .delay(0.2 * Double(index)),
                                        value: voiceCaptureManager.isRecording
                                    )
                            }
                        }
                    }
                    .padding(.bottom, 5)
                }
                
                // 预览模式下显示模拟文本
                if isRunningInPreview && voiceCaptureManager.isRecording {
                    Text("这是在预览模式下的模拟语音识别文本。实际设备上会显示真实的语音转文字内容。")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.3))
                        .lineSpacing(5)
                } else {
                    Text(voiceCaptureManager.transcribedText)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.3))
                        .lineSpacing(5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.8).opacity(0.5))
            
            if voiceCaptureManager.permissionStatus == .denied {
                Text("需要麦克风和语音识别权限。请在设置中启用。")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("点击下方按钮开始语音识别")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    private func startRecording() {
        // 在预览模式下，简化行为
        if isRunningInPreview {
            voiceCaptureManager.isRecording = true
            voiceCaptureManager.transcribedText = "这是预览模式下的模拟录音文本。在实际设备上，这里会显示真实的语音识别结果。"
            return
        }
        
        // 当用户点击按钮时才请求权限
        voiceCaptureManager.startRecording { success, error in
            if !success, let error = error {
                self.alertMessage = error.localizedDescription
                self.showingPermissionAlert = true
            }
        }
    }
    
    private func stopRecording() {
        if isRunningInPreview {
            voiceCaptureManager.isRecording = false
            return
        }
        
        voiceCaptureManager.stopRecording()
    }
}

// 为了在预览模式下显示而添加的预览提供者
struct VoiceCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceCaptureView()
    }
} 