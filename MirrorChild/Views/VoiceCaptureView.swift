import SwiftUI
import Speech

struct VoiceCaptureView: View {
    @StateObject private var voiceCaptureManager = VoiceCaptureManager.shared
    @State private var showingPermissionAlert = false
    @State private var alertMessage = ""
    @State private var showingSettingsAlert = false
    @Environment(\.dismiss) private var dismiss
    
    // Check if running in preview mode
    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.97, green: 0.97, blue: 0.98),
                    Color(red: 0.96, green: 0.96, blue: 0.98),
                    Color(red: 0.95, green: 0.95, blue: 0.98)
                ]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            // Cherry blossom decorative elements (subtle)
            GeometryReader { geometry in
                ZStack {
                    // Top right cherry blossom
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.pink.opacity(0.2))
                        .position(x: geometry.size.width - 40, y: 60)
                    
                    // Bottom left cherry blossom
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.pink.opacity(0.15))
                        .position(x: 30, y: geometry.size.height - 100)
                }
            }
            
            VStack(spacing: 20) {
                // Title with elegant, minimalist design
                HStack {
                    Text("voiceProfileTitle".localized)
                        .font(.system(size: 24, weight: .medium))
                        .tracking(1)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    
                    Spacer()
                    
                    Button(action: {
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
                              Color(red: 0.4, green: 0.6, blue: 0.5) : Color(red: 0.8, green: 0.4, blue: 0.4))
                        .frame(width: 12, height: 12)
                    
                    Text(voiceCaptureManager.isRecording ? 
                         "listeningMessage".localized : "voiceOffMessage".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.9))
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
                        .fill(Color.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 0.7, green: 0.7, blue: 0.9).opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                
                // Control buttons
                mainControlButton
                
                // Open settings button (if permission denied)
                if voiceCaptureManager.permissionStatus == .denied {
                    Button(action: {
                        showingSettingsAlert = true
                    }) {
                        Text("openSettings".localized)
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
                title: Text("permissionRequired".localized),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingSettingsAlert) {
            Alert(
                title: Text("openSettingsTitle".localized),
                message: Text("openSettingsMessage".localized),
                primaryButton: .default(Text("openSettingsButton".localized)) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // 转录视图
    private var transcriptionView: some View {
        VStack(spacing: 15) {
            // 实时波形显示
            if voiceCaptureManager.isRecording {
                LiveWaveformView()
                    .frame(height: 60)
                    .padding(.horizontal)
                    .padding(.top, 10)
            }
            
            ScrollView {
                Text(voiceCaptureManager.transcribedText)
                    .font(.system(size: 24))
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
                    .padding()
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
        )
    }
    
    // 主控制按钮
    private var mainControlButton: some View {
        Button(action: {
            if voiceCaptureManager.isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(
                        voiceCaptureManager.isRecording ? 
                        Color(red: 0.8, green: 0.4, blue: 0.4) : 
                        Color(red: 0.5, green: 0.5, blue: 0.8)
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                
                Image(systemName: voiceCaptureManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }
        }
        .padding(.bottom, 30)
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 80))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.8).opacity(0.5))
            
            if voiceCaptureManager.permissionStatus == .denied {
                Text("permissionDeniedMessage".localized)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("tapToStartListening".localized)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    private func startRecording() {
        // Simplified behavior in preview mode
        if isRunningInPreview {
            voiceCaptureManager.isRecording = true
            voiceCaptureManager.transcribedText = "This is simulated recording text in preview mode. On real devices, this would show actual speech recognition results."
            return
        }
        
        // Request permissions when user taps the button
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

// Preview provider
struct VoiceCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceCaptureView()
    }
}

// 实时波形视图
struct LiveWaveformView: View {
    @StateObject private var voiceCaptureManager = VoiceCaptureManager.shared
    @State private var waveform: [CGFloat] = Array(repeating: 10, count: 40)
    private let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    
    // 彩色渐变效果
    private let waveGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.4, green: 0.5, blue: 0.9),
            Color(red: 0.5, green: 0.5, blue: 0.8),
            Color(red: 0.6, green: 0.5, blue: 0.9)
        ]), 
        startPoint: .leading, 
        endPoint: .trailing
    )
    
    var body: some View {
        ZStack {
            // 背景网格线
            VStack(spacing: 20) {
                ForEach(0..<3) { _ in
                    Rectangle()
                        .fill(Color(red: 0.7, green: 0.7, blue: 0.9).opacity(0.2))
                        .frame(height: 1)
                }
            }
            .frame(maxHeight: .infinity)
            
            // 波形
            HStack(spacing: 2) {
                ForEach(0..<waveform.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(waveGradient)
                        .frame(width: 3, height: waveform[index])
                        .animation(.easeInOut(duration: 0.2), value: waveform[index])
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onReceive(timer) { _ in
            // 更新波形, 左移数组并添加新值
            var newWaveform = Array(waveform.dropFirst())
            
            // 将音频电平转换为视觉高度
            let height = normalizedAudioLevel(from: voiceCaptureManager.currentAudioLevel)
            newWaveform.append(height)
            
            waveform = newWaveform
        }
    }
    
    // 将音频电平转换为波形高度
    private func normalizedAudioLevel(from level: Float) -> CGFloat {
        // 音频电平通常为负分贝值，0分贝是最大值
        let minDb: Float = -50.0
        let maxDb: Float = -10.0
        let minHeight: CGFloat = 5.0
        let maxHeight: CGFloat = 60.0
        
        // 确保电平在有效范围内
        let clampedLevel = max(min(level, maxDb), minDb)
        
        // 将分贝值归一化到0-1的范围
        let normalizedLevel = (clampedLevel - minDb) / (maxDb - minDb)
        
        // 使用更强的非线性映射使效果更明显
        let height = minHeight + (pow(CGFloat(normalizedLevel), 0.7) * (maxHeight - minHeight))
        
        return height
    }
} 