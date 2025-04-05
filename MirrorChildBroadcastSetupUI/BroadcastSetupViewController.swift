//
//  BroadcastSetupViewController.swift
//  MirrorChildBroadcastSetupUI
//
//  Created by 赵嘉策 on 2025/4/4.
//

import ReplayKit
import UIKit

class BroadcastSetupViewController: UIViewController {
    
    // UI Elements
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Auto-start after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.userDidFinishSetup()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        
        // Title Label
        titleLabel.text = "屏幕共享"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = UIColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 1.0)
        
        // Description Label
        descriptionLabel.text = "即将开始录制您的屏幕"
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = .darkGray
        
        // Start Button
        startButton.setTitle("开始", for: .normal)
        startButton.backgroundColor = UIColor(red: 0.3, green: 0.3, blue: 0.8, alpha: 1.0)
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 20
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        
        // Cancel Button
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.setTitleColor(.gray, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(descriptionLabel)
        view.addSubview(startButton)
        view.addSubview(cancelButton)
        
        // Layout using frames (simple approach)
        titleLabel.frame = CGRect(x: 20, y: 40, width: view.bounds.width - 40, height: 30)
        descriptionLabel.frame = CGRect(x: 20, y: 80, width: view.bounds.width - 40, height: 60)
        startButton.frame = CGRect(x: 40, y: 160, width: view.bounds.width - 80, height: 50)
        cancelButton.frame = CGRect(x: 40, y: 220, width: view.bounds.width - 80, height: 40)
    }
    
    @objc private func startButtonTapped() {
        userDidFinishSetup()
    }
    
    @objc private func cancelButtonTapped() {
        userDidCancelSetup()
    }

    // Call this method when the user has finished interacting with the view controller and a broadcast stream can start
    func userDidFinishSetup() {
        // URL of the resource where broadcast can be viewed that will be returned to the application
        let broadcastURL = URL(string: "https://mirrochild.app/broadcast")
        
        // Dictionary with setup information that will be provided to broadcast extension when broadcast is started
        let setupInfo: [String : NSCoding & NSObjectProtocol] = [
            "broadcastName": "MirrorChild Broadcast" as NSString,
            "appGroupId": "group.name.KrypotoZ.MirrorChild" as NSString
        ]
        
        // Tell ReplayKit that the extension is finished setting up and can begin broadcasting
        self.extensionContext?.completeRequest(withBroadcast: broadcastURL!, setupInfo: setupInfo)
    }
    
    func userDidCancelSetup() {
        let error = NSError(domain: "com.mirrochild.broadcast", code: -1, userInfo: [NSLocalizedDescriptionKey: "用户取消了屏幕共享"])
        // Tell ReplayKit that the extension was cancelled by the user
        self.extensionContext?.cancelRequest(withError: error)
    }
}
