//
//  ContentView.swift
//  MirrorChild
//
//  Created by 赵嘉策 on 2025/4/3.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var screenCaptureManager = ScreenCaptureManager.shared
    
    // UI state
    @State private var showingSettings = false
    @State private var messageText = "initialGreeting".localized
    @State private var isMessageAnimating = false
    @State private var isMicrophoneActive = false
    @State private var isScreenSharingActive = false
    @State private var showingScreenCapture = false
    @State private var showingVoiceCapture = false
    @State private var showingBroadcastView = false
    
    // Constants
    let avatarSize: CGFloat = 160
    
    var body: some View {
        ZStack {
            // Subtle gradient background inspired by Japanese dawn (Akebono)
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.97, green: 0.97, blue: 0.98),
                    Color(red: 0.96, green: 0.96, blue: 0.98),
                    Color(red: 0.95, green: 0.95, blue: 0.98)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .onAppear {
                // 确保主视图能立即显示
                print("背景视图已加载")
            }
            
            // Cherry blossom decorative elements (subtle)
            GeometryReader { geometry in
                ZStack {
                    // Top right cherry blossom
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color.pink.opacity(0.3))
                        .position(x: geometry.size.width - 40, y: 60)
                    
                    // Bottom left cherry blossom
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.pink.opacity(0.2))
                        .position(x: 30, y: geometry.size.height - 100)
                }
            }
            
            VStack(spacing: 25) {
                // Top bar with elegant, minimalist design
                HStack {
                    Text("appTitle".localized)
                        .font(.system(size: 40, weight: .bold, design: .default))
                        .tracking(2)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        .padding(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.6))
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            )
                    }
                    .accessibilityLabel("settingsButton".localized)
                    .padding(.trailing)
                }
                .padding(.top, 25)
                
                Spacer()
                
                // Japanese-inspired avatar circle
                ZStack {
                    // Circular background with subtle border
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: avatarSize, height: avatarSize)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.7, green: 0.7, blue: 0.9).opacity(0.4),
                                            Color(red: 0.8, green: 0.7, blue: 0.9).opacity(0.4)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    
                    // Stylized avatar image
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                        .frame(width: avatarSize * 0.45, height: avatarSize * 0.45)
                    
                    // Subtle animation for microphone active state
                    if isMicrophoneActive {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.9, green: 0.5, blue: 0.5).opacity(0.3),
                                        Color(red: 0.9, green: 0.6, blue: 0.7).opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: avatarSize + 15, height: avatarSize + 15)
                            .scaleEffect(isMicrophoneActive ? 1.05 : 1.0)
                            .opacity(isMicrophoneActive ? 0.8 : 0)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true),
                                value: isMicrophoneActive
                            )
                    }
                    
                    // Screen sharing indicator
                    if isScreenSharingActive {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.5, green: 0.7, blue: 0.5).opacity(0.3),
                                        Color(red: 0.6, green: 0.8, blue: 0.6).opacity(0.3)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: avatarSize + 15, height: avatarSize + 15)
                            .scaleEffect(isScreenSharingActive ? 1.05 : 1.0)
                            .opacity(isScreenSharingActive ? 0.8 : 0)
                            .animation(
                                Animation.easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: true),
                                value: isScreenSharingActive
                            )
                    }
                }
                .padding(.bottom, 10)
                
                // Message text with Japanese-inspired paper card design
                Text(messageText)
                    .font(.system(size: 20, weight: .regular))
                    .tracking(0.5)
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.3))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 25)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                    )
                    .padding(.horizontal, 25)
                    .opacity(isMessageAnimating ? 1 : 0.9)
                    .onAppear {
                        isMessageAnimating = true
                    }
                
                Spacer()
                
                // Subtle instruction text
                Text("selectPrompt".localized)
                    .font(.system(size: 16, weight: .light))
                    .tracking(1)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                    .padding(.bottom, 5)
                
                // Control buttons - Japanese-inspired
                HStack(spacing: 60) {
                    // Voice button
                    Button(action: toggleMicrophone) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(red: 0.6, green: 0.6, blue: 0.7).opacity(0.3), lineWidth: 1.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 30, weight: .light))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                            }
                            
                            Text("voiceButtonLabel".localized)
                                .font(.system(size: 17, weight: .light))
                                .tracking(1)
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        }
                    }
                    .accessibilityLabel("voiceButtonA11y".localized)
                    .accessibilityHint("voiceButtonA11yHint".localized)
                    
                    // Screen button
                    Button(action: toggleScreenSharing) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(red: 0.6, green: 0.6, blue: 0.7).opacity(0.3), lineWidth: 1.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                
                                Image(systemName: "rectangle.on.rectangle")
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                            }
                            
                            Text("screenButtonLabel".localized)
                                .font(.system(size: 17, weight: .light))
                                .tracking(1)
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        }
                    }
                    .accessibilityLabel("screenButtonA11y".localized)
                    .accessibilityHint("screenButtonA11yHint".localized)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            // 确保尽快进入主界面而不是停留在启动屏幕
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            
            // 强制更新主线程UI
            DispatchQueue.main.async {
                isMessageAnimating = true
            }
        }
        .sheet(isPresented: $showingSettings) {
            JapaneseStyleSettingsView()
        }
        .sheet(isPresented: $showingBroadcastView) {
            BroadcastScreenView()
                .onDisappear {
                    isScreenSharingActive = BroadcastManager.shared.isBroadcasting
                }
        }
        .sheet(isPresented: $showingVoiceCapture) {
            VoiceCaptureView()
        }
    }
    
    // MARK: - User Actions
    
    private var isRunningInPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private func toggleMicrophone() {
        print("切换麦克风按钮被点击")
        
        // 强制更新UI状态
        withAnimation(.easeInOut(duration: 0.3)) {
            isMicrophoneActive.toggle()
        }
        
        if isMicrophoneActive {
            print("激活麦克风")
            messageText = "listeningMessage".localized
            showingVoiceCapture = true
            
            // 在预览模式下简单切换状态，不尝试访问实际API
            if isRunningInPreview {
                print("预览模式：跳过实际录音")
                return
            }
            
            print("尝试启动录音...")
            // 当激活麦克风时，实际启动录音
            VoiceCaptureManager.shared.startRecording { success, error in
                if success {
                    print("录音成功启动")
                    // 确保在主线程更新UI
                    DispatchQueue.main.async {
                        // 确保状态已更新
                        self.isMicrophoneActive = true
                    }
                } else if let error = error {
                    print("无法启动录音: \(error.localizedDescription)")
                    // 失败时重置状态
                    DispatchQueue.main.async {
                        withAnimation {
                            self.isMicrophoneActive = false
                            self.showingVoiceCapture = false
                            self.messageText = "voiceErrorMessage".localized
                        }
                    }
                }
            }
        } else {
            print("停用麦克风")
            messageText = "voiceOffMessage".localized
            showingVoiceCapture = false
            
            // 在预览模式下，跳过实际API调用
            if !isRunningInPreview {
                print("停止录音")
                VoiceCaptureManager.shared.stopRecording()
            }
        }
    }
    
    private func toggleScreenSharing() {
        showingBroadcastView = true
        messageText = "screenOnMessage".localized
    }
}

