//
//  MirrorChildApp.swift
//  MirrorChild
//
//  Created by 赵嘉策 on 2025/4/3.
//

import SwiftUI
import CoreData

@main
struct MirrorChildApp: App {
    let persistenceController = PersistenceController.shared
    
    // State for showing onboarding
    @State private var showOnboarding = false
    
    // Register app lifecycle events
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Configure app appearance
        configureAppAppearance()
        
        // Check if first launch
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            // Set the onboarding flag to show onboarding screen
            _showOnboarding = State(initialValue: true)
        }
        
        checkFirstLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .onAppear {
                        // Request necessary permissions on first run
                        requestPermissions()
                    }
                    .onChange(of: scenePhase) { newPhase in
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
                    SimpleOnboardingView()
                        .transition(.opacity)
                        .zIndex(1) // Ensure it appears on top
                        .onDisappear {
                            showOnboarding = false
                        }
                }
            }
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
    
    private func requestPermissions() {
        // We're not using any permissions in the simplified app
    }
}

// A simplified onboarding view with Japanese aesthetic
struct SimpleOnboardingView: View {
    @State private var currentStep = 0
    @State private var userName = ""
    
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
                    // Dismiss onboarding
                    UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                }) {
                    Text("startButton".localized)
                        .font(.system(size: 20, weight: .medium))
                        .tracking(4)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.35))
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
                                        .fill(Color.white.opacity(0.7))
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
                        )
                }
                .padding(.bottom, 50)
            }
            .padding()
        }
    }
}
