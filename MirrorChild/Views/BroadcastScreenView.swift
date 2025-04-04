import SwiftUI
import ReplayKit

struct BroadcastScreenView: View {
    @StateObject private var broadcastManager = BroadcastManager.shared
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
                    Text("Screen Sharing")
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
                        .fill(broadcastManager.isBroadcasting ? 
                              DesignSystem.Colors.success : DesignSystem.Colors.error)
                        .frame(width: 10, height: 10)
                    
                    Text(broadcastManager.isBroadcasting ? 
                         "Screen Sharing Active" : "Screen Sharing Inactive")
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
                    if broadcastManager.isBroadcasting {
                        if broadcastManager.frameInfos.isEmpty {
                            waitingForFramesView
                        } else {
                            frameInfosView
                                .padding()
                        }
                    } else {
                        emptyPreviewState
                    }
                }
                .frame(height: 400)
                .cardStyle()
                .padding(.horizontal, DesignSystem.Layout.spacingLarge)
                
                // Broadcast picker - production-ready implementation
                BroadcastPickerRepresentable()
                    .frame(width: 200, height: 60)
                    .padding(.top, DesignSystem.Layout.spacingLarge)
                
                Spacer()
            }
            .padding(.vertical)
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Subviews
    
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
    
    private var frameInfosView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Layout.spacingSmall) {
                ForEach(broadcastManager.frameInfos, id: \.self) { frameInfo in
                    Text(frameInfo)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(DesignSystem.Layout.spacingSmall)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusSmall)
                                .fill(DesignSystem.Colors.surfaceSecondary)
                        )
                        .padding(.horizontal, DesignSystem.Layout.spacingSmall)
                }
            }
            .padding(DesignSystem.Layout.spacingSmall)
        }
    }
    
    private var emptyPreviewState: some View {
        VStack(spacing: DesignSystem.Layout.spacingLarge) {
            Image(systemName: "display")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            Text("Tap the button below to start sharing your screen")
                .font(DesignSystem.Typography.subtitle)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - UIKit Bridge

struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 200, height: 60))
        pickerView.preferredExtension = nil
        pickerView.showsMicrophoneButton = false
        
        // Custom appearance
        for subview in pickerView.subviews {
            if let button = subview as? UIButton {
                // Use our accent color from design system
                button.backgroundColor = UIColor(
                    red: 0.45,
                    green: 0.45, 
                    blue: 0.85,
                    alpha: 1.0
                )
                button.tintColor = .white
                button.setTitle("Start Broadcast", for: .normal)
                button.layer.cornerRadius = 30
                button.layer.masksToBounds = true
                button.frame = CGRect(x: 0, y: 0, width: 200, height: 60)
            }
        }
        
        pickerView.backgroundColor = .clear
        
        return pickerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Nothing to update
    }
}

// MARK: - Preview

struct BroadcastScreenView_Previews: PreviewProvider {
    static var previews: some View {
        BroadcastScreenView()
    }
} 