struct JapaneseStyleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedVoice = "shimmer"
    @State private var personalityTraits: [String] = ["calmTrait".localized, "kindTrait".localized, "helpfulTrait".localized]
    @State private var showingVoiceProfilePage = false
    @State private var showingLanguageSelectionPage = false
    @ObservedObject private var voiceCaptureManager = VoiceCaptureManager.shared
    
    let availableVoices = ["shimmer", "echo", "fable", "onyx", "nova"]

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Voice language selection
                        VStack(alignment: .leading, spacing: 15) {
                            Text("voiceLanguageTitle".localized)
                                .font(.system(size: 18, weight: .medium))
                                .tracking(1)
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                .padding(.leading, 10)
                            
                            Button(action: {
                                showingLanguageSelectionPage = true
                            }) {
                                HStack {
                                    Text(voiceCaptureManager.currentLanguage.localizedName)
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.7))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.8))
                                }
                                .padding(15)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                                )
                            }
                            .padding(.horizontal, 10)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 15)
                        
                        // Voice selection
                        VStack(alignment: .leading, spacing: 15) {
                            Text("voiceTypeLabel".localized)
                                .font(.system(size: 18, weight: .medium))
                                .tracking(1)
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                .padding(.leading, 10)
                            
                            Picker("Voice Type", selection: $selectedVoice) {
                                ForEach(availableVoices, id: \.self) { voice in
                                    Text(voice.capitalized)
                                        .font(.system(size: 18))
                                        .tag(voice)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 100)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                            )
                            .padding(.horizontal, 10)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 15)
                        
                        // Voice Profile Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("voiceProfileLabel".localized)
                                .font(.system(size: 18, weight: .medium))
                                .tracking(1)
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                .padding(.leading, 10)
                            
                            Button(action: {
                                showingVoiceProfilePage = true
                            }) {
                                HStack {
                                    Text("customizeVoiceButton".localized)
                                        .font(.system(size: 18, weight: .light))
                                        .tracking(0.5)
                                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.6))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 16, weight: .light))
                                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                                }
                                .padding(.vertical, 15)
                                .padding(.horizontal, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                                )
                            }
                            .padding(.horizontal, 10)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 15)
                        
                        // Assistant traits
                        VStack(alignment: .leading, spacing: 15) {
                            Text("assistantPersonalityLabel".localized)
                                .font(.system(size: 18, weight: .medium))
                                .tracking(1)
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                .padding(.leading, 10)
                            
                            VStack(spacing: 0) {
                                ForEach(personalityTraits, id: \.self) { trait in
                                    HStack {
                                        Text(trait)
                                            .font(.system(size: 18, weight: .light))
                                            .tracking(0.5)
                                        Spacer()
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 18, weight: .light))
                                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 15)
                                    
                                    if trait != personalityTraits.last {
                                        Divider()
                                            .background(Color(red: 0.9, green: 0.9, blue: 0.95))
                                            .padding(.leading, 15)
                                    }
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                            )
                            .padding(.horizontal, 10)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 15)
                        
                        // About section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("aboutAppLabel".localized)
                                .font(.system(size: 18, weight: .medium))
                                .tracking(1)
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                .padding(.leading, 10)
                            
                            HStack {
                                Text("versionInfo".localized)
                                    .font(.system(size: 16, weight: .light))
                                    .tracking(0.5)
                                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                                Spacer()
                            }
                            .padding(15)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                            )
                            .padding(.horizontal, 10)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 15)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("settingsTitle".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            }
            .sheet(isPresented: $showingVoiceProfilePage) {
                VoiceProfileView()
            }
            .sheet(isPresented: $showingLanguageSelectionPage) {
                VoiceLanguageSelectionView()
            }
        }
    }
}

