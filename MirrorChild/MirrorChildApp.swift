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

// A simplified onboarding view
struct SimpleOnboardingView: View {
    @State private var currentStep = 0
    @State private var userName = ""
    
    var body: some View {
        ZStack {
            // Background
            Color.blue.opacity(0.2).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Welcome to MirrorChild!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("A simplified digital companion")
                    .font(.title2)
                
                Spacer()
                
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.blue)
                    .frame(width: 150, height: 150)
                    .padding(.vertical, 20)
                
                Text("This is the simplified version without AI features.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                Button(action: {
                    // Dismiss onboarding
                    UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                }) {
                    Text("Get Started")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 200)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.bottom, 50)
            }
            .padding()
        }
    }
}
