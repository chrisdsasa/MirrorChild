import SwiftUI
import ReplayKit
import UserNotifications
import AVFoundation
import BackgroundTasks

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
                    // 暂停/恢复按钮
                    Button(action: {
                        if isRecording {
                            if isPaused {
                                resumeRecording()
                            } else {
                                pauseRecording()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                                .font(.system(size: 22))
                            
                            Text(isPaused ? "恢复" : "暂停")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 20)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(isPaused ? Color.blue : Color.orange)
                        )
                        .frame(height: 60)
                    }
                    .disabled(!isRecording)
                    .opacity(isRecording ? 1.0 : 0.5)
                    
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
        }
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background && isRecording && !isPaused {
                if isRecordingInBackground {
                    // 进入后台且要求后台录制
                    beginBackgroundTask()
                    playSilentAudio() // 播放静音音频保持应用活跃
                    scheduleBackgroundTask() // 安排后台任务
                    showBackgroundRecordingNotification()
                } else {
                    // 不允许后台录制，暂停录制
                    pauseRecording()
                }
            } else if newPhase == .active && isRecording && backgroundTaskID != .invalid {
                // 回到前台，结束后台任务
                endBackgroundTask()
                stopSilentAudio() // 停止静音音频
            }
        }
        .onAppear {
            // 页面出现时自动请求权限并开始录制
            setupBackgroundTask() // 设置后台任务处理器
            requestPermissionAndStartRecording()
        }
        .onDisappear {
            if isRecording && !isRecordingInBackground {
                stopRecording()
            }
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
    
    private func requestPermissionAndStartRecording() {
        let recorder = RPScreenRecorder.shared()
        
        guard recorder.isAvailable else {
            errorMessage = "您的设备不支持屏幕录制"
            return
        }
        
        // 配置音频会话
        setupAudioSession()
        
        // 检查是否已经在录制
        if recorder.isRecording {
            isRecording = true
            return
        }
        
        // 请求权限并开始录制
        recorder.isMicrophoneEnabled = false
        recorder.startCapture { (buffer, bufferType, error) in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "录制错误: \(error.localizedDescription)"
                    self.isRecording = false
                }
                return
            }
            
            // 只处理视频帧
            if bufferType == .video {
                self.processVideoFrame(buffer)
            }
        } completionHandler: { (error) in
            if let error = error {
                DispatchQueue.main.async {
                    if (error as NSError).code == RPRecordingErrorCode.userDeclined.rawValue {
                        self.showPermissionAlert = true
                    } else {
                        self.errorMessage = "无法启动录制: \(error.localizedDescription)"
                    }
                    self.isRecording = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isRecording = true
                    self.isPaused = false
                    self.recordingTime = 0
                    self.errorMessage = nil
                    
                    // 开始计时器
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                        if !self.isPaused {
                            self.recordingTime += 0.1
                        }
                    }
                    
                    // 确保计时器在后台也能运行
                    RunLoop.current.add(self.timer!, forMode: .common)
                }
            }
        }
    }
    
    private func startRecording() {
        requestPermissionAndStartRecording()
    }
    
    private func pauseRecording() {
        // 暂停录制 - 注意RPScreenRecorder没有内置暂停功能，我们只是暂停计时器和UI显示
        isPaused = true
    }
    
    private func resumeRecording() {
        // 恢复录制
        isPaused = false
    }
    
    private func stopRecording() {
        let recorder = RPScreenRecorder.shared()
        
        // 结束后台任务(如果有)
        if backgroundTaskID != .invalid {
            endBackgroundTask()
        }
        
        // 停止静音音频播放
        stopSilentAudio()
        
        if recorder.isRecording {
            recorder.stopCapture { (error) in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "停止录制失败: \(error.localizedDescription)"
                    }
                    self.isRecording = false
                    self.isPaused = false
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 如果暂停了，不处理新帧
        if isPaused {
            return
        }
        
        // 每隔一段时间更新预览图像
        DispatchQueue.main.async {
            if Int(self.recordingTime * 10) % 20 == 0 { // 大约每2秒更新一次
                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    self.capturedImage = UIImage(cgImage: cgImage)
                    
                    // 后台录制时保存截图到文件系统
                    if self.isRecordingInBackground && !self.isPaused {
                        self.saveScreenshotToFile(UIImage(cgImage: cgImage))
                    }
                }
            }
        }
    }
    
    // MARK: - 后台任务处理
    
    private func beginBackgroundTask() {
        // 如果已经有一个后台任务，先结束它
        endBackgroundTask()
        
        // 开始一个新的后台任务
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            // 后台任务即将过期的回调
            print("屏幕录制后台任务即将过期")
            self.scheduleBackgroundTask() // 尝试安排新的后台任务
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
    
    // 设置后台任务处理器
    private func setupBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundTask(task: task as! BGProcessingTask)
        }
    }
    
    // 安排后台任务
    private func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("后台任务已安排")
        } catch {
            print("无法安排后台任务: \(error)")
        }
    }
    
    // 处理后台任务
    private func handleBackgroundTask(task: BGProcessingTask) {
        // 确保任务完成前不会被系统终止
        task.expirationHandler = {
            print("后台任务即将过期")
            task.setTaskCompleted(success: false)
        }
        
        // 如果我们正在录制，并且处于后台，则保持活跃并捕获更多帧
        if isRecording && !isPaused && isRecordingInBackground {
            print("后台任务执行中 - 继续录制")
            task.setTaskCompleted(success: true)
            
            // 再次安排后台任务
            scheduleBackgroundTask()
        } else {
            task.setTaskCompleted(success: true)
        }
    }
    
    // 配置音频会话以支持后台播放
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("设置音频会话失败: \(error)")
        }
    }
    
    // 播放静音音频以保持应用在后台活跃
    private func playSilentAudio() {
        guard audioPlayer == nil else { return }
        
        // 如果没有找到静音音频文件，就直接创建内存音频
        createSilentAudio()
    }
    
    // 创建内存中的静音音频（如果资源文件不可用）
    private func createSilentAudio() {
        // 创建5秒静音PCM数据
        let sampleRate = 8000
        let duration = 5.0
        let samples = Int(duration * Double(sampleRate))
        let buffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!, frameCapacity: AVAudioFrameCount(samples))
        
        if let channelData = buffer?.floatChannelData {
            // 填充静音数据
            for i in 0..<Int(buffer!.frameCapacity) {
                channelData[0][i] = 0.0
            }
            buffer?.frameLength = buffer!.frameCapacity
            
            // 创建播放器
            do {
                // 旧版iOS使用这种初始化方式
                if #available(iOS 15.0, *) {
                    let player = try AVAudioPlayer(audioFormat: buffer!.format, buffer: buffer!)
                    player.numberOfLoops = -1 // 无限循环
                    player.volume = 0.01
                    player.prepareToPlay()
                    player.play()
                    self.audioPlayer = player
                } else {
                    // iOS 15之前需要将PCM数据转换为Data
                    let audioFormat = buffer!.format
                    let audioBuffer = buffer!
                
                    
                    // 创建Data包装PCM数据
                    let channelCount = Int(audioFormat.channelCount)
                    let frameLength = Int(audioBuffer.frameLength)
                    let bytesPerFrame = audioFormat.streamDescription.pointee.mBytesPerFrame
                    let dataSize = frameLength * Int(bytesPerFrame)
                    var audioData = Data(count: dataSize)
                    
                    // 将PCM数据复制到Data中
                    audioData.withUnsafeMutableBytes { ptr in
                        for channel in 0..<channelCount {
                            let channelData = audioBuffer.floatChannelData![channel]
                            for frame in 0..<frameLength {
                                // 简单地将浮点样本转换为16位PCM
                                let offset = frame * channelCount + channel
                                let sample = Int16(channelData[frame] * 32767.0)
                                ptr.storeBytes(of: sample, toByteOffset: offset * 2, as: Int16.self)
                            }
                        }
                    }
                    
                    // 使用Data创建AVAudioPlayer
                    let player = try AVAudioPlayer(data: audioData)
                    player.numberOfLoops = -1
                    player.volume = 0.01
                    player.prepareToPlay()
                    player.play()
                    self.audioPlayer = player
                }
                
                print("开始播放内存生成的静音音频")
            } catch {
                print("创建静音音频播放器失败: \(error)")
            }
        }
    }
    
    // 停止播放静音音频
    private func stopSilentAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    // 显示后台录制通知
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
    
    // 保存截图到文件系统
    private func saveScreenshotToFile(_ image: UIImage) {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        // 创建截图目录
        let screenshotsDirectory = documentsDirectory.appendingPathComponent("Screenshots")
        if !FileManager.default.fileExists(atPath: screenshotsDirectory.path) {
            try? FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
        }
        
        // 创建文件名：timestamp.jpg
        let timestamp = Date().timeIntervalSince1970
        let fileName = "\(Int(timestamp)).jpg"
        let fileURL = screenshotsDirectory.appendingPathComponent(fileName)
        
        // 保存图像
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
            print("保存截图到: \(fileURL.path)")
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let tenths = Int((timeInterval - Double(Int(timeInterval))) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
} 
