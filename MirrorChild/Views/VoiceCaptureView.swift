import SwiftUI
import Speech

struct VoiceCaptureView: View {
    @StateObject private var voiceCaptureManager = VoiceCaptureManager.shared
    @State private var showingPermissionAlert = false
    @State private var alertMessage = ""
    @State private var showingSettingsAlert = false
    @State private var isBlinking = false
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
                    Spacer()
                    Text("voiceProfileTitle".localized)
                        .font(.appFont(size: 24, weight: .black))
                        .tracking(1)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                // Status indicator
                HStack {
                    Circle()
                        .fill(voiceCaptureManager.isRecording ? 
                              Color(red: 0.2, green: 0.8, blue: 0.2) : Color(red: 0.8, green: 0.4, blue: 0.4))
                        .frame(width: 12, height: 12)
                        .opacity(voiceCaptureManager.isRecording ? (isBlinking ? 1.0 : 0.5) : 1.0)
                    
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
                HStack(spacing: 30) {
                    if voiceCaptureManager.isRecording {
                        // Stop button
                        Button(action: stopRecording) {
                            Text("stopListening".localized)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 30)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.8, green: 0.4, blue: 0.4))
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                    } else {
                        // Start button
                        Button(action: startRecording) {
                            Text("startListening".localized)
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
        .onAppear {
            // 创建定时器，每秒切换一次闪烁状态
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    isBlinking.toggle()
                }
            }
            // 将timer存储到RunLoop中，确保即使在滚动时也能继续工作
            RunLoop.current.add(timer, forMode: .common)
            // 保存timer引用以便在视图消失时清理
            TimerManager.shared.voiceBlinkTimer = timer
        }
        .onDisappear {
            // 清理定时器
            TimerManager.shared.voiceBlinkTimer?.invalidate()
            TimerManager.shared.voiceBlinkTimer = nil
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
        .preferredColorScheme(.light)
    }
    
    private var transcriptionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // 背景录音指示器
                if UIApplication.shared.applicationState == .background && voiceCaptureManager.isRecording {
                    Text("(后台录音中...)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.orange)
                        .padding(.bottom, 5)
                }
                
                // Preview mode shows simulated text
                if isRunningInPreview && voiceCaptureManager.isRecording {
                    Text("This is simulated speech recognition text in preview mode. Actual speech-to-text content will be shown on real devices.")
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
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.8).opacity(0.5))
            
            if voiceCaptureManager.permissionStatus == .denied {
                Text("permissionDeniedMessage".localized)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("tapToStartListening".localized)
                    .font(.system(size: 18, weight: .medium))
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

// 用于管理全局计时器，避免内存泄漏
class TimerManager {
    static let shared = TimerManager()
    
    var voiceBlinkTimer: Timer?
    
    private init() {}
    
    deinit {
        voiceBlinkTimer?.invalidate()
    }
} 