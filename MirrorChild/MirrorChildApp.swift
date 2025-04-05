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

// 添加方向控制类
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // 限制应用只支持竖屏方向
        return .portrait
    }
}

@main
struct MirrorChildApp: App {
    // 注册AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    let persistenceController = PersistenceController.shared
    
    // State for showing onboarding
    @State private var showOnboarding = false
    
    // Register app lifecycle events
    @Environment(\.scenePhase) private var scenePhase
    
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
        
        // 打印可用字体列表，便于调试
        debugPrintAvailableFonts()
    }

    var body: some Scene {
        WindowGroup {
            // 处理模拟器特殊情况下，直接显示简单的视图确保能看到内容
            #if targetEnvironment(simulator)
            ZStack {
                // 简单的背景
                Color(red: 0.95, green: 0.95, blue: 0.98)
                    .ignoresSafeArea()
                    .onAppear {
                        print("模拟器视图已加载")
                    }
                
                // 直接显示内容视图
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                
                // 如果需要显示引导页，在最上层显示
                if showOnboarding {
                    SimpleOnboardingView(isPresented: $showOnboarding)
                        .transition(.opacity)
                        .zIndex(1) // 确保在最上层
                        .animation(.easeInOut(duration: 0.5), value: showOnboarding) // 添加淡入淡出动画
                }
            }
            #else
            ZStack {
                // 确保ContentView能立即显示
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .onAppear {
                        // 应用已启动，可以执行非关键的操作
                        print("Content view appeared")
                        
                        // 延迟请求权限，避免启动时就触发权限请求
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
                        .animation(.easeInOut(duration: 0.5), value: showOnboarding) // 添加淡入淡出动画
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
        
        // 设置应用程序默认字体
        setupDefaultFonts()
    }
    
    // MARK: - Font Configuration
    
    private func setupDefaultFonts() {
        // 设置默认字体为苹方和SF Pro
        // 这会影响整个应用程序中未明确指定字体的文本
        let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        
        // 根据当前语言环境设置不同的默认字体
        if Locale.current.language.languageCode?.identifier == "zh" {
            // 中文环境使用苹方
            UILabel.appearance().font = UIFont(name: "PingFangSC-Regular", size: fontDescriptor.pointSize)
            UITextField.appearance().font = UIFont(name: "PingFangSC-Regular", size: fontDescriptor.pointSize)
            UITextView.appearance().font = UIFont(name: "PingFangSC-Regular", size: fontDescriptor.pointSize)
            UIButton.appearance().titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: fontDescriptor.pointSize)
        } else {
            // 其他语言环境使用SF Pro
            UILabel.appearance().font = UIFont(name: "SFProText-Regular", size: fontDescriptor.pointSize)
            UITextField.appearance().font = UIFont(name: "SFProText-Regular", size: fontDescriptor.pointSize)
            UITextView.appearance().font = UIFont(name: "SFProText-Regular", size: fontDescriptor.pointSize)
            UIButton.appearance().titleLabel?.font = UIFont(name: "SFProText-Regular", size: fontDescriptor.pointSize)
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
            requestAudioPermission()
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }
    
    @available(iOS 17.0, *)
    private func requestAudioPermission() {
        AVAudioApplication.requestRecordPermission(completionHandler: { (granted: Bool) in
            // Permission result handled
        })
    }
    
    private func debugPrintAvailableFonts() {
        // 只在DEBUG模式下输出字体列表，方便开发调试
        #if DEBUG
        print("=== 系统可用字体列表 ===")
        for familyName in UIFont.familyNames.sorted() {
            print("Font Family: \(familyName)")
            for fontName in UIFont.fontNames(forFamilyName: familyName).sorted() {
                print("-- Font: \(fontName)")
            }
        }
        print("=== 字体列表结束 ===")
        #endif
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
            
            VStack(spacing: 30) {
                // Japanese-style welcome header
                HStack {
                    Spacer()
                    VStack(alignment: .center, spacing: 0) {
                        Text("welcome".localized)
                            .font(.system(size: 50, weight: .bold))
                            .tracking(8)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            .padding(.bottom, 25)
                        
                        Text("appTitle".localized)
                            .font(.system(size: 60, weight: .heavy))
                            .tracking(2)
                            .foregroundColor(Color.black)
                            .padding(.bottom, 12)
                        
                        Text("MirrorChild")
                            .font(.custom("SF Compact Display", size: 26, relativeTo: .title).weight(.bold))
                            .tracking(1)
                            .foregroundColor(Color.black)
                            .padding(.top, 5)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                }
                .padding(.top, 50)
                
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
                        .foregroundColor(Color(red: 0.455, green: 0.580, blue: 0.455))
                        .frame(width: 70, height: 70)
                }
                .padding(.bottom, 10)
                .padding(.top, -30)
                
                // Japanese-styled info card
                VStack(spacing: 18) {
                    VStack(spacing: 14) {
                        // Feature item
                        HStack(spacing: 15) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.5, green: 0.65, blue: 0.5))
                                .font(.system(size: 24, weight: .light))
                            Text("feature1".localized)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            Spacer()
                        }
                        .padding(.leading, 18)
                        
                        // Feature item
                        HStack(spacing: 15) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.5, green: 0.65, blue: 0.5))
                                .font(.system(size: 24, weight: .light))
                            Text("feature2".localized)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            Spacer()
                        }
                        .padding(.leading, 18)
                        
                        // Feature item
                        HStack(spacing: 15) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.5, green: 0.65, blue: 0.5))
                                .font(.system(size: 24, weight: .light))
                            Text("feature3".localized)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                            Spacer()
                        }
                        .padding(.leading, 18)
                    }
                    .padding(.horizontal, 8)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, 25)
                .padding(.top, -25)
                
                Spacer()
                    .frame(height: 5)
                
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
                            .font(.system(size: 20, weight: .bold))
                            .tracking(4)
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.455, green: 0.580, blue: 0.455))
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 40)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
                .padding(.bottom, 10)
                .contentShape(Rectangle())  // 扩大点击区域
                .allowsHitTesting(true)  // 确保按钮可点击
            }
            .padding()
        }
        .preferredColorScheme(.light) // 强制使用浅色模式
    }
}

// 自定义按钮样式，提供轻触反馈
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(), value: configuration.isPressed)
    }
}
