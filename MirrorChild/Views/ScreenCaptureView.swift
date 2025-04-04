import SwiftUI
import ReplayKit

struct ScreenCaptureView: View {
    @StateObject private var screenCaptureManager = ScreenCaptureManager.shared
    @State private var showingPermissionAlert = false
    @State private var alertMessage = ""
    @State private var showingSettingsAlert = false
    @State private var isRetrying = false
    @Environment(\.dismiss) private var dismiss
    
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
                    Text("Screen Capture")
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
                
                // Status indicator
                HStack(spacing: DesignSystem.Layout.spacingMedium) {
                    Circle()
                        .fill(screenCaptureManager.isRecording ? 
                              DesignSystem.Colors.success : DesignSystem.Colors.error)
                        .frame(width: 10, height: 10)
                    
                    Text(screenCaptureManager.isRecording ? 
                         "Screen Capture Active" : "Screen Capture Inactive")
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
                
                // Preview area
                Group {
                    if screenCaptureManager.isRecording {
                        if screenCaptureManager.previewFrames.isEmpty {
                            waitingForFramesView
                        } else {
                            screenPreviewGrid
                                .padding()
                        }
                    } else {
                        emptyPreviewState
                    }
                }
                .frame(height: 400)
                .cardStyle()
                .padding(.horizontal, DesignSystem.Layout.spacingLarge)
                
                // Control buttons
                if isRetrying {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(DesignSystem.Colors.accent)
                        .padding(.top, DesignSystem.Layout.spacingLarge)
                } else if screenCaptureManager.isRecording {
                    // Stop button
                    Button(action: stopCapture) {
                        Text("Stop Capture")
                            .font(DesignSystem.Typography.buttonPrimary)
                            .foregroundColor(.white)
                            .frame(width: 200)
                    }
                    .buttonStyle(DesignSystem.ButtonStyles.PrimaryButton())
                    .tint(DesignSystem.Colors.error)
                    .padding(.top, DesignSystem.Layout.spacingLarge)
                } else {
                    // Start capture button
                    Button(action: startCapture) {
                        Text("Start Capture")
                            .font(DesignSystem.Typography.buttonPrimary)
                            .foregroundColor(.white)
                            .frame(width: 200)
                    }
                    .buttonStyle(DesignSystem.ButtonStyles.PrimaryButton())
                    .padding(.top, DesignSystem.Layout.spacingLarge)
                }
                
                // Open settings button (if permission denied)
                if screenCaptureManager.permissionStatus == .denied {
                    Button(action: {
                        showingSettingsAlert = true
                    }) {
                        Text("Open Settings")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                    .buttonStyle(DesignSystem.ButtonStyles.SecondaryButton())
                    .padding(.top, DesignSystem.Layout.spacingMedium)
                }
                
                Spacer()
            }
            .padding(.vertical)
        }
        .alert(isPresented: $showingPermissionAlert) {
            Alert(
                title: Text("Permission Required"),
                message: Text("Screen capture permissions are required for this functionality."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showingSettingsAlert) {
            Alert(
                title: Text("Open Settings"),
                message: Text("Please enable screen recording access in Settings to use this feature."),
                primaryButton: .default(Text("Open Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onDisappear {
            // Always ensure we stop capturing when the view disappears
            if screenCaptureManager.isRecording {
                screenCaptureManager.stopCapture()
            }
        }
        .preferredColorScheme(.light)
    }
    
    private var waitingForFramesView: some View {
        VStack(spacing: DesignSystem.Layout.spacingLarge) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(DesignSystem.Colors.accent)
            
            Text("Capturing screen content...")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var screenPreviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Layout.spacingMedium) {
            ForEach(screenCaptureManager.previewFrames.indices, id: \.self) { index in
                Image(uiImage: screenCaptureManager.previewFrames[index])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusMedium))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusMedium)
                            .stroke(DesignSystem.Colors.textTertiary.opacity(0.2), lineWidth: 1)
                    )
                    .transition(.opacity)
                    .animation(.easeInOut, value: screenCaptureManager.previewFrames.count)
            }
            
            // Empty placeholders to maintain grid layout
            ForEach(0..<(4 - screenCaptureManager.previewFrames.count), id: \.self) { _ in
                RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusMedium)
                    .fill(DesignSystem.Colors.surfaceSecondary)
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusMedium)
                            .stroke(DesignSystem.Colors.textTertiary.opacity(0.1), lineWidth: 1)
                    )
            }
        }
    }
    
    private var emptyPreviewState: some View {
        VStack(spacing: DesignSystem.Layout.spacingLarge) {
            Image(systemName: "display")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            if screenCaptureManager.permissionStatus == .denied {
                Text("Screen recording permission denied")
                    .font(DesignSystem.Typography.subtitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if isRetrying {
                Text("Cleaning up previous session...")
                    .font(DesignSystem.Typography.subtitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("Tap the button below to start capturing your screen")
                    .font(DesignSystem.Typography.subtitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    private func startCapture() {
        // Set retrying flag to show progress
        isRetrying = true
        
        // Direct start of screen capture which will trigger system permission dialog if needed
        screenCaptureManager.startCapture { success, error in
            DispatchQueue.main.async {
                if !success, let error = error {
                    // Handle "already active" errors specially
                    let nsError = error as NSError
                    
                    if nsError.localizedDescription.contains("already active") {
                        // Wait and then automatically retry once
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            // Try again after a delay
                            screenCaptureManager.startCapture { retrySuccess, retryError in
                                DispatchQueue.main.async {
                                    isRetrying = false
                                    
                                    if !retrySuccess, let retryError = retryError {
                                        alertMessage = retryError.localizedDescription
                                        showingPermissionAlert = true
                                    }
                                }
                            }
                        }
                    } else {
                        // For other errors, show the alert
                        isRetrying = false
                        alertMessage = error.localizedDescription
                        showingPermissionAlert = true
                    }
                } else {
                    // Success or handling in the manager itself
                    isRetrying = false
                }
            }
        }
    }
    
    private func stopCapture() {
        screenCaptureManager.stopCapture()
    }
}

// MARK: - Preview

struct ScreenCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        ScreenCaptureView()
    }
} 