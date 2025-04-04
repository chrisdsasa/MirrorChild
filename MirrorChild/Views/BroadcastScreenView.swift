import SwiftUI
import ReplayKit

struct BroadcastScreenView: View {
    @StateObject private var broadcastManager = BroadcastManager.shared
    @State private var selectedFrameIndex: Int? = nil
    
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
                        // 显示实时捕获的画面
                        capturedFrameView
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
        .onAppear {
            // 加载已捕获的帧
            if broadcastManager.isBroadcasting {
                broadcastManager.loadAllCapturedFrames()
            }
        }
    }
    
    // MARK: - Subviews
    
    // 显示捕获的帧画面
    private var capturedFrameView: some View {
        VStack {
            if let currentFrame = broadcastManager.currentFrame {
                // 显示当前帧
                Image(uiImage: currentFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(8)
                    .padding()
                
                // 显示缩略图预览
                thumbnailsView
            } else if broadcastManager.isLoadingFrames {
                waitingForFramesView
            } else {
                waitingForFramesView
            }
        }
    }
    
    // 缩略图预览
    private var thumbnailsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<broadcastManager.capturedFrames.count, id: \.self) { index in
                    Image(uiImage: broadcastManager.capturedFrames[index])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selectedFrameIndex == index ? Color.blue : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedFrameIndex = index
                        }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 70)
        .padding(.bottom)
    }
    
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
        // 创建广播选择器视图
        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 200, height: 60))
        // 不指定特定扩展，使用系统可用的任何广播扩展
        pickerView.preferredExtension = nil
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
        
        // 添加观察者监听广播选择器视图窗口变化
        NotificationCenter.default.addObserver(forName: UIWindow.didBecomeVisibleNotification, object: nil, queue: .main) { notification in
            guard let window = notification.object as? UIWindow else { return }
            
            // 延迟一点执行，确保UI已完全加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 自动选择列表中的第一个应用，无论是哪个应用
                self.selectFirstApp(in: window)
            }
        }
        
        pickerView.backgroundColor = .clear
        return pickerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 不需要更新
    }
    
    // 递归查找并选择列表中的第一个应用
    private func selectFirstApp(in view: UIView) {
        // 检查每个子视图
        for subview in view.subviews {
            // 如果是表格视图，选择第一个单元格
            if let tableView = subview as? UITableView, tableView.numberOfRows(inSection: 0) > 0 {
                // 选择第一个可用的应用
                tableView.delegate?.tableView?(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
                return
            }
            
            // 对子视图递归查找
            selectFirstApp(in: subview)
        }
    }
} 