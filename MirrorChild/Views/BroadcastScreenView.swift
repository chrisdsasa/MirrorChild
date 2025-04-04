import SwiftUI
import ReplayKit

struct BroadcastScreenView: View {
    @StateObject private var broadcastManager = BroadcastManager.shared
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Title
                Text("screenCaptureTitle".localized)
                    .font(.appFont(size: 24, weight: .black))
                    .tracking(1)
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    .padding(.top, 20)
                
                // Status indicator
                HStack {
                    Circle()
                        .fill(broadcastManager.isBroadcasting ? 
                              Color.green.opacity(0.8) : Color.red.opacity(0.5))
                        .frame(width: 12, height: 12)
                    
                    Text(broadcastManager.isBroadcasting ? 
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
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
                .padding(.horizontal, 20)
                
                // Broadcast picker - production-ready implementation
                BroadcastPickerRepresentable()
                    .frame(width: 200, height: 60)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                
                Spacer()
            }
            .padding()
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Subviews
    
    private var waitingForFramesView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 10)
            
            Text("capturingScreen".localized)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var frameInfosView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(broadcastManager.frameInfos, id: \.self) { frameInfo in
                    Text(frameInfo)
                        .font(.system(size: 14, weight: .regular))
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.95, green: 0.95, blue: 0.98))
                        )
                        .padding(.horizontal)
                }
            }
        }
    }
    
    private var emptyPreviewState: some View {
        VStack(spacing: 16) {
            Image(systemName: "display")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.8).opacity(0.5))
            
            Text("tapToBroadcast".localized)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - UIKit Bridge

struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        // 获取最简单的广播选择器视图
        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 200, height: 60))
        pickerView.preferredExtension = nil  // 不指定，让系统自动选择
        pickerView.showsMicrophoneButton = false
        
        // 自定义按钮外观
        for subview in pickerView.subviews {
            if let button = subview as? UIButton {
                button.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 1.0)
                button.tintColor = .white
                button.setTitle("开始广播", for: .normal)
                button.layer.cornerRadius = 30
                button.frame = CGRect(x: 0, y: 0, width: 200, height: 60)
            }
        }
        
        pickerView.backgroundColor = .clear
        
        return pickerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 不需要更新
    }
} 