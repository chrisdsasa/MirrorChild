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
    let avatarSize: CGFloat = 180
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedVoice = "shimmer"
    @State private var personalityTraits: [String] = ["calmTrait".localized, "kindTrait".localized, "helpfulTrait".localized]
    @State private var showingVoiceRecordingPage = false
    @ObservedObject private var voiceCaptureManager = VoiceCaptureManager.shared
    
    let availableVoices = ["shimmer", "echo", "fable", "onyx", "nova"]
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.9, green: 0.85, blue: 0.95), // 更柔和的淡紫色
                    Color(red: 0.85, green: 0.8, blue: 0.92), // 中间过渡色
                    Color(red: 0.82, green: 0.78, blue: 0.9)  // 略深的柔和紫色
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Subtle decorative elements
            GeometryReader { geometry in
                ZStack {
                    // Top decorative element
                    Circle()
                        .fill(Color.accentRebeccaPurple.opacity(0.05))
                        .frame(width: 300, height: 300)
                        .blur(radius: 50)
                        .offset(x: geometry.size.width * 0.3, y: -geometry.size.height * 0.2)
                    
                    // Bottom decorative element
                    Circle()
                        .fill(Color.accentRebeccaPurple.opacity(0.05))
                        .frame(width: 250, height: 250)
                        .blur(radius: 40)
                        .offset(x: -geometry.size.width * 0.2, y: geometry.size.height * 0.3)
                }
            }
            
            VStack(spacing: 30) {
                // Top bar with modern design
                HStack {
                    Text("appTitle".localized)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.3, blue: 0.7),
                                    Color(red: 0.6, green: 0.4, blue: 0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        showingSettings = true
                    }) {
                        ZStack {
                            // 毛玻璃效果底层
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                            
                            // 渐变紫色边框
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.5, green: 0.3, blue: 0.7),
                                            Color(red: 0.6, green: 0.4, blue: 0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                                .frame(width: 44, height: 44)
                            
                            // 带渐变的小圆形背景
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.7),
                                            Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.6)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .shadow(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(DesignSystem.ButtonStyles.ScaleButton())
                    .accessibilityLabel("settingsButton".localized)
                    .padding(.trailing)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Modern avatar design
                ZStack {
                    // 毛玻璃效果底层
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: avatarSize, height: avatarSize)
                    
                    // 白色背景提供对比
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: avatarSize - 6, height: avatarSize - 6)
                    
                    // 渐变紫色边框
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.3, blue: 0.7),
                                    Color(red: 0.6, green: 0.4, blue: 0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: avatarSize, height: avatarSize)
                    
                    // Modern avatar symbol
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.5, green: 0.3, blue: 0.7),
                                    Color(red: 0.6, green: 0.4, blue: 0.8)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: avatarSize * 0.4, height: avatarSize * 0.4)
                        .symbolEffect(.bounce, value: isMessageAnimating)
                    
                    // Activity indicators
                    if isMicrophoneActive || isScreenSharingActive {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        isMicrophoneActive ? Color.red.opacity(0.4) : Color.green.opacity(0.4),
                                        isMicrophoneActive ? Color.red.opacity(0.7) : Color.green.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: avatarSize + 20, height: avatarSize + 20)
                            .scaleEffect(isMicrophoneActive || isScreenSharingActive ? 1.1 : 1.0)
                            .opacity(isMicrophoneActive || isScreenSharingActive ? 0.8 : 0)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                                value: isMicrophoneActive || isScreenSharingActive
                            )
                    }
                }
                .shadow(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.2), radius: 20, x: 0, y: 10)
                .padding(.bottom, 20)
                
                // Message card with modern design
                Text(messageText)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(red: 0.3, green: 0.2, blue: 0.4))
                    .padding(.horizontal, 35)
                    .padding(.vertical, 30)
                    .background(
                        ZStack {
                            // 毛玻璃效果底层
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                            
                            // 白色背景提供对比
                            RoundedRectangle(cornerRadius: 22)
                                .fill(Color.white.opacity(0.7))
                                .padding(2)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.3),
                                        Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.2), radius: 15, x: 0, y: 5)
                    .padding(.horizontal, 25)
                    .opacity(isMessageAnimating ? 1 : 0.9)
                    .animation(.easeInOut(duration: 0.3), value: isMessageAnimating)
                
                Spacer()
                
                // Modern control buttons
                HStack(spacing: 40) {
                    // Voice button
                    Button(action: toggleMicrophone) {
                        VStack(spacing: 12) {
                            ZStack {
                                // 毛玻璃效果底层
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 70, height: 70)
                                
                                // 渐变紫色边框
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.5, green: 0.3, blue: 0.7),
                                                Color(red: 0.6, green: 0.4, blue: 0.8)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: 70, height: 70)
                                
                                // 带渐变的圆形背景
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                isMicrophoneActive ? Color.red.opacity(0.3) : Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.7),
                                                isMicrophoneActive ? Color.red.opacity(0.2) : Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.6)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: isMicrophoneActive ? "mic.fill" : "mic")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                                    .symbolEffect(.bounce, value: isMicrophoneActive)
                            }
                            .shadow(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            Text("voiceButtonLabel".localized)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.7))
                        }
                    }
                    .buttonStyle(DesignSystem.ButtonStyles.ScaleButton())
                    .accessibilityLabel("voiceButtonA11y".localized)
                    
                    // Screen button
                    Button(action: toggleScreenSharing) {
                        VStack(spacing: 12) {
                            ZStack {
                                // 毛玻璃效果底层
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 70, height: 70)
                                
                                // 渐变紫色边框
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.5, green: 0.3, blue: 0.7),
                                                Color(red: 0.6, green: 0.4, blue: 0.8)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: 70, height: 70)
                                
                                // 带渐变的圆形背景
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                isScreenSharingActive ? Color.green.opacity(0.3) : Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.7),
                                                isScreenSharingActive ? Color.green.opacity(0.2) : Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.6)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: isScreenSharingActive ? "rectangle.on.rectangle.fill" : "rectangle.on.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .symbolEffect(.bounce, value: isScreenSharingActive)
                            }
                            .shadow(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            Text("screenButtonLabel".localized)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(Color(red: 0.5, green: 0.3, blue: 0.7))
                        }
                    }
                    .buttonStyle(DesignSystem.ButtonStyles.ScaleButton())
                    .accessibilityLabel("screenButtonA11y".localized)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            withAnimation(.easeInOut(duration: 0.5)) {
                isMessageAnimating = true
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
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
        .sheet(isPresented: $showingVoiceRecordingPage) {
            VoiceProfileRecordingView()
        }
    }
    
    // MARK: - User Actions
    
    private var isRunningInPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    private func toggleMicrophone() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isMicrophoneActive.toggle()
        }
        
        if isMicrophoneActive {
            messageText = "listeningMessage".localized
            showingVoiceCapture = true
            
            if isRunningInPreview {
                return
            }
            
            VoiceCaptureManager.shared.startRecording { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.isMicrophoneActive = true
                    }
                } else if let error = error {
                    print("Recording failed: \(error.localizedDescription)")
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
            messageText = "voiceOffMessage".localized
            showingVoiceCapture = false
            
            if !isRunningInPreview {
                VoiceCaptureManager.shared.stopRecording()
            }
        }
    }
    
    private func toggleScreenSharing() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingBroadcastView = true
            messageText = "screenOnMessage".localized
        }
    }
}

// MARK: - Supporting Views and Styles



// MARK: - Preview Provider

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.isPreview, true)
    }
}