struct VoiceProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var recordedSamples: [CGFloat] = []
    @State private var uploadProgress: CGFloat = 0
    @State private var isUploading = false
    @State private var recordings: [Recording] = [
        Recording(name: "Sample 1", duration: "0:12"),
        Recording(name: "Sample 2", duration: "0:27")
    ]
    
    struct Recording: Identifiable {
        let id = UUID()
        let name: String
        let duration: String
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        instructionsView
                        recordingVisualizerView
                        uploadButtonView
                        
                        // Divider
                        Rectangle()
                            .fill(Color(red: 0.8, green: 0.8, blue: 0.9).opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        
                        savedRecordingsView
                    }
                }
            }
            .navigationTitle("voiceProfileTitle".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            }
        }
    }
    
    // MARK: - Subviews
    
    private var instructionsView: some View {
        Text("voiceProfileInstructions".localized)
            .font(.system(size: 17, weight: .light))
            .tracking(0.5)
            .lineSpacing(5)
            .multilineTextAlignment(.center)
            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
            .padding(.horizontal, 20)
            .padding(.top, 10)
    }
    
    private var recordingVisualizerView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                .frame(height: 180)
            
            if recordedSamples.isEmpty {
                placeholderWaveformView
            } else {
                actualWaveformView
            }
            
            recordButtonView
        }
        .padding(.horizontal, 20)
    }
    
    private var placeholderWaveformView: some View {
        HStack(spacing: 4) {
            ForEach(0..<30, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.7, green: 0.7, blue: 0.8).opacity(0.3))
                    .frame(width: 3, height: CGFloat.random(in: 5...40))
            }
        }
    }
    
    private var actualWaveformView: some View {
        HStack(spacing: 4) {
            ForEach(recordedSamples.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.5, green: 0.5, blue: 0.8))
                    .frame(width: 3, height: recordedSamples[index])
            }
        }
    }
    
    private var recordButtonView: some View {
        VStack {
            Spacer()
            
            recordButton
                .padding(.bottom, 16)
        }
    }
    
    private var recordButton: some View {
        Button(action: {
            isRecording.toggle()
            if isRecording {
                startRecording()
            } else {
                stopRecording()
            }
        }) {
            Circle()
                .fill(isRecording ? Color.red.opacity(0.8) : Color(red: 0.5, green: 0.5, blue: 0.8))
                .frame(width: 56, height: 56)
                .overlay(recordButtonOverlay)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    @ViewBuilder
    private var recordButtonOverlay: some View {
        if isRecording {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white)
                .frame(width: 20, height: 20)
        } else {
            Circle()
                .fill(Color.white)
                .frame(width: 26, height: 26)
        }
    }
    
    private var uploadButtonView: some View {
        VStack {
            Button(action: {
                uploadVoiceProfile()
            }) {
                HStack {
                    Text("uploadVoiceProfile".localized)
                        .font(.system(size: 17, weight: .medium))
                        .tracking(1)
                    
                    if isUploading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.5, green: 0.5, blue: 0.8))
                        .opacity(recordedSamples.isEmpty ? 0.5 : 1)
                )
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            }
            .disabled(recordedSamples.isEmpty || isUploading)
            
            if isUploading {
                ProgressView(value: uploadProgress, total: 1.0)
                    .accentColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
        }
    }
    
    private var savedRecordingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("savedRecordings".localized)
                .font(.system(size: 18, weight: .medium))
                .tracking(0.5)
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                .padding(.horizontal, 20)
            
            ForEach(recordings) { recording in
                recordingRowView(for: recording)
            }
        }
        .padding(.bottom, 20)
    }
    
    private func recordingRowView(for recording: Recording) -> some View {
        HStack {
            Image(systemName: "waveform")
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
            
            Text(recording.name)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
            
            Spacer()
            
            Text(recording.duration)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
            
            Button(action: {
                // Play recording action
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Functions
    
    private func startRecording() {
        // This would normally start actual audio recording
        // For UI demo, we'll just generate random waveform data
        recordedSamples = []
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if isRecording {
                if recordedSamples.count > 40 {
                    recordedSamples.removeFirst()
                }
                recordedSamples.append(CGFloat.random(in: 5...70))
            }
        }
        timer.fire()
    }
    
    private func stopRecording() {
        // Would normally stop recording and process audio
    }
    
    private func uploadVoiceProfile() {
        isUploading = true
        uploadProgress = 0
        
        // Simulate upload progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if uploadProgress < 1.0 {
                uploadProgress += 0.05
            } else {
                isUploading = false
                timer.invalidate()
                
                // Add to recordings
                let newRecording = Recording(name: "Recording \(recordings.count + 1)", duration: "0:18")
                recordings.insert(newRecording, at: 0)
            }
        }
        timer.fire()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // 使用一个基本的环境包装ContentView，确保不会触发录音功能
        ContentView()
            .environment(\.isPreview, true)
    }
}
