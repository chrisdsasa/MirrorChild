import SwiftUI
import ReplayKit

struct BroadcastScreenView: View {
    @StateObject private var broadcastManager = BroadcastManager.shared
    @StateObject private var coordinatorService = CaptureCoordinatorService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAPIKeyAlert = false
    @State private var apiKeyInput = ""
    @State private var showingResponseView = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
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
                
                // Status indicators
                VStack(spacing: DesignSystem.Layout.spacingMedium) {
                    // 广播状态
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
                    
                    // 后台录制状态
                    HStack(spacing: DesignSystem.Layout.spacingMedium) {
                        Circle()
                            .fill(coordinatorService.isBackgroundCapturingActive ? 
                                  DesignSystem.Colors.success : DesignSystem.Colors.error)
                            .frame(width: 10, height: 10)
                            .opacity(coordinatorService.status == .processing ? 0.5 : 1.0)
                            .animation(coordinatorService.status == .capturing ? Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: coordinatorService.status == .capturing)
                        
                        Text(statusText)
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
                }
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
                    } else if coordinatorService.status == .capturing || coordinatorService.status == .processing {
                        backgroundCaptureStatusView
                    } else {
                        emptyPreviewState
                    }
                }
                .frame(height: 350)
                .cardStyle()
                .padding(.horizontal, DesignSystem.Layout.spacingLarge)
                
                // Action buttons
                VStack(spacing: DesignSystem.Layout.spacingMedium) {
                    // 广播按钮
                    BroadcastPickerRepresentable()
                        .frame(width: 200, height: 50)
                    
                    // 后台录制按钮
                    if coordinatorService.status == .capturing {
                        Button(action: stopBackgroundCapture) {
                            HStack {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 16))
                                Text("Stop & Analyze")
                                    .fontWeight(.semibold)
                            }
                            .frame(width: 200, height: 50)
                            .foregroundColor(.white)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(25)
                        }
                    } else if coordinatorService.status == .processing {
                        Button(action: {}) {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                                Text("Processing...")
                                    .fontWeight(.medium)
                            }
                            .frame(width: 200, height: 50)
                            .foregroundColor(.white)
                            .background(Color.gray)
                            .cornerRadius(25)
                        }
                        .disabled(true)
                    } else {
                        Button(action: startBackgroundCapture) {
                            HStack {
                                Image(systemName: "record.circle")
                                    .font(.system(size: 16))
                                Text("Background Recording")
                                    .fontWeight(.semibold)
                            }
                            .frame(width: 200, height: 50)
                            .foregroundColor(.white)
                            .background(coordinatorService.hasAPIKey ? DesignSystem.Colors.accent : Color.gray)
                            .cornerRadius(25)
                        }
                        .disabled(!coordinatorService.hasAPIKey)
                    }
                    
                    // 显示上次分析结果按钮
                    if coordinatorService.latestResponse != nil && coordinatorService.status == .idle {
                        Button(action: { showingResponseView = true }) {
                            HStack {
                                Image(systemName: "eye")
                                    .font(.system(size: 14))
                                Text("View Last Analysis")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(DesignSystem.Colors.accent)
                        }
                        .padding(.top, 4)
                    }
                    
                    // API Key信息
                    if !coordinatorService.hasAPIKey {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.system(size: 10))
                            
                            Text("OpenAI API Key Required")
                                .font(.system(size: 12))
                            
                            Button(action: { showingAPIKeyAlert = true }) {
                                Text("Set Key")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .padding(.top, 4)
                    }
                }
                .padding(.top, DesignSystem.Layout.spacingMedium)
                
                Spacer()
            }
            .padding(.vertical)
        }
        .alert(isPresented: $showingError) {
            Alert(title: Text("Error"), 
                  message: Text(errorMessage ?? "An unknown error occurred"),
                  dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showingAPIKeyAlert) {
            apiKeyInputView
        }
        .sheet(isPresented: $showingResponseView) {
            if let response = coordinatorService.latestResponse {
                ResponseDetailView(response: response)
                    .preferredColorScheme(.light)
            }
        }
        .onAppear {
            checkAPIKeyStatus()
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        switch coordinatorService.status {
        case .idle:
            return coordinatorService.isBackgroundCapturingActive ? "Ready" : "Background Recording Off"
        case .capturing:
            if let startTime = coordinatorService.captureStartTime {
                let interval = Date().timeIntervalSince(startTime)
                let minutes = Int(interval) / 60
                let seconds = Int(interval) % 60
                return "Recording \(String(format: "%02d:%02d", minutes, seconds))"
            } else {
                return "Recording..."
            }
        case .processing:
            return "Processing Data \(Int(coordinatorService.processingProgress * 100))%"
        case .error:
            return "Error Occurred"
        }
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
    
    private var backgroundCaptureStatusView: some View {
        VStack(spacing: DesignSystem.Layout.spacingLarge) {
            if coordinatorService.status == .capturing {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                    .opacity(0.8)
                    .animation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: true)
                
                Text("Background screen recording is active\nVoice to text also enabled")
                    .font(DesignSystem.Typography.subtitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else if coordinatorService.status == .processing {
                VStack {
                    ProgressView(value: coordinatorService.processingProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 200)
                        .tint(DesignSystem.Colors.accent)
                    
                    Text("\(Int(coordinatorService.processingProgress * 100))%")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.top, 4)
                }
                
                Text("Analyzing screen data with OpenAI...")
                    .font(DesignSystem.Typography.subtitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
    
    private var emptyPreviewState: some View {
        VStack(spacing: DesignSystem.Layout.spacingLarge) {
            Image(systemName: "display")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            Text("Choose an option below to start sharing or recording your screen")
                .font(DesignSystem.Typography.subtitle)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // API密钥输入视图
    private var apiKeyInputView: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Please enter your OpenAI API Key")
                    .font(DesignSystem.Typography.subtitle)
                    .padding(.top)
                
                Text("The API key will be stored securely on your device")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                SecureField("API Key", text: $apiKeyInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal)
                
                Button(action: saveAPIKey) {
                    Text("Save")
                        .fontWeight(.semibold)
                        .frame(minWidth: 150, minHeight: 44)
                        .foregroundColor(.white)
                        .background(apiKeyInput.isEmpty ? Color.gray : DesignSystem.Colors.accent)
                        .cornerRadius(22)
                }
                .disabled(apiKeyInput.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("API Key Setup", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                showingAPIKeyAlert = false
                apiKeyInput = ""
            })
        }
    }
    
    // MARK: - Actions
    
    private func startBackgroundCapture() {
        // 检查API密钥
        if !coordinatorService.hasAPIKey {
            errorMessage = "Please set an OpenAI API key first"
            showingError = true
            return
        }
        
        // 开始录制
        coordinatorService.startBackgroundCapture { success, error in
            if !success {
                errorMessage = error?.localizedDescription ?? "Could not start recording"
                showingError = true
            }
        }
    }
    
    private func stopBackgroundCapture() {
        coordinatorService.stopCaptureAndProcess { result in
            switch result {
            case .success(_):
                // 成功后显示响应视图
                showingResponseView = true
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    // 保存API密钥
    private func saveAPIKey() {
        guard !apiKeyInput.isEmpty else { return }
        
        coordinatorService.setAPIKey(apiKeyInput)
        apiKeyInput = ""
        showingAPIKeyAlert = false
    }
    
    // 检查API密钥状态
    private func checkAPIKeyStatus() {
        if !coordinatorService.hasAPIKey {
            // 如果是首次使用，可以决定是否自动弹出设置对话框
            // 在这里我们不自动弹出，让用户手动点击
        }
    }
}

// MARK: - UIKit Bridge

struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let pickerView = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
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
                button.layer.cornerRadius = 25
                button.layer.masksToBounds = true
                button.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
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

// MARK: - Response Detail View

// 响应详情视图
struct ResponseDetailView: View {
    let response: AssistantResponse
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 问题
                    VStack(alignment: .leading, spacing: 8) {
                        Text("您的问题:")
                            .font(.headline)
                        
                        Text(response.query)
                            .font(.body)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // 响应
                    VStack(alignment: .leading, spacing: 8) {
                        Text("助手回答:")
                            .font(.headline)
                        
                        Text(response.response)
                            .font(.body)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // 截图展示
                    if !response.screenshotURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("屏幕截图:")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(response.screenshotURLs, id: \.self) { url in
                                        ScreenshotThumbnail(url: url)
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitle("分析结果", displayMode: .inline)
        }
    }
}

// 截图缩略图组件
struct ScreenshotThumbnail: View {
    let url: URL
    @State private var image: UIImage?
    @State private var showFullScreen = false
    
    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 220)
                    .cornerRadius(8)
                    .onTapGesture {
                        showFullScreen = true
                    }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 220)
                    .cornerRadius(8)
                    .overlay(
                        ProgressView()
                    )
            }
        }
        .onAppear(perform: loadImage)
        .fullScreenCover(isPresented: $showFullScreen) {
            if let image = image {
                FullScreenImageView(image: image, isPresented: $showFullScreen)
            }
        }
    }
    
    private func loadImage() {
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url),
               let loadedImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = loadedImage
                }
            }
        }
    }
}

// 全屏图像查看器
struct FullScreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale *= delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                scale = scale == 1.0 ? 2.0 : 1.0
                            }
                        }
                }
            }
            .navigationBarItems(trailing: Button(action: {
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .padding()
            })
            .navigationBarTitleDisplayMode(.inline)
        }
    }
} 