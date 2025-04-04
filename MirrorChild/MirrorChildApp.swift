//
//  MirrorChildApp.swift
//  MirrorChild
//
//  Created by 赵嘉策 on 2025/4/3.
//

import SwiftUI
import CoreData
import Speech
import AVFoundation
import UserNotifications

// Define consistent accent color extension
extension Color {
    static let accentColor = Color(red: 0.45, green: 0.45, blue: 0.85)
}

// Add SplashScreenView definition before the MirrorChildApp struct
struct SplashScreenView: View {
    @State private var isActive = false
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.95, green: 0.95, blue: 0.98),
                    Color(red: 0.9, green: 0.9, blue: 0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App logo/icon
                Image(systemName: "person.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color.accentColor)
                    .padding()
                
                // App name
                Text("MirrorChild")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
                
                // Loading indicator
                ProgressView()
                    .scaleEffect(1.2)
                    .padding(.top, 30)
            }
        }
        .onAppear {
            // Simulate a splash screen delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Mark as having launched before
                hasLaunchedBefore = true
            }
        }
    }
}

@main
struct MirrorChildApp: App {
    let persistenceController = PersistenceController.shared

    // State for showing onboarding
    @State private var showOnboarding = false
    @State private var isLoading = true
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    
    // Environment scene phase to detect app lifecycle changes
    @Environment(\.scenePhase) var scenePhase
    
    // Only override accent color if the device is using Light Mode
    @Environment(\.colorScheme) var colorScheme
    
    init() {
        // 检查是否首次启动，如果是则显示引导页
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        _showOnboarding = State(initialValue: isFirstLaunch)
        
        // 首先进行基本的UI配置
        configureAppAppearance()
        
        // 将耗时操作放在异步线程中执行，避免阻塞主线程
        DispatchQueue.main.async {
            // 初始化默认设置，确保应用有基本配置
            UserDefaults.standard.set("shimmer", forKey: "selectedVoice")
            UserDefaults.standard.set(0.7, forKey: "temperature")
            
            // 手动清理可能导致启动延迟的缓存
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID + ".SplashDefaults")
            }
            
            // 创建默认用户资料（异步执行，不阻塞主线程）
            _ = PersistenceController.shared.saveUserProfile(
                name: "User",
                email: "",
                appleUserId: nil
            )
        }
        
        // 简化启动流程
        setupPermissions()
    }

    var body: some Scene {
        WindowGroup {
            // Handle simulator special case, showing simple view to ensure content is visible
            #if targetEnvironment(simulator)
            ZStack {
                // Simple background
                Color(red: 0.95, green: 0.95, blue: 0.98)
                    .ignoresSafeArea()
                    .onAppear {
                        print("Simulator view loaded")
                    }
                
                // Directly show content view
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .accentColor(Color.accentColor) // Set global accent color
                
                // If onboarding needed, show at top layer
                if showOnboarding {
                    SimpleOnboardingView(isPresented: $showOnboarding)
                        .transition(.opacity)
                        .zIndex(1) // Ensure on top
                        .animation(.easeInOut(duration: 0.5), value: showOnboarding)
                }
            }
            #else
            ZStack {
                // For real devices, show splash screen first if not launched before
                if !hasLaunchedBefore {
                    SplashScreenView()
                } else {
                    // Main content view
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .accentColor(Color.accentColor) // Set global accent color
                        .onAppear {
                            // App launched, can perform non-critical operations
                            print("Content view appeared")
                            
                            // Delay permission requests to avoid triggering at startup
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.requestPermissions()
                                self.setupPermissions() 
                            }
                        }
                        .onChange(of: scenePhase) { oldPhase, newPhase in
                            if newPhase == .active {
                                // App became active
                                print("App became active")
                            } else if newPhase == .inactive {
                                // App became inactive
                                print("App became inactive")
                            } else if newPhase == .background {
                                // App went to background
                                print("App went to background")
                            }
                        }
                    
                    // Overlay the onboarding view if needed
                    if showOnboarding {
                        SimpleOnboardingView(isPresented: $showOnboarding)
                            .transition(.opacity)
                            .zIndex(1) // Ensure it appears on top
                            .animation(.easeInOut(duration: 0.5), value: showOnboarding)
                    }
                }
            }
            #endif
        }
    }
    
    // MARK: - Helper Methods
    
    private func configureAppAppearance() {
        // Configure the global app appearance
        if #available(iOS 15.0, *) {
            let navigationBarAppearance = UINavigationBarAppearance()
            navigationBarAppearance.configureWithOpaqueBackground()
            navigationBarAppearance.backgroundColor = UIColor.systemBackground
            
            UINavigationBar.appearance().standardAppearance = navigationBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
            
            // Configure tab bar appearance if needed
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor.systemBackground
            
            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
        }
    }
    
    private func checkFirstLaunch() {
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunchedBefore {
            // This is the first launch
            print("First launch detected")
            
            // Initialize default settings
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            UserDefaults.standard.set("shimmer", forKey: "selectedVoice")
            UserDefaults.standard.set(0.7, forKey: "temperature")
            
            // Create a default user profile
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                _ = PersistenceController.shared.saveUserProfile(
                    name: "User",
                    email: "",
                    appleUserId: nil
                )
            }
        }
    }
    
    private func setupPermissions() {
        // Setup background audio mode
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        // 请求通知权限以支持后台录音通知
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("通知权限已获取")
            } else if let error = error {
                print("获取通知权限失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func requestPermissions() {
        // Pre-request permissions for better user experience
        SFSpeechRecognizer.requestAuthorization { _ in }
        
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }
}

