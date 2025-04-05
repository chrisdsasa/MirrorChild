//
//  ContentView.swift
//  MirrorChild
//
//  Created by 赵嘉策 on 2025/4/3.
//

import SwiftUI
import CoreData
import AVFoundation
// 导入VoiceProfileView模块以获取通知支持
import Combine

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var screenCaptureManager = ScreenCaptureManager.shared
    @ObservedObject private var voiceCaptureManager = VoiceCaptureManager.shared
    
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
                    
                    // Fixed position avatar in the center
                    ZStack {
                        // Animation indicators (positioned behind the main avatar)
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
                        
                        // Core avatar components (these stay fixed in position)
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
                                .frame(width: 70, height: 70)
                                .offset(y: -6)
                        }
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.32)
                }
            }
            
            VStack(spacing: 25) {
                // Top bar with elegant, minimalist design
                HStack {
                    ZStack {
                        // Multiple shadow layers for ultra-bold effect
                        Text("appTitle".localized)
                            .font(.custom("PingFang SC", size: 40).weight(.black))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            .offset(x: 0.7, y: 0.7)
                        
                        Text("appTitle".localized)
                            .font(.custom("PingFang SC", size: 40).weight(.black))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            .offset(x: 0.7, y: 0)
                        
                        Text("appTitle".localized)
                            .font(.custom("PingFang SC", size: 40).weight(.black))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            .offset(x: 0, y: 0.7)
                            
                        Text("appTitle".localized)
                            .font(.custom("PingFang SC", size: 40).weight(.black))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            .offset(x: -0.7, y: 0)
                            
                        Text("appTitle".localized)
                            .font(.custom("PingFang SC", size: 40).weight(.black))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            .offset(x: 0, y: -0.7)
                            
                        // Main text (center)
                        Text("appTitle".localized)
                            .font(.custom("PingFang SC", size: 40).weight(.black))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Button {
                        print("Settings button tapped")
                        showingSettings = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.6))
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                .frame(width: 52, height: 52)
                            
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                        }
                    }
                    .accessibilityLabel("settingsButton".localized)
                    .padding(.trailing)
                }
                .padding(.top, 25)
                
                Spacer()
                
                // Empty space to account for the fixed position avatar
                Color.clear
                    .frame(width: 1, height: avatarSize + 30)
                
                // Message text with Japanese-inspired paper card design
                Text(messageText)
                    .font(.appFont(size: 20))
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
                
                // Control buttons - Japanese-inspired
                HStack(spacing: 60) {
                    // Voice button
                    Button(action: toggleMicrophone) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(isMicrophoneActive ? 
                                        Color(red: 0.5, green: 0.5, blue: 0.8).opacity(0.2) : 
                                        Color(red: 0.95, green: 0.95, blue: 0.98))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(red: 0.6, green: 0.6, blue: 0.7).opacity(0.3), lineWidth: 1.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundColor(isMicrophoneActive ? 
                                                   Color(red: 0.4, green: 0.4, blue: 0.7) : 
                                                   Color(red: 0.5, green: 0.5, blue: 0.7))
                            }
                            
                            Text("voiceButtonLabel".localized)
                                .font(.system(size: 20, weight: .bold))
                                .tracking(1)
                                .foregroundColor(isMicrophoneActive ? 
                                               Color(red: 0.4, green: 0.4, blue: 0.6) : 
                                               Color(red: 0.3, green: 0.3, blue: 0.35))
                        }
                    }
                    .accessibilityLabel("voiceButtonA11y".localized)
                    .accessibilityHint("voiceButtonA11yHint".localized)
                    
                    // Screen button
                    Button(action: toggleScreenSharing) {
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(isScreenSharingActive ? 
                                        Color(red: 0.5, green: 0.7, blue: 0.5).opacity(0.2) : 
                                        Color(red: 0.95, green: 0.95, blue: 0.98))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(red: 0.6, green: 0.6, blue: 0.7).opacity(0.3), lineWidth: 1.5)
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                
                                Image(systemName: "rectangle.on.rectangle.fill")
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundColor(isScreenSharingActive ? 
                                                  Color(red: 0.4, green: 0.6, blue: 0.4) : 
                                                  Color(red: 0.5, green: 0.5, blue: 0.7))
                            }
                            
                            Text("screenButtonLabel".localized)
                                .font(.system(size: 20, weight: .bold))
                                .tracking(1)
                                .foregroundColor(isScreenSharingActive ? 
                                               Color(red: 0.3, green: 0.5, blue: 0.3) : 
                                               Color(red: 0.3, green: 0.3, blue: 0.35))
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
                .preferredColorScheme(.light)
                .onDisappear {
                    // 如果从设置页面返回，需要更新UI状态以匹配实际的录音状态
                    if !VoiceCaptureManager.shared.isRecording {
                        withAnimation {
                            isMicrophoneActive = false
                        }
                    }
                }
        }
        .sheet(isPresented: $showingBroadcastView) {
            BroadcastScreenView()
        }
        .sheet(isPresented: $showingVoiceCapture) {
            VoiceCaptureView()
                .preferredColorScheme(.light)
        }
        // 监听VoiceCaptureManager的录音状态变化
        .onChange(of: voiceCaptureManager.isRecording) { oldValue, newValue in 
            print("VoiceCaptureManager.isRecording变化: \(oldValue) -> \(newValue)")
            // 如果录音状态关闭，确保UI反映出来
            if !newValue {
                withAnimation {
                    isMicrophoneActive = false
                }
                // 仅当之前状态是录音中时，才显示停止消息
                if oldValue {
                    messageText = "voiceOffMessage".localized
                }
            }
        }
        // 监听来自VoiceProfileView的录音状态变化
        .listenToVoiceProfileRecording(onStart: {
            // 当VoiceProfileView开始录音时，确保主界面不显示录音状态
            print("收到VoiceProfileView开始录音通知")
            DispatchQueue.main.async {
                isMicrophoneActive = false
                messageText = "configRecording".localized
            }
        }, onStop: {
            // 当VoiceProfileView停止录音时，更新消息
            print("收到VoiceProfileView停止录音通知")
            DispatchQueue.main.async {
                isMicrophoneActive = false
                messageText = "voiceOffMessage".localized
                
                // 2秒后恢复默认消息
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    messageText = "initialGreeting".localized
                }
            }
        }, onDismiss: {
            // 当VoiceProfileView关闭时，确保主界面状态正确
            print("收到VoiceProfileView页面关闭通知")
            DispatchQueue.main.async {
                isMicrophoneActive = false
                messageText = "voiceOffMessage".localized
                
                // 强制重置isMicrophoneActive状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isMicrophoneActive = false
                }
            }
        })
    }
    
    // MARK: - User Actions
    
    private var isRunningInPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private func toggleMicrophone() {
        print("切换麦克风按钮被点击")
        
        // 在预览模式下简单切换状态，不尝试访问实际API
        if isRunningInPreview {
            withAnimation(.easeInOut(duration: 0.3)) {
                isMicrophoneActive.toggle()
            }
            messageText = isMicrophoneActive ? "listeningMessage".localized : "voiceOffMessage".localized
            print("预览模式：跳过实际录音")
            return
        }
        
        // 停止当前录音 或 开始新录音
        if isMicrophoneActive {
            // 正在录音，需要停止
            withAnimation(.easeInOut(duration: 0.3)) {
                isMicrophoneActive = false
            }
            messageText = "voiceOffMessage".localized
            showingVoiceCapture = false
            
            print("停止录音")
            VoiceCaptureManager.shared.stopRecording()
        } else {
            // 未在录音，需要开始
            // 先更新UI状态，给用户反馈
            withAnimation(.easeInOut(duration: 0.3)) {
                isMicrophoneActive = true
            }
            
            // 更新消息文本
            messageText = "listeningMessage".localized
            
            // 显示录音界面
            showingVoiceCapture = true
            
            print("激活麦克风")
            print("尝试启动录音...")
            
            // 在后台线程启动录音以避免UI卡顿
            DispatchQueue.global(qos: .userInitiated).async {
                // 尝试启动录音
                VoiceCaptureManager.shared.startRecording { success, error in
                    // 确保在主线程更新UI
                    DispatchQueue.main.async {
                        if success {
                            print("录音成功启动")
                        } else {
                            // 启动失败，回滚UI状态
                            withAnimation {
                                self.isMicrophoneActive = false
                                self.showingVoiceCapture = false
                                
                                // 显示错误消息
                                if let error = error {
                                    self.messageText = "无法启动录音: \(error.localizedDescription)"
                                    print("无法启动录音: \(error.localizedDescription)")
                                } else {
                                    self.messageText = "voiceErrorMessage".localized
                                    print("录音启动失败，无具体错误信息")
                                }
                            }
                            
                            // 2秒后恢复默认消息
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.messageText = "initialGreeting".localized
                            }
                        }
                    }
                }
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
    @State private var selectedPersonalityTrait = "calmTrait".localized
    @State private var showingVoiceProfilePage = false
    @State private var showingVoiceClonePage = false
    @ObservedObject private var voiceCaptureManager = VoiceCaptureManager.shared
    
    let personalityTraits = ["calmTrait".localized, "kindTrait".localized, "幽默"]
    let availableVoices = ["shimmer", "echo", "fable", "onyx", "nova"]
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                // 页面背景
                Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()
                
                // 顶部白色区域和标题
                VStack(spacing: 0) {
                    ZStack {
                        // 白色背景
                        Rectangle()
                            .fill(Color.white)
                            .frame(height: 110)
                            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                        
                        // 居中标题
                        Text("设置")
                            .font(.system(size: 48, weight: .bold))
                            .tracking(2)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    }
                    .ignoresSafeArea(edges: .top)
                    
                    // 内容区域
                    ScrollView {
                        VStack(spacing: 30) {
                            // Voice selection
                            VStack(alignment: .leading, spacing: 15) {
                                Text("voiceTypeLabel".localized)
                                    .font(.system(size: 20, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                    .padding(.leading, 10)
                                
                                Picker("Voice Type", selection: $selectedVoice) {
                                    ForEach(availableVoices, id: \.self) { voice in
                                        Text(voice.capitalized)
                                            .font(.system(size: 18, weight: .regular))
                                            .tag(voice)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                                )
                                .padding(.horizontal, 10)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 15)
                            
                            // Voice Clone Section (新增)
                            VStack(alignment: .leading, spacing: 15) {
                                Text("声音克隆")
                                    .font(.system(size: 20, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                    .padding(.leading, 10)
                                
                                Button(action: {
                                    // 如果正在进行主界面的语音识别，先停止它
                                    if voiceCaptureManager.isRecording {
                                        voiceCaptureManager.stopRecording()
                                    }
                                    showingVoiceClonePage = true
                                }) {
                                    HStack {
                                        Text("创建个性化语音")
                                            .font(.system(size: 18, weight: .regular))
                                            .tracking(0.5)
                                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.6))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 20, weight: .semibold))
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
                                
                                if let voiceId = UserDefaults.standard.string(forKey: "clonedVoiceId"),
                                   let voiceName = UserDefaults.standard.string(forKey: "clonedVoiceName") {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(voiceName)
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                            
                                            Text("ID: \(voiceId)")
                                                .font(.system(size: 14, weight: .regular))
                                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.4))
                                    }
                                    .padding(.vertical, 15)
                                    .padding(.horizontal, 20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.8))
                                            .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                                    )
                                    .padding(.horizontal, 10)
                                }
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 15)
                            
                            // Voice Profile Section
                            VStack(alignment: .leading, spacing: 15) {
                                Text("voiceProfileLabel".localized)
                                    .font(.system(size: 20, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                    .padding(.leading, 10)
                                
                                Button(action: {
                                    // 如果正在进行主界面的语音识别，先停止它
                                    if voiceCaptureManager.isRecording {
                                        voiceCaptureManager.stopRecording()
                                    }
                                    showingVoiceProfilePage = true
                                }) {
                                    HStack {
                                        Text("customizeVoiceButton".localized)
                                            .font(.system(size: 18, weight: .regular))
                                            .tracking(0.5)
                                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.6))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 20, weight: .semibold))
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
                            
                            // Assistant traits - 修改为单选
                            VStack(alignment: .leading, spacing: 15) {
                                Text("assistantPersonalityLabel".localized)
                                    .font(.system(size: 20, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                    .padding(.leading, 10)
                                
                                VStack(spacing: 0) {
                                    ForEach(personalityTraits, id: \.self) { trait in
                                        Button(action: {
                                            // 点击时更新选中的特质
                                            selectedPersonalityTrait = trait
                                        }) {
                                            HStack {
                                                Text(trait)
                                                    .font(.system(size: 18, weight: .regular))
                                                    .tracking(0.5)
                                                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                                Spacer()
                                                // 仅当当前特质被选中时显示勾选图标
                                                if selectedPersonalityTrait == trait {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 20, weight: .semibold))
                                                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                                                }
                                            }
                                            .padding(.vertical, 15)
                                            .padding(.horizontal, 15)
                                            .frame(height: 52)
                                        }
                                        
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
                                    .font(.system(size: 20, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                    .padding(.leading, 10)
                                
                                HStack {
                                    Text("versionInfo".localized)
                                        .font(.system(size: 18, weight: .regular))
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
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true) // 隐藏原生导航栏
            .sheet(isPresented: $showingVoiceProfilePage, onDismiss: {
                // 确保语音配置页面关闭时发送通知
                VoiceProfileCoordinator.shared.notifyDismissed()
            }) {
                VoiceProfileView()
                    .preferredColorScheme(.light)
            }
            .sheet(isPresented: $showingVoiceClonePage) {
                IntegratedVoiceCloneView()
                    .preferredColorScheme(.light)
            }
        }
    }
}

struct VoiceProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var voiceCaptureManager = VoiceCaptureManager.shared
    @State private var recordingName: String = ""
    @State private var showingSaveDialog = false
    @State private var isPlayingRecording: String? = nil
    @State private var waveformHeights: [CGFloat] = Array(repeating: 0, count: 40)
    @State private var waveformTimer: Timer? = nil
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        instructionsView
                        recordingVisualizerView
                        
                        // 在录音成功后显示上传按钮
                        if let _ = voiceCaptureManager.voiceFileURL, !voiceCaptureManager.isRecording {
                            saveRecordingButtonView
                        }
                        
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
                        // 在页面关闭前发送通知，确保主界面状态更新
                        print("点击完成按钮")
                        
                        // 使用主线程更新UI，避免跨线程问题
                        DispatchQueue.main.async {
                            VoiceProfileCoordinator.shared.notifyDismissed()
                            print("点击完成按钮发送页面关闭通知")
                            
                            // 如果正在录音，也发送停止录音通知
                            if voiceCaptureManager.isRecording {
                                VoiceProfileCoordinator.shared.notifyRecordingStopped()
                                print("点击完成按钮发送停止录音通知")
                            }
                        }
                        
                        dismiss()
                    }) {
                        Text("完成")
                            .font(.system(size: 17))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                    }
                }
            }
            .onAppear {
                // 重新加载保存的录音列表
                voiceCaptureManager.reloadSavedRecordings()
                
                // 启动波形动画
                startWaveformAnimation()
            }
            .onDisappear {
                // 停止波形动画
                waveformTimer?.invalidate()
                waveformTimer = nil
                
                // 停止任何正在播放的录音
                audioPlayer?.stop()
                audioPlayer = nil
                
                // 停止录音并重置音频会话
                if voiceCaptureManager.isRecording {
                    _ = voiceCaptureManager.stopVoiceFileRecording()
                    
                    // 确保在主线程上发送通知
                    DispatchQueue.main.async {
                        // 通知主界面录音已停止
                        VoiceProfileCoordinator.shared.notifyRecordingStopped()
                        print("在onDisappear中发送停止录音通知")
                    }
                }
                
                // 无论如何，都通知主界面语音配置页面已关闭
                DispatchQueue.main.async {
                    VoiceProfileCoordinator.shared.notifyDismissed()
                    print("在onDisappear中发送页面关闭通知")
                }
                
                // 重置音频会话
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                } catch {
                    print("离开页面时重置音频会话出错: \(error)")
                }
            }
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Subviews
    
    private var instructionsView: some View {
        Text("请在安静的环境中录制您的声音样本，以便AI助手学习您的声音特征。")
            .font(.system(size: 18, weight: .regular))
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
            
            VStack {
                if voiceCaptureManager.isRecording {
                    // 录音状态下将波形图往上移动
                    VStack(spacing: 0) {
                        Spacer().frame(height: 15) // 添加顶部间距
                        
                        // 显示录音时长
                        Text(formatDuration(voiceCaptureManager.currentRecordingDuration))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                        
                        // 实时声波可视化 - 使用状态驱动的波形
                        HStack(spacing: 3) {
                            ForEach(0..<waveformHeights.count, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color(red: 0.5, green: 0.5, blue: 0.8))
                                    .frame(width: 2, height: waveformHeights[index])
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: waveformHeights[index])
                            }
                        }
                        .padding(.top, 7)
                        
                        Spacer()
                    }
                    .padding(.top, 0)
                } else if let _ = voiceCaptureManager.voiceFileURL {
                    // 显示已录制但未保存的录音
                    VStack(spacing: 0) {
                        Spacer().frame(height: 15) // 与录音时相同的顶部间距
                        
                        // 显示与录音时完全相同的结构
                        Text("录音完成")
                            .font(.system(size: 22, weight: .semibold)) // 与录音时的字体大小和粗细相同
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                        
                        // 显示最后录制时的波形状态，与录音时布局完全一致
                        HStack(spacing: 3) {
                            ForEach(0..<waveformHeights.count, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color(red: 0.5, green: 0.5, blue: 0.8))
                                    .frame(width: 2, height: waveformHeights[index])
                            }
                        }
                        .padding(.top, 7)
                        
                        Spacer()
                    }
                    .padding(.top, 0)
                } else {
                    // 麦克风准备好但未录音时显示静止的波形图
                    VStack(spacing: 0) {
                        Spacer().frame(height: 15) // 与录音时相同的顶部间距
                        
                        // 状态文本占位，保持布局一致性
                        Text("准备录音")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                        
                        // 静止波形图
                        HStack(spacing: 3) {
                            ForEach(0..<40, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color(red: 0.7, green: 0.7, blue: 0.8).opacity(0.3))
                                    .frame(width: 2, height: CGFloat.random(in: 5...50))
                            }
                        }
                        .padding(.top, 7) // 从原来的2增加到7，向下移动5像素
                        
                        Spacer()
                    }
                    .padding(.top, 0)
                }
            }
            
            recordButtonView
        }
        .padding(.horizontal, 20)
    }
    
    private func startWaveformAnimation() {
        // 初始化波形高度（如果尚未设置）
        if waveformHeights.allSatisfy({ $0 == 0 }) {
            // 使用更大的高度差异
            waveformHeights = (0..<40).map { _ in CGFloat.random(in: 10...50) }
        }
        
        // 创建计时器来更新波形
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            // 在录音状态或播放状态才更新波形
            if voiceCaptureManager.isRecording || self.isPlayingRecording != nil {
                for i in 0..<self.waveformHeights.count {
                    // 部分保留前值以获得更平滑的动画
                    let previousHeight = self.waveformHeights[i]
                    // 使用更大的波动范围（5-50）
                    let randomHeight = CGFloat.random(in: 5...50)
                    self.waveformHeights[i] = (previousHeight * 0.6) + (randomHeight * 0.4)
                }
            }
        }
        
        // 确保计时器在滚动时也能运行
        if let timer = waveformTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private var recordButtonView: some View {
        VStack {
            Spacer()
            
            recordButton
                .padding(.bottom, 25)
        }
    }
    
    private var recordButton: some View {
        Button(action: {
            if voiceCaptureManager.isRecording {
                // 停止录音
                _ = voiceCaptureManager.stopVoiceFileRecording()
                // 确保无论录音是否成功停止，都更新UI状态
                DispatchQueue.main.async {
                    // 通知其他视图录音已停止
                    VoiceProfileCoordinator.shared.notifyRecordingStopped()
                    print("发送停止录音通知")
                }
            } else if voiceCaptureManager.voiceFileURL != nil {
                // 重新录音
                voiceCaptureManager.resetVoiceCloneStatus()
            } else {
                // 开始录音
                voiceCaptureManager.startVoiceFileRecording()
                // 通知其他视图录音已开始
                VoiceProfileCoordinator.shared.notifyRecordingStarted()
                print("发送开始录音通知")
            }
        }) {
            HStack {
                if voiceCaptureManager.isRecording {
                    // 停止录音按钮
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.trailing, 8)
                    
                    Text("停止录音")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                } else if voiceCaptureManager.voiceFileURL != nil {
                    // 重新录音按钮
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.trailing, 8)
                    
                    Text("重新录音")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    // 开始录音按钮
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.trailing, 8)
                    
                    Text("开始录音")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 30)
            .background(
                Capsule()
                    .fill(voiceCaptureManager.isRecording ? 
                         Color.red.opacity(0.8) : 
                         Color(red: 0.5, green: 0.5, blue: 0.8))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
    }
    
    @ViewBuilder
    private var recordButtonOverlay: some View {
        EmptyView() // 已不再使用
    }
    
    private var saveRecordingButtonView: some View {
        Button(action: {
            saveRecording()
        }) {
            HStack {
                Spacer()
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 18))
                    .padding(.trailing, 5)
                Text("保存录音")
                    .font(.system(size: 17, weight: .medium))
                    .tracking(1)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.5, green: 0.5, blue: 0.8))
            )
            .foregroundColor(.white)
            .padding(.horizontal, 20)
        }
    }
    
    private var savedRecordingsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("已保存的录音")
                    .font(.system(size: 18, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                
                Spacer()
                
                Text("\(voiceCaptureManager.savedRecordings.count) 个录音")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
            }
            .padding(.horizontal, 20)
            
            if voiceCaptureManager.savedRecordings.isEmpty {
                HStack {
                    Spacer()
                    Text("没有保存的录音")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        .padding(.vertical, 30)
                    Spacer()
                }
            } else {
                ForEach(voiceCaptureManager.savedRecordings) { recording in
                    recordingRowView(for: recording)
                }
            }
        }
        .padding(.bottom, 20)
    }
    
    private func recordingRowView(for recording: SavedRecording) -> some View {
        HStack {
            Image(systemName: "waveform")
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
            
            Text(recording.description)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
            
            Spacer()
            
            Text(formatDuration(recording.duration))
                .font(.system(size: 14, weight: .light))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
            
            Button(action: {
                playOrStopRecording(recording)
            }) {
                Image(systemName: isPlayingRecording == recording.id ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
            }
            
            Button(action: {
                deleteRecording(recording)
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(Color.red.opacity(0.7))
            }
            .padding(.leading, 5)
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
    
    // MARK: - Helper Functions
    
    private func saveRecording() {
        // 自动生成年日月时分秒格式的文件名
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let autoName = "录音_\(timestamp)"
        voiceCaptureManager.saveCurrentRecording(description: autoName)
        // 保存后清空当前录音
        voiceCaptureManager.resetVoiceCloneStatus()
    }
    
    private func playOrStopRecording(_ recording: SavedRecording) {
        if isPlayingRecording == recording.id {
            // 停止播放
            audioPlayer?.stop()
            isPlayingRecording = nil
        } else {
            // 开始播放
            isPlayingRecording = recording.id
            
            do {
                // 配置音频会话为播放模式
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                
                // 创建并保存播放器实例
                audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
                audioPlayer?.delegate = voiceCaptureManager
                audioPlayer?.prepareToPlay()
                
                // 检查音量
                audioPlayer?.volume = 1.0
                
                if audioPlayer?.play() == true {
                    print("播放开始：\(recording.description)")
                    // 播放完成后自动重置状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + recording.duration) {
                        if self.isPlayingRecording == recording.id {
                            self.isPlayingRecording = nil
                        }
                    }
                } else {
                    print("播放失败")
                    isPlayingRecording = nil
                }
            } catch {
                print("播放录音出错: \(error.localizedDescription)")
                isPlayingRecording = nil
            }
        }
    }
    
    private func deleteRecording(_ recording: SavedRecording) {
        // 如果正在播放这个录音，先停止播放
        if isPlayingRecording == recording.id {
            audioPlayer?.stop()
            audioPlayer = nil
            isPlayingRecording = nil
        }
        
        // 从VoiceCaptureManager中删除录音
        voiceCaptureManager.deleteRecording(id: recording.id)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // 使用一个基本的环境包装ContentView，确保不会触发录音功能
        ContentView()
            .environment(\.isPreview, true)
    }
}

// MARK: - 整合后的声音克隆视图

struct IntegratedVoiceCloneView: View {
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
    
    // 获取错误消息
    private var errorMessage: String? {
        if case .failed(let error) = voiceCaptureManager.cloneStatus {
            return error.localizedDescription
        }
        return nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景 - 使用与ContentView一致的设计
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
                
                VStack(spacing: 30) {
                    // 顶部说明
                    VStack(alignment: .leading, spacing: 10) {
                        Text("创建你的个性化声音")
                            .font(.system(size: 20, weight: .bold))
                            .tracking(1)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        
                        Text("请录制一段至少30秒的清晰语音。录制完成后，我们会将其上传到服务器进行声音克隆。这个过程可能需要几分钟时间。")
                            .font(.system(size: 16))
                            .lineSpacing(4)
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                    )
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // 录音状态指示 - 使用ContentView的风格
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
                    
                    // 控制按钮 - 使用ContentView风格
                    HStack(spacing: 60) {
                        if voiceCaptureManager.isRecording {
                            // 停止录音按钮
                            Button(action: {
                                _ = voiceCaptureManager.stopVoiceFileRecording()
                            }) {
                                VStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0.8, green: 0.3, blue: 0.3).opacity(0.8))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color(red: 0.9, green: 0.4, blue: 0.4).opacity(0.3), lineWidth: 1.5)
                                            )
                                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                        
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 30, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("停止录音")
                                        .font(.system(size: 18, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(Color(red: 0.7, green: 0.3, blue: 0.3))
                                }
                            }
                        } else if case .uploading = voiceCaptureManager.cloneStatus {
                            // 上传中，不显示按钮
                            EmptyView()
                        } else if case .success = voiceCaptureManager.cloneStatus {
                            // 成功，显示完成按钮
                            Button(action: {
                                dismiss()
                            }) {
                                VStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0.4, green: 0.7, blue: 0.4).opacity(0.8))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color(red: 0.5, green: 0.8, blue: 0.5).opacity(0.3), lineWidth: 1.5)
                                            )
                                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                        
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 30, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("完成")
                                        .font(.system(size: 18, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.4))
                                }
                            }
                        } else if voiceCaptureManager.voiceFileURL != nil {
                            // 显示重录和上传按钮
                            Button(action: {
                                voiceCaptureManager.resetVoiceCloneStatus()
                            }) {
                                VStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0.5, green: 0.5, blue: 0.5).opacity(0.2))
                                            .frame(width: 70, height: 70)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color(red: 0.6, green: 0.6, blue: 0.7).opacity(0.3), lineWidth: 1.5)
                                            )
                                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                        
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 26, weight: .semibold))
                                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                                    }
                                    
                                    Text("重录")
                                        .font(.system(size: 16, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                                }
                            }
                            
                            Button(action: {
                                voiceCaptureManager.uploadVoiceToCloneAPI()
                            }) {
                                VStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0.4, green: 0.5, blue: 0.8).opacity(0.8))
                                            .frame(width: 70, height: 70)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color(red: 0.5, green: 0.6, blue: 0.9).opacity(0.3), lineWidth: 1.5)
                                            )
                                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                        
                                        Image(systemName: "icloud.and.arrow.up.fill")
                                            .font(.system(size: 26, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("上传")
                                        .font(.system(size: 16, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.8))
                            }
                            .disabled(voiceCaptureManager.voiceCloneName.isEmpty)
                            .opacity(voiceCaptureManager.voiceCloneName.isEmpty ? 0.5 : 1.0)
                            
                            // 如果有错误，显示错误消息
                            if let errorMsg = errorMessage {
                                Text(errorMsg)
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                    .padding(.top, 5)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            // 显示录音按钮
                            Button(action: {
                                voiceCaptureManager.startVoiceFileRecording()
                            }) {
                                VStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0.5, green: 0.5, blue: 0.8).opacity(0.8))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color(red: 0.6, green: 0.6, blue: 0.9).opacity(0.3), lineWidth: 1.5)
                                            )
                                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                        
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 30, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("开始录音")
                                        .font(.system(size: 18, weight: .bold))
                                        .tracking(1)
                                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                                }
                            }
                            .disabled(voiceCaptureManager.permissionStatus != .authorized)
                        }
                    }
                    .padding(.bottom)
                    
                    // 时间显示
                    if voiceCaptureManager.isRecording {
                        Text(formattedTime)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                            .padding(.top, 5)
                            .padding(.bottom, 20)
                    }
                }
                .padding()
            }
            .navigationTitle("创建个性化声音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showHelp = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
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
    
    private var recordingAnimation: some View {
        VStack(spacing: 25) {
            // 使用与ContentView相似的动画效果
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.9, green: 0.5, blue: 0.5).opacity(0.6),
                                Color(red: 0.9, green: 0.6, blue: 0.7).opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.05)
                    .opacity(0.8)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: voiceCaptureManager.isRecording
                    )
                
                Image(systemName: "waveform")
                    .font(.system(size: 50))
                    .foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.3))
                    .symbolEffect(.variableColor.iterative, options: .repeating)
            }
            
            Text("正在录音...")
                .font(.system(size: 22, weight: .semibold))
                .tracking(1)
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
            
            Text("请清晰地朗读一段内容")
                .font(.system(size: 16))
                .tracking(0.5)
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
        }
    }
    
    private var uploadingAnimation: some View {
        VStack(spacing: 25) {
            // 使用与ContentView相似的动画效果
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.5, green: 0.5, blue: 0.9).opacity(0.6),
                                Color(red: 0.6, green: 0.6, blue: 0.9).opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(1.05)
                    .opacity(0.8)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: true
                    )
                
                ProgressView()
                    .scaleEffect(2)
                    .tint(Color(red: 0.5, green: 0.5, blue: 0.8))
            }
            
            Text("正在上传并处理语音...")
                .font(.system(size: 22, weight: .semibold))
                .tracking(1)
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
            
            Text("这可能需要几分钟时间")
                .font(.system(size: 16))
                .tracking(0.5)
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
        }
    }
    
    private var successView: some View {
        VStack(spacing: 25) {
            // 使用与ContentView相似的效果
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.98, blue: 0.95))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.4, green: 0.8, blue: 0.4).opacity(0.6),
                                Color(red: 0.5, green: 0.8, blue: 0.5).opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.4))
            }
            
            Text("声音克隆成功！")
                .font(.system(size: 22, weight: .semibold))
                .tracking(1)
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
            
            if let voiceId = voiceCaptureManager.cloneStatus.voiceId {
                Text("声音ID: \(voiceId)")
                    .font(.system(size: 16, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
            }
        }
    }
    
    private var readyToUploadView: some View {
        VStack(spacing: 25) {
            // 使用与ContentView相似的效果
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
                    .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.4, green: 0.4, blue: 0.8).opacity(0.6),
                                Color(red: 0.5, green: 0.5, blue: 0.9).opacity(0.6)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.4, green: 0.5, blue: 0.8))
            }
            
            Text("录音完成")
                .font(.system(size: 22, weight: .semibold))
                .tracking(1)
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
            
            Text("请为你的声音起一个名字，然后点击上传按钮")
                .font(.system(size: 16))
                .tracking(0.5)
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            // 声音名称输入框
            TextField("声音名称", text: $voiceCaptureManager.voiceCloneName)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.5, green: 0.5, blue: 0.8).opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 40)
                .padding(.top, 5)
        }
    }
    
    private var readyToRecordView: some View {
        VStack(spacing: 25) {
            // 使用与ContentView相似的效果
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
                    .frame(width: 120, height: 120)
                
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
                        lineWidth: 3
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
            }
            
            Text("准备录音")
                .font(.system(size: 22, weight: .semibold))
                .tracking(1)
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
            
            Text("点击下方按钮开始录制你的声音")
                .font(.system(size: 16))
                .tracking(0.5)
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
        }
    }
    
    private var helpView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("如何获得最佳效果")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(1)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        
                        Text("1. 在安静的环境中录音")
                            .font(.headline)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        Text("确保录音环境没有背景噪音，如风扇声、交通声或其他人说话的声音。")
                            .font(.body)
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        
                        Text("2. 保持适当距离")
                            .font(.headline)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        Text("将手机或麦克风保持在距离嘴部约15-20厘米的位置，不要太近或太远。")
                            .font(.body)
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        
                        Text("3. 说话清晰自然")
                            .font(.headline)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        Text("以自然的语速和音量朗读，不要刻意改变声音风格。")
                            .font(.body)
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    }
                    
                    Group {
                        Text("4. 录制足够长度")
                            .font(.headline)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        Text("至少录制30秒的声音样本，更长的样本有助于提高克隆效果。")
                            .font(.body)
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        
                        Text("5. 多样化的内容")
                            .font(.headline)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        Text("尝试朗读包含不同情感和语调的内容，这有助于系统捕捉你声音的多样性。")
                            .font(.body)
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        
                        Text("关于隐私")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            .padding(.top, 10)
                        
                        Text("你的声音样本将被上传到我们的服务器进行处理。我们会保护你的隐私，不会将样本用于其他目的。你可以随时删除你的声音样本。")
                            .font(.body)
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    }
                }
                .padding()
            }
            .background(Color(red: 0.97, green: 0.97, blue: 0.98))
            .navigationTitle("语音克隆帮助")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        showHelp = false
                    }
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
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

