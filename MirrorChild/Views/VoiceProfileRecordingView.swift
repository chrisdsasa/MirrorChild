import SwiftUI
import AVFoundation

struct VoiceProfileRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Recording state
    @State private var isRecording = false
    @State private var isPlayingBack = false
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingProgress: CGFloat = 0
    @State private var showingUploadSuccess = false
    @State private var showingPermissionAlert = false
    
    // Audio-related
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var recordingURL: URL?
    @State private var player: AVAudioPlayer?
    @State private var isUploading = false
    @State private var uploadSuccess = false
    @State private var alertMessage = ""
    @State private var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    
    // Audio level monitoring
    @State private var audioLevels: [CGFloat] = Array(repeating: 0, count: 30)
    @State private var meterTimer: Timer?
    
    // Constants
    private let maxRecordingTime: TimeInterval = 30 // 30 seconds
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    // Check if 30 seconds is complete
    private var isRecordingComplete: Bool {
        return recordingTime >= 29.5
    }
    
    // Progress percentage
    private var progressPercentage: Double {
        return min(recordingTime / 30.0, 1.0)
    }
    
    var body: some View {
        ZStack {
            // Background
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
                // Header with title and close button
                HStack {
                    Text("Voice Recording")
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
                
                Spacer()
                
                // Waveform view
                VStack {
                    waveformView
                        .frame(height: 150)
                        .opacity(isRecording || isPlayingBack ? 1 : 0.5)
                        .cardStyle()
                        .padding(.horizontal, DesignSystem.Layout.spacingLarge)
                    
                    // Progress and time information
                    VStack(spacing: DesignSystem.Layout.spacingMedium) {
                        // Progress bar
                        ProgressView(value: progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: isRecordingComplete ? 
                                                                      DesignSystem.Colors.success : 
                                                                      DesignSystem.Colors.accent))
                            .frame(height: 8)
                        
                        // Time text
                        Text("\(Int(min(recordingTime, 30))) seconds")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.horizontal, DesignSystem.Layout.spacingLarge)
                    .padding(.top, DesignSystem.Layout.spacingMedium)
                }
                
                Spacer()
                
                // Recording/Playback controls
                Group {
                    if recordingURL != nil && !isRecording {
                        // Playback and re-record buttons
                        HStack(spacing: DesignSystem.Layout.spacingExtraLarge) {
                            // Play button
                            Button(action: togglePlayback) {
                                ZStack {
                                    Circle()
                                        .fill(DesignSystem.Colors.success)
                                        .frame(width: 70, height: 70)
                                        .shadow(radius: 5, x: 0, y: 2)
                                    
                                    Image(systemName: isPlayingBack ? "pause.fill" : "play.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(DesignSystem.ButtonStyles.IconButton())
                            
                            // Re-record button
                            Button(action: resetRecording) {
                                ZStack {
                                    Circle()
                                        .fill(DesignSystem.Colors.accent)
                                        .frame(width: 70, height: 70)
                                        .shadow(radius: 5, x: 0, y: 2)
                                    
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(DesignSystem.ButtonStyles.IconButton())
                        }
                    } else {
                        // Record button
                        Button(action: toggleRecording) {
                            ZStack {
                                Circle()
                                    .fill(isRecording ? DesignSystem.Colors.error : DesignSystem.Colors.accent)
                                    .frame(width: 80, height: 80)
                                    .shadow(radius: 5, x: 0, y: 3)
                                
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(DesignSystem.ButtonStyles.IconButton())
                    }
                }
                .padding(.vertical, DesignSystem.Layout.spacingLarge)
                
                // Upload button
                if recordingURL != nil && !isRecording {
                    Button(action: uploadRecording) {
                        HStack {
                            Image(systemName: uploadSuccess ? "checkmark.circle" : "arrow.up.circle")
                                .font(.system(size: 20))
                            
                            Text(uploadSuccess ? "Uploaded" : "Upload Voice")
                                .font(DesignSystem.Typography.buttonPrimary)
                        }
                        .frame(width: 200)
                    }
                    .buttonStyle(DesignSystem.ButtonStyles.PrimaryButton())
                    .disabled(uploadSuccess)
                    .opacity(uploadSuccess ? 0.7 : 1)
                    .padding(.bottom, DesignSystem.Layout.spacingLarge)
                }
                
                Spacer()
            }
        }
        .onAppear {
            checkPermission()
        }
        .onDisappear {
            stopRecording()
            stopPlayback()
            meterTimer?.invalidate()
        }
        .onReceive(timer) { _ in
            updateTimer()
        }
        .alert(isPresented: $showingPermissionAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - Subviews
    
    // Waveform visualization
    private var waveformView: some View {
        HStack(spacing: 4) {
            ForEach(audioLevels.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                DesignSystem.Colors.accent.opacity(0.7),
                                DesignSystem.Colors.accent,
                                DesignSystem.Colors.accent.opacity(0.8)
                            ]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 3, height: max(audioLevels[index], 5))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.5), value: audioLevels)
    }
    
    // MARK: - Functions
    
    private func checkPermission() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            permissionStatus = .granted
        case .denied:
            permissionStatus = .denied
            alertMessage = "Microphone access is required for voice recording."
            showingPermissionAlert = true
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionStatus = granted ? .granted : .denied
                    if !granted {
                        self.alertMessage = "Microphone access is required for voice recording."
                        self.showingPermissionAlert = true
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard permissionStatus == .granted else {
            alertMessage = "Microphone permission is required."
            showingPermissionAlert = true
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("voiceRecording.m4a")
            
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordingTime = 0
            recordingURL = audioFilename
            
            // Start audio level monitoring
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let recorder = self.audioRecorder, recorder.isRecording {
                    recorder.updateMeters()
                    
                    // Get the average power level across all channels
                    let level = recorder.averagePower(forChannel: 0)
                    let normalizedLevel = self.normalizeLevel(level)
                    
                    // Update audio levels visualization
                    if self.audioLevels.count > 30 {
                        self.audioLevels.removeFirst()
                    }
                    self.audioLevels.append(normalizedLevel)
                }
            }
            meterTimer?.fire()
            
        } catch {
            alertMessage = "Failed to start recording: \(error.localizedDescription)"
            showingPermissionAlert = true
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        meterTimer?.invalidate()
        isRecording = false
        
        // For UI demo, ensure we have a recording URL even if something failed
        if recordingURL == nil {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            recordingURL = documentsPath.appendingPathComponent("voiceRecording.m4a")
        }
    }
    
    private func togglePlayback() {
        if isPlayingBack {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    private func startPlayback() {
        guard let url = recordingURL else { return }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = AudioPlayerDelegate(onFinish: {
                DispatchQueue.main.async {
                    self.isPlayingBack = false
                }
            })
            player?.play()
            isPlayingBack = true
            
            // Simulate audio levels during playback
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                var newLevels: [CGFloat] = []
                for _ in 0..<30 {
                    newLevels.append(CGFloat.random(in: 5...70))
                }
                self.audioLevels = newLevels
            }
            meterTimer?.fire()
            
        } catch {
            alertMessage = "Failed to play recording: \(error.localizedDescription)"
            showingPermissionAlert = true
        }
    }
    
    private func stopPlayback() {
        player?.stop()
        meterTimer?.invalidate()
        isPlayingBack = false
    }
    
    private func resetRecording() {
        stopPlayback()
        recordingURL = nil
        recordingTime = 0
        audioLevels = Array(repeating: 0, count: 30)
    }
    
    private func uploadRecording() {
        isUploading = true
        
        // Simulate upload progress
        let uploadTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            DispatchQueue.main.async {
                self.isUploading = false
                self.uploadSuccess = true
            }
        }
        uploadTimer.fire()
    }
    
    private func updateTimer() {
        if isRecording {
            recordingTime += 0.1
            
            // Auto-stop after 30 seconds
            if recordingTime >= 30.0 {
                stopRecording()
            }
        }
    }
    
    private func normalizeLevel(_ level: Float) -> CGFloat {
        // Audio level conversion from dB to visual height
        let minDb: Float = -50.0
        let maxDb: Float = -10.0
        let minHeight: CGFloat = 5.0
        let maxHeight: CGFloat = 70.0
        
        // Ensure level is in valid range
        let clampedLevel = max(min(level, maxDb), minDb)
        
        // Normalize dB value to 0-1 range
        let normalizedLevel = (clampedLevel - minDb) / (maxDb - minDb)
        
        // Use non-linear mapping for better visual effect
        let height = minHeight + (pow(CGFloat(normalizedLevel), 0.7) * (maxHeight - minHeight))
        
        return height
    }
}

// MARK: - Supporting Types

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        super.init()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}

// MARK: - Preview

struct VoiceProfileRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceProfileRecordingView()
    }
} 