// A simplified onboarding view with Japanese aesthetic
struct SimpleOnboardingView: View {
    @State private var currentStep = 0
    @State private var userName = ""
    @Binding var isPresented: Bool  // 使用Binding来控制显示状态
    
    var body: some View {
        ZStack {
            // Subtle gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.97, green: 0.97, blue: 0.98),
                    Color(red: 0.96, green: 0.96, blue: 0.98),
                    Color(red: 0.95, green: 0.95, blue: 0.98)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .onAppear {
                print("引导页面已显示")
            }
            .onDisappear {
                print("引导页面已关闭")
            }
            
            // Cherry blossom decorative elements
            GeometryReader { geometry in
                ZStack {
                    // Top right cherry blossom
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color.pink.opacity(0.3))
                        .position(x: geometry.size.width - 40, y: 60)
                    
                    // Bottom left cherry blossom
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.pink.opacity(0.2))
                        .position(x: 30, y: geometry.size.height - 100)
                    
                    // Center decorative line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.7, green: 0.7, blue: 0.9).opacity(0.0),
                                    Color(red: 0.7, green: 0.7, blue: 0.9).opacity(0.3),
                                    Color(red: 0.7, green: 0.7, blue: 0.9).opacity(0.0)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width, height: 1)
                        .position(x: geometry.size.width/2, y: geometry.size.height/2 - 40)
                }
            }
            
            VStack(spacing: 30) {
                // Japanese-style welcome header
                VStack(spacing: 12) {
                    Text("welcome".localized)
                        .font(.system(size: 36, weight: .light))
                        .tracking(8)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    
                    Text("appTitle".localized)
                        .font(.system(size: 28, weight: .light))
                        .tracking(2)
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                    
                    Text("digitalCompanion".localized)
                        .font(.system(size: 20, weight: .light))
                        .tracking(4)
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
                        .padding(.top, 5)
                }
                .padding(.top, 30)
                
                Spacer()
                
                // Stylized avatar in circular frame
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 160, height: 160)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.7, green: 0.7, blue: 0.9).opacity(0.4),
                                            Color(red: 0.8, green: 0.7, blue: 0.9).opacity(0.4)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                        .frame(width: 70, height: 70)
                }
                
                // Japanese-styled info card
                VStack(spacing: 22) {
                    Text("appIntroTitle".localized)
                        .font(.system(size: 20, weight: .medium))
                        .tracking(2)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                    
                    VStack(spacing: 14) {
                        // Feature item
                        HStack(spacing: 15) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.8))
                                .font(.system(size: 22, weight: .light))
                            Text("feature1".localized)
                                .font(.system(size: 17, weight: .light))
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            Spacer()
                        }
                        
                        // Feature item
                        HStack(spacing: 15) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.8))
                                .font(.system(size: 22, weight: .light))
                            Text("feature2".localized)
                                .font(.system(size: 17, weight: .light))
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            Spacer()
                        }
                        
                        // Feature item
                        HStack(spacing: 15) {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.8))
                                .font(.system(size: 22, weight: .light))
                            Text("feature3".localized)
                                .font(.system(size: 17, weight: .light))
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(25)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 25)
                .padding(.top, 10)
                
                Spacer()
                
                // Japanese-styled start button
                Button(action: {
                    // 设置已启动标志，避免下次再显示引导页
                    UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                    // 添加淡出动画效果
                    withAnimation(.easeOut(duration: 0.5)) {
                        isPresented = false
                    }
                    print("按钮被点击，引导页关闭")
                }) {
                    HStack {
                        Text("startButton".localized)
                            .font(.system(size: 20, weight: .medium))
                            .tracking(4)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.7))
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 40)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.7, green: 0.7, blue: 0.9).opacity(0.5),
                                        Color(red: 0.8, green: 0.7, blue: 0.9).opacity(0.5)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 30)
                                    .fill(Color.white.opacity(0.9))
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
                .buttonStyle(DesignSystem.ButtonStyles.ScaleButton())  // Add custom button style
                .padding(.bottom, 50)
                .contentShape(Rectangle())  // 扩大点击区域
                .allowsHitTesting(true)  // 确保按钮可点击
            }
            .padding()
        }
    }
}
