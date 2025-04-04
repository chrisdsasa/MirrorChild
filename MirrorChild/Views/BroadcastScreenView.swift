import SwiftUI
import ReplayKit

struct BroadcastScreenView: View {
    @StateObject private var broadcastManager = BroadcastManager.shared
    @Environment(\.dismiss) private var dismiss
    
    // 状态变量
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var errorMessage: String?
    @State private var capturedImage: UIImage?
    @State private var showPermissionAlert = false
    
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
                        if isRecording {
                            stopRecording()
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
                              Color.green.opacity(0.8) : Color.red.opacity(0.5))
                        .frame(width: 12, height: 12)
                    
                    Text(isRecording ? 
                         "录制中: \(formatTime(recordingTime))" : "未开始录制")
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
                
                // Recording button
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
                    .padding(.horizontal, 25)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(isRecording ? Color.red : Color(red: 0.3, green: 0.3, blue: 0.8))
                    )
                    .frame(width: 240, height: 60)
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
                
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
        .onDisappear {
            if isRecording {
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
            
            Text("点击下方按钮开始录制屏幕")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - 录制功能
    
    private func startRecording() {
        let recorder = RPScreenRecorder.shared()
        
        guard recorder.isAvailable else {
            errorMessage = "您的设备不支持屏幕录制"
            return
        }
        
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
                    self.recordingTime = 0
                    self.errorMessage = nil
                    
                    // 开始计时器
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                        self.recordingTime += 0.1
                    }
                }
            }
        }
    }
    
    private func stopRecording() {
        let recorder = RPScreenRecorder.shared()
        
        if recorder.isRecording {
            recorder.stopCapture { (error) in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "停止录制失败: \(error.localizedDescription)"
                    }
                    self.isRecording = false
                    self.timer?.invalidate()
                    self.timer = nil
                }
            }
        }
    }
    
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 每隔一段时间更新预览图像
        DispatchQueue.main.async {
            if Int(self.recordingTime * 10) % 20 == 0 { // 大约每2秒更新一次
                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                let context = CIContext()
                if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                    self.capturedImage = UIImage(cgImage: cgImage)
                }
            }
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let tenths = Int((timeInterval - Double(Int(timeInterval))) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
} 
