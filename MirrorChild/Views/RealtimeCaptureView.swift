import SwiftUI
import UIKit
import Vision

struct RealtimeCaptureView: View {
    @StateObject private var captureService = RealtimeCaptureService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showText = true
    @State private var showElements = true
    @State private var captureRate: Double = 2.0
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [
                    DesignSystem.Colors.surface,
                    DesignSystem.Colors.surfaceSecondary
                ]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Layout.spacingMedium) {
                // 顶部导航栏
                HStack {
                    Text("Realtime Screen Capture")
                        .font(DesignSystem.Typography.title)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        // 如果正在捕获，先停止
                        if captureService.isCapturing {
                            captureService.stopCapture()
                        }
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
                
                // 状态指示器
                HStack(spacing: DesignSystem.Layout.spacingMedium) {
                    Circle()
                        .fill(captureService.isCapturing ? 
                              DesignSystem.Colors.success : DesignSystem.Colors.error)
                        .frame(width: 10, height: 10)
                        .opacity(captureService.isCapturing ? 1.0 : 0.5)
                        .animation(captureService.isCapturing ? 
                                  .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, 
                                  value: captureService.isCapturing)
                    
                    Text(captureService.isCapturing ? 
                         "Capturing active (\(String(format: "%.1f", captureRate)) fps)" : 
                         "Capture inactive")
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
                
                // 捕获和识别结果显示区域
                TabView(selection: $selectedTab) {
                    // 第一个标签页：捕获的帧
                    capturedFrameView
                        .tag(0)
                    
                    // 第二个标签页：识别的文本
                    recognizedTextView
                        .tag(1)
                    
                    // 第三个标签页：识别的UI元素
                    recognizedElementsView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle())
                .frame(height: 450)
                .padding(.horizontal, DesignSystem.Layout.spacingMedium)
                
                // 分页指示器
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(selectedTab == index ? 
                                  DesignSystem.Colors.accent : 
                                  DesignSystem.Colors.textTertiary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 4)
                
                // 控制按钮
                VStack(spacing: DesignSystem.Layout.spacingMedium) {
                    // 捕获速率滑块
                    HStack {
                        Text("Capture Rate:")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Slider(value: $captureRate, in: 0.5...5.0, step: 0.5)
                            .onChange(of: captureRate) { oldValue, newValue in
                                captureService.setCaptureRate(newValue)
                            }
                        
                        Text("\(String(format: "%.1f", captureRate)) fps")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .frame(width: 50)
                    }
                    .padding(.horizontal, DesignSystem.Layout.spacingLarge)
                    
                    // 主要动作按钮
                    HStack(spacing: DesignSystem.Layout.spacingLarge) {
                        // 开始/停止捕获按钮
                        Button(action: toggleCapture) {
                            HStack {
                                Image(systemName: captureService.isCapturing ? "stop.fill" : "play.fill")
                                    .font(.system(size: 16))
                                Text(captureService.isCapturing ? "Stop Capture" : "Start Capture")
                                    .fontWeight(.semibold)
                            }
                            .frame(width: 170, height: 50)
                            .foregroundColor(.white)
                            .background(captureService.isCapturing ? Color.red.opacity(0.8) : DesignSystem.Colors.accent)
                            .cornerRadius(25)
                        }
                        
                        // 处理开关
                        Toggle(isOn: $showText) {
                            Text("Process")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .onChange(of: showText) { oldValue, newValue in
                            captureService.setProcessingEnabled(newValue)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: DesignSystem.Colors.accent))
                        .padding(.trailing, DesignSystem.Layout.spacingMedium)
                    }
                }
                .padding(.top, DesignSystem.Layout.spacingSmall)
                
                Spacer()
            }
            .padding(.vertical)
        }
        .onAppear {
            // 设置初始捕获速率
            captureService.setCaptureRate(captureRate)
        }
        .alert(isPresented: $showingError) {
            Alert(title: Text("Error"), 
                  message: Text(errorMessage ?? "An unknown error occurred"),
                  dismissButton: .default(Text("OK")))
        }
        .preferredColorScheme(.light)
    }
    
    // MARK: - 子视图
    
    // 捕获的帧视图
    private var capturedFrameView: some View {
        VStack {
            if let image = captureService.lastCapturedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(DesignSystem.Layout.radiusMedium)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .padding()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusMedium)
                        .fill(DesignSystem.Colors.surfaceSecondary)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    if captureService.isCapturing {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else {
                        VStack(spacing: DesignSystem.Layout.spacingMedium) {
                            Image(systemName: "display")
                                .font(.system(size: 50))
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                            
                            Text("Tap 'Start Capture' to begin")
                                .font(DesignSystem.Typography.subtitle)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding()
            }
            
            Text("Screen Capture")
                .font(DesignSystem.Typography.subtitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.bottom)
        }
        .tag(0)
    }
    
    // 识别的文本视图
    private var recognizedTextView: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if captureService.recognizedText.isEmpty {
                        HStack {
                            Spacer()
                            
                            if captureService.isCapturing && showText {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    
                                    Text("Waiting for text...")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            } else {
                                Text("No text recognized yet")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 100)
                    } else {
                        Text(captureService.recognizedText)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusMedium)
                    .fill(DesignSystem.Colors.surfaceSecondary)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding()
            
            Text("Recognized Text")
                .font(DesignSystem.Typography.subtitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.bottom)
        }
        .tag(1)
    }
    
    // 识别的UI元素视图
    private var recognizedElementsView: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if captureService.recognizedElements.isEmpty {
                        HStack {
                            Spacer()
                            
                            if captureService.isCapturing && showText {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    
                                    Text("Analyzing UI elements...")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            } else {
                                Text("No UI elements detected")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                            
                            Spacer()
                        }
                        .padding(.top, 100)
                    } else {
                        ForEach(captureService.recognizedElements, id: \.self) { element in
                            HStack {
                                Text(element)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Spacer()
                                
                                // 根据文本推测可能的UI元素类型
                                Image(systemName: guessElementType(for: element))
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusSmall)
                                    .fill(DesignSystem.Colors.glassMaterial)
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.radiusMedium)
                    .fill(DesignSystem.Colors.surfaceSecondary)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
            .padding()
            
            Text("Detected UI Elements")
                .font(DesignSystem.Typography.subtitle)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .padding(.bottom)
        }
        .tag(2)
    }
    
    // MARK: - 动作方法
    
    // 切换捕获状态
    private func toggleCapture() {
        if captureService.isCapturing {
            captureService.stopCapture()
        } else {
            captureService.startCapture { success, error in
                if !success, let error = error {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    // 根据文本猜测可能的UI元素类型
    private func guessElementType(for text: String) -> String {
        let lowercasedText = text.lowercased()
        
        if lowercasedText.contains("button") || 
           lowercasedText.contains("tap") ||
           lowercasedText.contains("click") ||
           lowercasedText.contains("submit") ||
           lowercasedText.contains("log in") ||
           lowercasedText.contains("cancel") {
            return "square.and.arrow.up"
        } else if lowercasedText.contains("switch") || 
                  lowercasedText.contains("toggle") {
            return "switch.2"
        } else if lowercasedText.contains("slider") {
            return "slider.horizontal.3"
        } else if lowercasedText.contains("menu") || 
                  lowercasedText.contains("option") {
            return "list.bullet"
        } else if lowercasedText.contains("text") || 
                  lowercasedText.contains("input") ||
                  lowercasedText.contains("field") ||
                  lowercasedText.contains("enter") {
            return "textformat"
        } else {
            return "doc.text"
        }
    }
}

// MARK: - 预览

struct RealtimeCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        RealtimeCaptureView()
    }
} 