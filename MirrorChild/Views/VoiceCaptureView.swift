import SwiftUI
import Speech
import Combine

struct VoiceCaptureView: View {
    @StateObject private var voiceCaptureManager = VoiceCaptureManager.shared
    @State private var showingPermissionAlert = false
    @State private var alertMessage = ""
    @State private var showingSettingsAlert = false
    @State private var isBlinking = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    // 存储API响应文本
    @State private var apiResponseText = ""
    // 跟踪页面状态
    @State private var hasAppeared = false
    @State private var stateResetter: AnyCancellable?
    
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
            
            VStack(spacing: 15) {
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
                
                // 分隔视图为两个部分
                GeometryReader { geo in
                    VStack(spacing: 15) {
                        // 用户语音转写区域 - 上半部分
                        VStack {
                            Text("您的语音")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            if voiceCaptureManager.isRecording || !voiceCaptureManager.transcribedText.isEmpty {
                                transcriptionView
                                    .padding()
                                    .frame(height: max(100, geo.size.height / 2 - 40))
                            } else {
                                emptyStateView
                                    .frame(height: max(100, geo.size.height / 2 - 40))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.9))
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(red: 0.7, green: 0.8, blue: 0.7).opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        // AI响应区域 - 下半部分
                        VStack {
                            Text("AI助手")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            apiResponseView
                                .padding()
                                .frame(height: max(100, geo.size.height / 2 - 40))
                        }
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
                    }
                    .padding(.horizontal, 20)
                }
                
                // Control buttons
                HStack(spacing: 60) {
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
                                        .fill(Color.accentColor)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                    }
                }
                .padding(.top, 25)
                .padding(.bottom, 35)
                .padding(.horizontal, 30)
            }
        }
        .onAppear {
            if hasAppeared {
                print("📱 VoiceCaptureView重新出现，强制重置服务")
                resetService()
            }
            
            hasAppeared = true
            
            // 检查麦克风权限
            checkPermissions()
            
            // 设置闪烁效果动画
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isBlinking = true
            }
            
            // 完全重置OpenAI服务，确保状态干净
            resetService()
            
            // 监听TTS播放完成通知，确保UI状态正确更新
            NotificationCenter.default.addObserver(forName: .didFinishPlayingTTS, object: nil, queue: .main) { _ in
                print("📱 VoiceCaptureView收到TTS播放完成通知")
                // 如果需要，可以在这里更新UI状态
            }
            
            // 添加一个定时器，每15秒检查并重置服务状态
            stateResetter = Timer.publish(every: 15, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    print("📱 VoiceCaptureView定时检查服务状态")
                    if !voiceCaptureManager.isRecording {
                        // 如果没有录音，重置服务，避免状态卡住
                        OpenAIService.shared.reset()
                    }
                }
        }
        .onDisappear {
            print("📱 VoiceCaptureView消失")
            cleanupView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .background:
                print("📱 应用进入后台")
                cleanupView()
            case .active:
                if hasAppeared {
                    print("📱 应用恢复前台")
                    resetService()
                }
            default:
                break
            }
        }
        .alert(isPresented: $showingPermissionAlert) {
            if showingSettingsAlert {
                return Alert(
                    title: Text("permissionNeeded".localized),
                    message: Text(alertMessage),
                    primaryButton: .default(Text("openSettings".localized)) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text("cancel".localized))
                )
            } else {
                return Alert(
                    title: Text("permissionDenied".localized),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
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
    
    private var apiResponseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if apiResponseText.isEmpty {
                    Text("AI助手将在您说话后回应...")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                } else {
                    Text(apiResponseText)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                        .lineSpacing(6)
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
                .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.7).opacity(0.5))
            
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
    
    private func checkPermissions() {
        voiceCaptureManager.checkPermissionStatus()
        
        if voiceCaptureManager.permissionStatus == .denied {
            alertMessage = "需要麦克风访问权限才能使用语音功能。请在设置中允许访问麦克风。"
            showingSettingsAlert = true
            showingPermissionAlert = true
        }
    }
    
    // 添加一个方法来重置服务状态
    private func resetService() {
        print("📱 VoiceCaptureView重置OpenAIService")
        
        // 完全重置OpenAI服务
        OpenAIService.shared.reset()
        
        // 重新订阅OpenAI响应
        OpenAIService.shared.onNewResponse = { response in
            self.apiResponseText = response
        }
    }
    
    // 添加一个方法来清理视图资源
    private func cleanupView() {
        // 停止语音录制（如果正在进行）
        if voiceCaptureManager.isRecording {
            voiceCaptureManager.stopRecording()
        }
        
        // 停止自动发送
        OpenAIService.shared.stopAutoSend()
        
        // 取消订阅OpenAI响应
        OpenAIService.shared.onNewResponse = nil
        
        // 取消定时器
        stateResetter?.cancel()
        
        // 移除通知观察者
        NotificationCenter.default.removeObserver(self, name: .didFinishPlayingTTS, object: nil)
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