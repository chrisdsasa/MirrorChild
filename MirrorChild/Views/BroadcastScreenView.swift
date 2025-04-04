import SwiftUI
import ReplayKit
import UserNotifications
import AVFoundation
import BackgroundTasks
import Photos

struct BroadcastScreenView: View {
    @StateObject private var broadcastManager = BroadcastManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    // 状态变量
    @State private var isRecording = false
    @State private var isPaused = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var errorMessage: String?
    @State private var capturedImage: UIImage?
    @State private var showPermissionAlert = false
    @State private var isRecordingInBackground = true  // 默认开启后台录制
    @State private var recordingURL: URL?
    @State private var showingSaveSuccess = false
    
    // 屏幕录制器
    private let screenRecorder = ScreenRecorder()
    
    // 后台任务ID
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // 音频播放器(用于保持后台运行)
    @State private var audioPlayer: AVAudioPlayer?
    
    // 任务标识符
    private let backgroundTaskIdentifier = "com.mirrochild.screencapture"
    
    var body: some View {
        ZStack {
            // Background
            Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Title bar with dismiss button
                HStack {
                    Text("屏幕录制")
                        .font(.appFont(size: 24, weight: .black))
                        .tracking(1)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    
                    Spacer()
                    
                    Button(action: {
                        // 退出前确保已停止录制，否则会在后台继续
                        if isRecording {
                            errorMessage = "请先停止录制再关闭此页面"
                            return
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal)
                
                // Status indicator
                HStack {
                    Circle()
                        .fill(isRecording ? 
                              (isPaused ? Color.orange.opacity(0.8) : Color.green.opacity(0.8)) : 
                              Color.red.opacity(0.5))
                        .frame(width: 12, height: 12)
                    
                    Text(isRecording ? 
                         (isPaused ? "已暂停: \(formatTime(recordingTime))" : "录制中: \(formatTime(recordingTime))\(isRecordingInBackground ? " (后台)" : "")") : 
                         "未开始录制")
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
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(10)
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
                
                // 后台录制开关
                Toggle("在后台继续录制", isOn: $isRecordingInBackground)
                    .padding(.horizontal, 20)
                    .padding(.top, 5)
                    .disabled(isRecording) // 录制开始后不允许更改
                
                // Recording controls
                HStack(spacing: 20) {
                    // 开始/停止按钮
                    Button(action: {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        HStack {
                            Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                                .font(.system(size: 22))
                            
                            Text(isRecording ? "停止录制" : "开始录制")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 20)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(isRecording ? Color.red : Color(red: 0.3, green: 0.3, blue: 0.8))
                        )
                        .frame(height: 60)
                    }
                    
                    // 保存按钮 - 仅当有录制视频时显示
                    if !isRecording, let _ = recordingURL {
                        Button(action: {
                            saveVideoToPhotoLibrary()
                        }) {
                            HStack {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.system(size: 22))
                                
                                Text("保存视频")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .padding(.vertical, 18)
                            .padding(.horizontal, 20)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(Color.blue)
                            )
                            .frame(height: 60)
                        }
                    }
                }
                .padding(.top, 5)
                .padding(.bottom, 10)
                
                // 错误消息显示
                if let message = errorMessage {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }
                
                Spacer()
            }
            .padding()
            
            // 保存成功提示
            if showingSaveSuccess {
                ZStack {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                        
                        Text("视频已保存到相册")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                .onAppear {
                    // 2秒后自动关闭提示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showingSaveSuccess = false
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background && isRecording && !isPaused {
                if isRecordingInBackground {
                    // 进入后台且要求后台录制
                    beginBackgroundTask()
                    playSilentAudio() // 播放静音音频保持应用活跃
                    showBackgroundRecordingNotification()
                } else {
                    // 不允许后台录制，停止录制
                    stopRecording()
                }
            } else if newPhase == .active && isRecording && backgroundTaskID != .invalid {
                // 回到前台，结束后台任务
                endBackgroundTask()
                stopSilentAudio() // 停止静音音频
            }
        }
        .onAppear {
            // 页面出现时自动请求权限
            checkScreenRecordingPermission()
            setupBackgroundTask() // 设置后台任务处理器
            
            // 设置计时器，用于更新录制时间
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if self.isRecording && !self.isPaused {
                    self.recordingTime += 1
                }
            }
            timer?.fire()
        }
        .onDisappear {
            // 页面消失时停止录制和计时器
            if isRecording {
                stopRecording()
            }
            
            timer?.invalidate()
            timer = nil
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("需要屏幕录制权限"),
                message: Text("请在设置中允许MirrorChild录制您的屏幕"),
                primaryButton: .default(Text("去设置"), action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }),
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    // MARK: - 辅助视图
    
    private var emptyPreviewState: some View {
        VStack(spacing: 16) {
            Image(systemName: "display")
                .font(.system(size: 60))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.8).opacity(0.5))
            
            Text(isRecording ? "录制中..." : "准备录制屏幕")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - 录制功能
    
    private func checkScreenRecordingPermission() {
        let recorder = RPScreenRecorder.shared()
        
        guard recorder.isAvailable else {
            errorMessage = "您的设备不支持屏幕录制"
            return
        }
    }
    
    private func startRecording() {
        // 创建临时文件URL用于保存录制内容
        let tempDirectory = FileManager.default.temporaryDirectory
        let outputURL = tempDirectory.appendingPathComponent("screen_recording_\(Date().timeIntervalSince1970).mp4")
        
        // 重置计时和状态
        recordingTime = 0
        isPaused = false
        
        // 开始录制
        screenRecorder.startRecording(to: outputURL) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "无法开始录制: \(error.localizedDescription)"
                    print("Failed to start recording: \(error.localizedDescription)")
                } else {
                    self.isRecording = true
                    self.recordingURL = outputURL
                    self.errorMessage = nil
                    
                    // 捕获一个预览图像
                    self.capturePreviewImage()
                }
            }
        }
    }
    
    private func stopRecording() {
        screenRecorder.stopRecording { url, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "停止录制时发生错误: \(error.localizedDescription)"
                    print("Failed to stop recording: \(error.localizedDescription)")
                } else if let url = url {
                    // 录制成功，保存URL以便稍后保存
                    self.recordingURL = url
                    print("Recording saved to: \(url.path)")
                }
                
                self.isRecording = false
                self.isPaused = false
            }
        }
    }
    
