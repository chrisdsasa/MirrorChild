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
    
    // UI state
    @State private var showingSettings = false
    @State private var messageText = "initialGreeting".localized
    @State private var isMessageAnimating = false
    @State private var isMicrophoneActive = false
    @State private var isScreenSharingActive = false
    
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
            
            // Cherry blossom decorative elements (subtle)
            GeometryReader { geometry in
                ZStack {
                    // Top right cherry blossom
                    Image(systemName: "sakurasou")
                        .font(.system(size: 30))
                        .foregroundColor(Color.pink.opacity(0.3))
                        .position(x: geometry.size.width - 40, y: 60)
                    
                    // Bottom left cherry blossom
                    Image(systemName: "sakurasou")
                        .font(.system(size: 24))
                        .foregroundColor(Color.pink.opacity(0.2))
                        .position(x: 30, y: geometry.size.height - 100)
                }
            }
            
            VStack(spacing: 25) {
                // Top bar with elegant, minimalist design
                HStack {
                    Text("appTitle".localized)
                        .font(.system(size: 22, weight: .light))
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
                .padding(.top, 15)
                
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
                                    .fill(
                                        isMicrophoneActive ? 
                                        Color(red: 0.9, green: 0.5, blue: 0.5).opacity(0.2) :
                                        Color(red: 0.95, green: 0.95, blue: 0.98)
                                    )
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                isMicrophoneActive ?
                                                Color(red: 0.9, green: 0.5, blue: 0.5).opacity(0.4) :
                                                Color(red: 0.6, green: 0.6, blue: 0.7).opacity(0.3),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 30, weight: .light))
                                    .foregroundColor(
                                        isMicrophoneActive ?
                                        Color(red: 0.9, green: 0.4, blue: 0.4) :
                                        Color(red: 0.5, green: 0.5, blue: 0.7)
                                    )
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
                                    .fill(
                                        isScreenSharingActive ? 
                                        Color(red: 0.5, green: 0.7, blue: 0.6).opacity(0.2) :
                                        Color(red: 0.95, green: 0.95, blue: 0.98)
                                    )
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                isScreenSharingActive ?
                                                Color(red: 0.5, green: 0.7, blue: 0.6).opacity(0.4) :
                                                Color(red: 0.6, green: 0.6, blue: 0.7).opacity(0.3),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                
                                Image(systemName: "rectangle.on.rectangle")
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundColor(
                                        isScreenSharingActive ?
                                        Color(red: 0.4, green: 0.6, blue: 0.5) :
                                        Color(red: 0.5, green: 0.5, blue: 0.7)
                                    )
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
        .sheet(isPresented: $showingSettings) {
            JapaneseStyleSettingsView()
        }
    }
    
    // MARK: - User Actions
    
    private func toggleMicrophone() {
        isMicrophoneActive.toggle()
        if isMicrophoneActive {
            messageText = "listeningMessage".localized
        } else {
            messageText = "voiceOffMessage".localized
        }
    }
    
    private func toggleScreenSharing() {
        isScreenSharingActive.toggle()
        if isScreenSharingActive {
            messageText = "screenOnMessage".localized
        } else {
            messageText = "screenOffMessage".localized
        }
    }
}

struct JapaneseStyleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedVoice = "shimmer"
    @State private var fontSize: Double = 1.0
    @State private var personalityTraits: [String] = ["calmTrait".localized, "kindTrait".localized, "helpfulTrait".localized]
    
    let availableVoices = ["shimmer", "echo", "fable", "onyx", "nova"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
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
                        
                        // Text size adjustment
                        VStack(alignment: .leading, spacing: 15) {
                            Text("textSizeLabel".localized)
                                .font(.system(size: 18, weight: .medium))
                                .tracking(1)
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                                .padding(.leading, 10)
                            
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("smallLabel".localized)
                                        .font(.system(size: 16, weight: .light))
                                    Slider(value: $fontSize, in: 0.8...1.4, step: 0.1)
                                        .accentColor(Color(red: 0.6, green: 0.6, blue: 0.7))
                                    Text("largeLabel".localized)
                                        .font(.system(size: 20, weight: .light))
                                }
                                
                                Text("sampleText".localized)
                                    .font(.system(size: 24 * fontSize, weight: .light))
                                    .tracking(1)
                                    .padding(.top, 5)
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
                            )
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
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
