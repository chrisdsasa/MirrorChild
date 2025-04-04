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
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    DesignSystem.Colors.surface,
                    DesignSystem.Colors.surfaceSecondary
                ]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            // Subtle decorative elements
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.accent.opacity(0.05))
                        .frame(width: 300, height: 300)
                        .blur(radius: 50)
                        .offset(x: geometry.size.width * 0.3, y: -geometry.size.height * 0.2)
                    
                    Circle()
                        .fill(DesignSystem.Colors.accent.opacity(0.05))
                        .frame(width: 250, height: 250)
                        .blur(radius: 40)
                        .offset(x: -geometry.size.width * 0.2, y: geometry.size.height * 0.3)
                }
            }
            
            VStack(spacing: DesignSystem.Layout.spacingLarge) {
                // Navigation header with title and dismiss button
                HStack {
                    Text("Voice Input")
                        .font(DesignSystem.Typography.title)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(DesignSystem.ButtonStyles.IconButton())
                }
                .padding(.top, DesignSystem.Layout.spacingLarge)
                .padding(.horizontal, DesignSystem.Layout.spacingLarge)
                
                // Auto punctuation toggle
                Toggle(isOn: $voiceCaptureManager.enablePunctuation) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto Punctuation")
                            .font(DesignSystem.Typography.bodyBold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Add punctuation marks automatically")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, DesignSystem.Layout.spacingLarge)
                .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.accent))
                
                // Status indicator
                HStack(spacing: DesignSystem.Layout.spacingMedium) {
                    Circle()
                        .fill(voiceCaptureManager.isRecording ? 
                              DesignSystem.Colors.success : DesignSystem.Colors.error)
                        .frame(width: 10, height: 10)
                    
                    Text(voiceCaptureManager.isRecording ? 
                         "Listening..." : "Voice recognition inactive")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(.vertical, DesignSystem.Layout.spacingSmall)
                .padding(.horizontal, DesignSystem.Layout.spacingMedium)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusLarge)
                        .fill(DesignSystem.Colors.glassMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusLarge)
                        .stroke(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, DesignSystem.Layout.spacingLarge)
                
                // Transcription area
                Group {
                    if voiceCaptureManager.isRecording || !voiceCaptureManager.transcribedText.isEmpty {
                        transcriptionView
                    } else {
                        emptyStateView
                    }
                }
                .frame(height: 400)
                .cardStyle()
                .padding(.horizontal, DesignSystem.Layout.spacingLarge)
                
                // Control button
                Button(action: {
                    if voiceCaptureManager.isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(voiceCaptureManager.isRecording ? 
                                  DesignSystem.Colors.error : 
                                  DesignSystem.Colors.accent)
                            .frame(width: 80, height: 80)
                            .shadow(radius: 5, x: 0, y: 3)
                        
                        Image(systemName: voiceCaptureManager.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(DesignSystem.ButtonStyles.IconButton())
                .accessibilityLabel(voiceCaptureManager.isRecording ? "Stop Recording" : "Start Recording")
                
                // Open settings button (if permission denied)
                if voiceCaptureManager.permissionStatus == .denied {
                    Button(action: {
                        showingSettingsAlert = true
                    }) {
                        Text("Open Settings")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                    .buttonStyle(DesignSystem.ButtonStyles.SecondaryButton())
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .alert(isPresented: $showingPermissionAlert) {
            Alert(
                title: Text("Permission Required"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingSettingsAlert) {
            Alert(
                title: Text("Open Settings"),
                message: Text("Please enable microphone access in Settings to use voice recognition."),
                primaryButton: .default(Text("Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    // Transcription view with live waveform
    private var transcriptionView: some View {
        VStack(spacing: DesignSystem.Layout.spacingMedium) {
            // Live waveform display
            if voiceCaptureManager.isRecording {
                LiveWaveformView()
                    .frame(height: 60)
                    .padding(.horizontal)
                    .padding(.top, 10)
            }
            
            ScrollView {
                Text(voiceCaptureManager.transcribedText)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Layout.spacingLarge) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .symbolEffect(.pulse, options: .repeating, value: voiceCaptureManager.isRecording)
            
            if voiceCaptureManager.permissionStatus == .denied {
                Text("Microphone access denied")
                    .font(DesignSystem.Typography.subtitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("Tap the microphone button to start listening")
                    .font(DesignSystem.Typography.subtitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    // Start recording function
    private func startRecording() {
        if isRunningInPreview {
            return
        }
        
        VoiceCaptureManager.shared.startRecording { success, error in
            if success {
                // Recording started successfully
            } else if let error = error {
                print("Recording failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    alertMessage = error.localizedDescription
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    // Stop recording function
    private func stopRecording() {
        if !isRunningInPreview {
            VoiceCaptureManager.shared.stopRecording()
        }
    }
}

// MARK: - Live Waveform

struct LiveWaveformView: View {
    @State private var waveform: [CGFloat] = Array(repeating: 0.1, count: 30)
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(waveform.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignSystem.Colors.accent)
                    .frame(width: 3, height: waveform[index] * 60)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5), value: waveform[index])
            }
        }
        .onReceive(timer) { _ in
            // Generate random waveform for visualization
            for i in 0..<waveform.count {
                withAnimation {
                    waveform[i] = CGFloat.random(in: 0.1...1.0)
                }
            }
        }
    }
}

// MARK: - Preview

struct VoiceCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceCaptureView()
    }
} 