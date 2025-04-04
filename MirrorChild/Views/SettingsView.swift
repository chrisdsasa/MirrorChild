import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @StateObject private var voiceCaptureManager = VoiceCaptureManager.shared
    @State private var showingVoiceRecordingPage = false
    @State private var selectedVoice = "shimmer"
    @State private var personalityTraits: [String] = ["calmTrait".localized, "kindTrait".localized, "helpfulTrait".localized]
    
    let availableVoices = ["shimmer", "echo", "fable", "onyx", "nova"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.95, blue: 0.98),
                        Color(red: 0.98, green: 0.98, blue: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Voice Profile Section
                        GroupBox {
                            Button(action: { showingVoiceRecordingPage = true }) {
                                HStack(spacing: 15) {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 60, height: 60)
                                        
                                        Image(systemName: "waveform")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Record Voice")
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                            .foregroundColor(.primary)
                                        
                                        Text("Create your voice profile")
                                            .font(.system(size: 14, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(DesignSystem.ButtonStyles.ScaleButton())
                        } label: {
                            Label("Voice Settings", systemImage: "mic.fill")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                        
                        // Voice Type Selection
                        GroupBox {
                            Picker("Voice Type", selection: $selectedVoice) {
                                ForEach(availableVoices, id: \.self) { voice in
                                    Text(voice.capitalized)
                                        .tag(voice)
                                }
                            }
                            .pickerStyle(.segmented)
                        } label: {
                            Label("Voice Type", systemImage: "person.wave.2.fill")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                        
                        // Personality Traits
                        GroupBox {
                            VStack(spacing: 0) {
                                ForEach(personalityTraits, id: \.self) { trait in
                                    HStack {
                                        Text(trait)
                                            .font(.system(size: 17, design: .rounded))
                                        
                                        Spacer()
                                        
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 12)
                                    
                                    if trait != personalityTraits.last {
                                        Divider()
                                    }
                                }
                            }
                        } label: {
                            Label("Personality", systemImage: "sparkles")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                        
                        // Auto Punctuation Toggle
                        GroupBox {
                            Toggle(isOn: .init(
                                get: { voiceCaptureManager.enablePunctuation },
                                set: { voiceCaptureManager.enablePunctuation = $0 }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Auto Punctuation")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    
                                    Text("Add punctuation marks automatically")
                                        .font(.system(size: 14, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        } label: {
                            Label("Features", systemImage: "text.quote")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                        
                        // About Section
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Version 1.0.0", systemImage: "info.circle")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(.secondary)
                                
                                Link(destination: URL(string: "https://example.com/privacy")!) {
                                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                                        .font(.system(size: 15, design: .rounded))
                                }
                                
                                Link(destination: URL(string: "https://example.com/terms")!) {
                                    Label("Terms of Service", systemImage: "doc.text.fill")
                                        .font(.system(size: 15, design: .rounded))
                                }
                            }
                            .foregroundColor(.accentColor)
                        } label: {
                            Label("About", systemImage: "info.circle.fill")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .groupBoxStyle(ModernGroupBoxStyle())
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                }
            }
            .sheet(isPresented: $showingVoiceRecordingPage) {
                VoiceProfileRecordingView()
            }
        }
    }
}

// MARK: - Supporting Views

struct ModernGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .foregroundColor(.primary.opacity(0.8))
                .padding(.leading, 8)
            
            VStack {
                configuration.content
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview Provider

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 