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
    @State private var messageText = "Hi there! I'm your digital companion. How can I help you today?"
    @State private var isMessageAnimating = false
    @State private var isMicrophoneActive = false
    @State private var isScreenSharingActive = false
    
    // Constants
    let avatarSize: CGFloat = 200
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]),
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Top bar with settings button
                HStack {
                    Spacer()
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                            .padding()
                    }
                }
                
                Spacer()
                
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: avatarSize, height: avatarSize)
                        .shadow(radius: 10)
                    
                    // Placeholder avatar image
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.blue)
                        .frame(width: avatarSize * 0.6, height: avatarSize * 0.6)
                    
                    // Animation rings when listening
                    if isMicrophoneActive {
                        ForEach(0..<3) { i in
                            Circle()
                                .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                                .frame(width: avatarSize + CGFloat(i * 30), 
                                       height: avatarSize + CGFloat(i * 30))
                                .scaleEffect(isMicrophoneActive ? 1.2 : 1.0)
                                .opacity(isMicrophoneActive ? 0.0 : 0.5)
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(i) * 0.3),
                                    value: isMicrophoneActive
                                )
                        }
                    }
                }
                
                // Message text
                Text(messageText)
                    .font(.system(size: 18, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.9))
                            .shadow(radius: 5)
                    )
                    .padding(.horizontal, 20)
                    .opacity(isMessageAnimating ? 1 : 0.7)
                    .scaleEffect(isMessageAnimating ? 1.02 : 1)
                    .animation(
                        Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                        value: isMessageAnimating
                    )
                    .onAppear {
                        isMessageAnimating = true
                    }
                
                Spacer()
                
                // Control buttons
                HStack(spacing: 40) {
                    // Microphone button
                    Button(action: toggleMicrophone) {
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(isMicrophoneActive ? Color.red.opacity(0.8) : Color.gray.opacity(0.2))
                                    .frame(width: 70, height: 70)
                                    .shadow(radius: 5)
                                
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(isMicrophoneActive ? .white : .gray)
                            }
                            
                            Text("Microphone")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Screen sharing button
                    Button(action: toggleScreenSharing) {
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(isScreenSharingActive ? Color.green.opacity(0.8) : Color.gray.opacity(0.2))
                                    .frame(width: 70, height: 70)
                                    .shadow(radius: 5)
                                
                                Image(systemName: "rectangle.on.rectangle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(isScreenSharingActive ? .white : .gray)
                            }
                            
                            Text("Screen")
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - User Actions
    
    private func toggleMicrophone() {
        isMicrophoneActive.toggle()
        if isMicrophoneActive {
            messageText = "I'm listening..."
        } else {
            messageText = "How else can I help you?"
        }
    }
    
    private func toggleScreenSharing() {
        isScreenSharingActive.toggle()
        if isScreenSharingActive {
            messageText = "I can see your screen now. What would you like help with?"
        } else {
            messageText = "Screen sharing stopped. How else can I help you?"
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedVoice = "shimmer"
    @State private var temperature: Double = 0.7
    @State private var personalityTraits: [String] = ["Friendly", "Patient", "Helpful"]
    
    let availableVoices = ["shimmer", "echo", "fable", "onyx", "nova"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Companion Voice")) {
                    Picker("Voice", selection: $selectedVoice) {
                        ForEach(availableVoices, id: \.self) { voice in
                            Text(voice.capitalized)
                                .tag(voice)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Personality")) {
                    ForEach(personalityTraits, id: \.self) { trait in
                        HStack {
                            Text(trait)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button("Add Trait") {
                        // In a real app, show a dialog to add a new trait
                    }
                }
                
                Section(header: Text("Response Style")) {
                    VStack {
                        Text("Creativity: \(Int(temperature * 100))%")
                        Slider(value: $temperature, in: 0...1)
                    }
                }
                
                Section(header: Text("Account")) {
                    Text("Manage Apple ID")
                        .foregroundColor(.blue)
                }
                
                Section(header: Text("About")) {
                    Text("Version 1.0.0")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
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