    private func capturePreviewImage() {
        // 使用截图来获取预览
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                let screenshot = renderer.image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                self.capturedImage = screenshot
            }
        }
    }
    
    private func saveVideoToPhotoLibrary() {
        guard let recordingURL = recordingURL else {
            errorMessage = "没有可保存的录制内容"
            return
        }
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            errorMessage = "录制文件不存在或已被移除"
            return
        }
        
        // 显示正在保存的提示
        DispatchQueue.main.async {
            self.errorMessage = "正在保存视频到相册..."
        }
        
        // 请求照片库权限
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            switch status {
            case .authorized, .limited:
                // 保存视频到照片库
                self.saveVideoFile(at: recordingURL)
            case .denied, .restricted:
                DispatchQueue.main.async {
                    self.errorMessage = "需要访问照片库权限才能保存视频。请在设置中允许MirrorChild访问照片库。"
                }
            case .notDetermined:
                // 权限状态尚未确定，这不应该发生，因为我们刚刚请求了权限
                DispatchQueue.main.async {
                    self.errorMessage = "无法确定照片库权限状态，请重试"
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.errorMessage = "未知错误，无法保存视频"
                }
            }
        }
    }
    
    private func saveVideoFile(at videoURL: URL) {
        // 创建一个临时文件拷贝，避免访问权限问题
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = "temp_video_\(Date().timeIntervalSince1970).mp4"
        let tempFileURL = tempDir.appendingPathComponent(tempFileName)
        
        do {
            // 如果临时文件已存在，先删除
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
            
            // 复制视频文件到临时目录
            try FileManager.default.copyItem(at: videoURL, to: tempFileURL)
            
            // 在主线程更新UI并执行保存操作
            DispatchQueue.main.async {
                PHPhotoLibrary.shared().performChanges({
                    // 创建视频资源
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempFileURL)
                }) { success, error in
                    // 保存完成后删除临时文件
                    try? FileManager.default.removeItem(at: tempFileURL)
                    
                    DispatchQueue.main.async {
                        if success {
                            self.showingSaveSuccess = true
                            self.errorMessage = nil
                            
                            // 2秒后恢复默认状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                self.errorMessage = nil
                            }
                        } else {
                            if let error = error {
                                print("保存视频错误: \(error.localizedDescription)")
                                self.errorMessage = "保存视频失败: \(error.localizedDescription)"
                            } else {
                                self.errorMessage = "保存视频失败，请重试"
                            }
                        }
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                print("处理视频文件错误: \(error.localizedDescription)")
                self.errorMessage = "处理视频文件失败: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - 后台任务处理
    
    private func setupBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            // 这里处理后台任务
            print("后台任务被激活")
            task.setTaskCompleted(success: true)
        }
    }
    
    private func beginBackgroundTask() {
        // 结束之前的后台任务（如果有）
        endBackgroundTask()
        
        // 开始一个新的后台任务
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [self] in
            // 这是后台任务即将过期的回调
            print("屏幕录制后台任务即将过期")
            self.endBackgroundTask()
        }
        
        print("已开始屏幕录制后台任务，ID: \(backgroundTaskID)")
    }
    
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        print("结束屏幕录制后台任务，ID: \(backgroundTaskID)")
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
    
    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60) // 60秒后可以开始执行
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("后台任务已安排")
        } catch {
            print("无法安排后台任务: \(error)")
        }
    }
    
    // MARK: - 后台播放静音音频以保持应用活跃
    
    private func playSilentAudio() {
        guard audioPlayer == nil else { return }
        
        // 尝试加载静音音频文件
        guard let audioFileURL = Bundle.main.url(forResource: "silence", withExtension: "mp3") else {
            print("找不到静音音频文件")
            return
        }
        
        do {
            // 配置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // 创建音频播放器
            audioPlayer = try AVAudioPlayer(contentsOf: audioFileURL)
            audioPlayer?.numberOfLoops = -1 // 无限循环
            audioPlayer?.volume = 0.01 // 几乎无声
            audioPlayer?.play()
            
            print("开始播放静音音频以保持后台活跃")
        } catch {
            print("无法配置音频播放: \(error)")
        }
    }
    
    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        // 恢复音频会话
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("无法重置音频会话: \(error)")
        }
    }
    
    // MARK: - 后台通知
    
    private func showBackgroundRecordingNotification() {
        let content = UNMutableNotificationContent()
        content.title = "屏幕录制进行中"
        content.body = "MirrorChild正在后台继续录制屏幕"
        content.sound = .none
        
        // 立即触发通知
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "backgroundScreenRecording", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送后台屏幕录制通知失败: \(error)")
            }
        }
    }
    
    // MARK: - 辅助函数
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) / 60 % 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
} 
