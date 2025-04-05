import SwiftUI
import ReplayKit
import AVKit

struct BroadcastScreenView: View {
    @StateObject private var broadcastManager = BroadcastManager.shared
    @State private var selectedFrameIndex: Int? = nil
    @State private var showVideoPlayer = false
    @State private var selectedVideo: RecordedVideo? = nil
    @State private var showSaveSuccess = false
    @State private var showSaveError = false
    @State private var errorMessage = ""
    
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
                
                // Status indicator with animated pulse effect
                HStack {
                    Circle()
                        .fill(broadcastManager.isBroadcasting ? 
                              Color.green.opacity(0.8) : Color.red.opacity(0.5))
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(broadcastManager.isBroadcasting ? Color.green : Color.red, lineWidth: 2)
                                .scaleEffect(broadcastManager.isBroadcasting ? 1.5 : 1.0)
                                .opacity(broadcastManager.isBroadcasting ? 0.0 : 0.5)
                                .animation(broadcastManager.isBroadcasting ? 
                                          Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true) : 
                                          .default, 
                                          value: broadcastManager.isBroadcasting)
                        )
                    
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
                    } else if !broadcastManager.recordedVideos.isEmpty {
                        // 显示录制的视频列表
                        recordedVideosView
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
                    .frame(width: 240, height: 60)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                
                Spacer()
            }
            .padding()
            
            // Video player sheet
            if showVideoPlayer, let video = selectedVideo {
                videoPlayerView(for: video)
            }
            
            // Toast messages
            if showSaveSuccess {
                toastView(message: "视频已保存到相册", success: true)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showSaveSuccess = false
                            }
                        }
                    }
            }
            
            if showSaveError {
                toastView(message: errorMessage, success: false)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showSaveError = false
                            }
                        }
                    }
            }
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
    
    // 显示录制的视频列表
    private var recordedVideosView: some View {
        VStack(spacing: 12) {
            Text("录制的视频")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                .padding(.top, 10)
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(broadcastManager.recordedVideos) { video in
                        videoItemView(video: video)
                            .onTapGesture {
                                selectedVideo = video
                                showVideoPlayer = true
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
    
    // 视频列表项视图
    private func videoItemView(video: RecordedVideo) -> some View {
        HStack(spacing: 12) {
            // 视频缩略图
            if let thumbnail = video.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.9, green: 0.9, blue: 0.95))
                    .frame(width: 80, height: 60)
                    .overlay(
                        Image(systemName: "video.fill")
                            .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.7))
                    )
            }
            
            // 视频信息
            VStack(alignment: .leading, spacing: 4) {
                Text(video.fileName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
                    .lineLimit(1)
                
                HStack {
                    Text(video.formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    
                    Text("•")
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                    
                    Text(video.formattedFileSize)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 16) {
                Button(action: {
                    saveVideoToPhotos(video: video)
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(Color(red: 0.455, green: 0.580, blue: 0.455))
                }
                
                Button(action: {
                    broadcastManager.deleteVideo(video: video)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(Color.red.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // 视频播放器视图
    private func videoPlayerView(for video: RecordedVideo) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    showVideoPlayer = false
                }
            
            VStack(spacing: 12) {
                // 标题栏
                HStack {
                    Text(video.fileName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        showVideoPlayer = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // 视频播放器
                VideoPlayer(player: AVPlayer(url: video.url))
                    .frame(height: 300)
                    .cornerRadius(12)
                
                // 操作按钮
                HStack(spacing: 20) {
                    Button(action: {
                        saveVideoToPhotos(video: video)
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存到相册")
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color(red: 0.455, green: 0.580, blue: 0.455))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showVideoPlayer = false
                        broadcastManager.deleteVideo(video: video)
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("删除视频")
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.red.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.vertical, 20)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
            )
            .padding(30)
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
                .foregroundColor(Color(red: 0.7, green: 0.8, blue: 0.7).opacity(0.5))
            
            Text("tapToBroadcast".localized)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // Toast 提示视图
    private func toastView(message: String, success: Bool) -> some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(success ? .green : .red)
                
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                Capsule()
                    .fill(Color(red: 0.2, green: 0.2, blue: 0.25))
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            )
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveVideoToPhotos(video: RecordedVideo) {
        broadcastManager.saveVideoToPhotos(videoURL: video.url) { success, error in
            if success {
                withAnimation {
                    showSaveSuccess = true
                }
            } else {
                errorMessage = error?.localizedDescription ?? "保存失败"
                withAnimation {
                    showSaveError = true
                }
            }
        }
    }
}

// MARK: - UIKit Bridge

struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        // 创建广播选择器视图
        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 200, height: 60))
        // 使用我们自己的广播扩展
        pickerView.preferredExtension = "name.KrypotoZ.MirrorChild.MirrorChildBroadcast"
        pickerView.showsMicrophoneButton = true
        
        // 自定义按钮外观
        for subview in pickerView.subviews {
            if let button = subview as? UIButton {
                button.backgroundColor = UIColor(red: 0.455, green: 0.580, blue: 0.455, alpha: 1.0)
                button.tintColor = .white
                button.setTitle("   开始/停止录制", for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .medium)
                button.titleLabel?.textAlignment = .center
                button.contentVerticalAlignment = .center
                button.layer.cornerRadius = 30
                button.frame = CGRect(x: 0, y: 0, width: 240, height: 60)
            }
        }
        
        // 添加观察者监听广播选择器视图窗口变化
        NotificationCenter.default.addObserver(forName: UIWindow.didBecomeVisibleNotification, object: nil, queue: .main) { notification in
            guard let window = notification.object as? UIWindow else { return }
            
            // 延迟一点执行，确保UI已完全加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 自动选择列表中的第一个应用，无论是哪个应用
                selectFirstApp(in: window)
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