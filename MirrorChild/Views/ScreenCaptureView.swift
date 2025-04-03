import SwiftUI
import ReplayKit

struct ScreenCaptureView: View {
    @StateObject private var screenCaptureManager = ScreenCaptureManager.shared
    @State private var showingPermissionAlert = false
    @State private var alertMessage = ""
    @State private var showingSettingsAlert = false
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Title
                Text("screenCaptureTitle".localized)
                    .font(.system(size: 22, weight: .medium))
                    .tracking(1)
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    .padding(.top, 20)
                
                // Status indicator
                HStack {
                    Circle()
                        .fill(screenCaptureManager.isRecording ? 
                              Color.green.opacity(0.8) : Color.red.opacity(0.5))
                        .frame(width: 12, height: 12)
                    
                    Text(screenCaptureManager.isRecording ? 
                         "screenCaptureActive".localized : "screenCaptureInactive".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                
                // Preview area
                VStack {
                    if screenCaptureManager.isRecording {
                        screenPreviewGrid
                            .padding()
                    } else {
                        emptyPreviewState
                    }
                }
                .frame(height: 400)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 20)
                
                // Control buttons
                HStack(spacing: 30) {
                    // Start/Stop button if recording already started
                    if screenCaptureManager.isRecording {
                        Button(action: stopCapture) {
                            Text("stopCapture".localized)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 30)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.8))
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                    } else {
                        // Start capture button - always show this
                        Button(action: startCapture) {
                            Text("startCapture".localized)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.vertical, 14)
                                .padding(.horizontal, 30)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 0.5, green: 0.5, blue: 0.8))
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                    }
                }
                .padding(.top, 20)
                
                // Open settings button (if permission denied)
                if screenCaptureManager.permissionStatus == .denied {
                    Button(action: {
                        showingSettingsAlert = true
                    }) {
                        Text("openSettings".localized)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                            .padding(.top, 10)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .alert(isPresented: $showingPermissionAlert) {
            Alert(
                title: Text("permissionRequired".localized),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingSettingsAlert) {
            Alert(
                title: Text("openSettingsTitle".localized),
                message: Text("openSettingsMessage".localized),
                primaryButton: .default(Text("openSettingsButton".localized)) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private var screenPreviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(screenCaptureManager.previewFrames.indices, id: \.self) { index in
                Image(uiImage: screenCaptureManager.previewFrames[index])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // Empty placeholders to maintain grid layout
            ForEach(0..<(4 - screenCaptureManager.previewFrames.count), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
        }
    }
    
    private var emptyPreviewState: some View {
        VStack(spacing: 16) {
            Image(systemName: "display")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.8).opacity(0.5))
            
            if screenCaptureManager.permissionStatus == .denied {
                Text("permissionDeniedMessage".localized)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("tapToStartCapture".localized)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    private func startCapture() {
        // Direct start of screen capture which will trigger system permission dialog if needed
        screenCaptureManager.startCapture { success, error in
            if !success, let error = error {
                alertMessage = error.localizedDescription
                showingPermissionAlert = true
                
                // Update permission status if we got a permission error
                let nsError = error as NSError
                if nsError.domain == RPRecordingErrorDomain {
                    // Use the domain and error codes directly from NSError
                    if nsError.code == 1301 || // .userDeclined (1301)
                       nsError.code == 1302 {  // .noPermission (1302) 
                        screenCaptureManager.permissionStatus = .denied
                    }
                }
            }
        }
    }
    
    private func stopCapture() {
        screenCaptureManager.stopCapture()
    }
} 