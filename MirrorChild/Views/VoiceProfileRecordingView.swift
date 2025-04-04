import SwiftUI
import AVFoundation

struct VoiceProfileRecordingView: View {
    @State private var isRecording = false
    @State private var permissionStatus: PermissionStatus = .undetermined
    
    enum PermissionStatus {
        case undetermined
        case granted
        case denied
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Voice Profile Recording")
                .font(.title)
                .padding()
            
            // Status display
            Text("Permission Status: \(permissionStatusText)")
                .padding()
            
            // Recording controls
            Button(action: {
                if permissionStatus == .granted {
                    toggleRecording()
                } else {
                    requestMicrophonePermission()
                }
            }) {
                Text(buttonText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(buttonColor)
                    .cornerRadius(10)
            }
            
            if permissionStatus == .denied {
                Button("Open Settings") {
                    openSettings()
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            checkMicrophonePermission()
        }
    }
    
    private var permissionStatusText: String {
        switch permissionStatus {
        case .undetermined:
            return "Not Determined"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        }
    }
    
    private var buttonText: String {
        if permissionStatus != .granted {
            return "Request Permission"
        }
        return isRecording ? "Stop Recording" : "Start Recording"
    }
    
    private var buttonColor: Color {
        if permissionStatus == .denied {
            return Color.gray
        }
        return isRecording ? Color.red : Color.blue
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        // Add your actual recording logic here
    }
    
    private func checkMicrophonePermission() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                permissionStatus = .granted
            case .denied:
                permissionStatus = .denied
                print("Microphone permission was denied")
            case .undetermined:
                permissionStatus = .undetermined
            @unknown default:
                permissionStatus = .undetermined
            }
        } else {
            // For iOS 16 and earlier
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                permissionStatus = .granted
            case .denied:
                permissionStatus = .denied
                print("Microphone permission was denied")
            case .undetermined:
                permissionStatus = .undetermined
            @unknown default:
                permissionStatus = .undetermined
            }
        }
    }
    
    private func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionStatus = granted ? .granted : .denied
                }
            }
        } else {
            // For iOS 16 and earlier
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.permissionStatus = granted ? .granted : .denied
                }
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct VoiceProfileRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        VoiceProfileRecordingView()
    }
} 