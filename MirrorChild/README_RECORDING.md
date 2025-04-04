# MirrorChild 屏幕录制功能使用指南

本文档详细说明了 MirrorChild 应用中的屏幕录制功能，包括技术实现、使用方法和常见问题。

## 技术实现

MirrorChild 的屏幕录制功能使用了 Apple 的 ReplayKit2 框架和系统的广播扩展（Broadcast Extension）来实现对其他应用的屏幕录制。主要包括以下组件：

1. **MirrorChildBroadcast 扩展**：负责实际的屏幕捕获和处理
2. **MirrorChildBroadcastSetupUI 扩展**：提供录制前的设置界面
3. **RPSystemBroadcastPickerView**：系统提供的广播选择器控件
4. **BroadcastManager**：负责在主应用和扩展之间通信的管理器

应用和扩展之间通过 App Group 共享数据，包括录制状态和捕获的屏幕图像。

## 使用方法

### 基本步骤

1. 在 MirrorChild 应用中，导航到"屏幕共享"页面
2. 点击页面底部的蓝色"开始/停止录制"按钮
3. 在系统弹出的选择器中，选择要录制的应用
4. 切换到目标应用进行操作，此时 MirrorChildBroadcast 扩展会在后台工作
5. 录制结束后，可点击控制中心中的红色状态栏，或返回 MirrorChild 应用再次点击录制按钮来停止录制

### 查看录制内容

在录制过程中或录制结束后，您可以返回 MirrorChild 应用查看捕获的屏幕内容：

- 实时视图显示最新捕获的屏幕内容
- 缩略图栏显示最近的截图历史
- 点击缩略图可查看更大的预览

## 开发者设置

如果您需要在开发环境中设置此功能，请确保以下配置正确：

### 1. App Group 配置

确保主应用和两个扩展都在同一个 App Group 中：

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.mirrochild.screensharing</string>
</array>
```

### 2. 启用背景模式（主应用）

在 Info.plist 中：

```xml
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
</array>
```

### 3. 扩展配置

确保扩展的 Info.plist 包含正确的配置：

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.broadcast-services-upload</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).SampleHandler</string>
    <key>RPBroadcastProcessMode</key>
    <string>RPBroadcastProcessModeSampleBuffer</string>
</dict>
```

### 4. Entitlements 文件

确保主应用和扩展的 entitlements 文件中包含相同的 App Group。

## 常见问题

### Q: 为什么我在某些应用中无法录制屏幕？
A: 一些应用出于隐私和安全原因禁止屏幕录制，如银行应用、某些视频播放器等。这是系统级别的限制，无法绕过。

### Q: 录制的质量如何调整？
A: 目前录制质量已设置为平衡性能和质量的最佳选项。可以通过修改 SampleHandler.swift 中的帧处理部分来调整压缩率和分辨率。

### Q: 为何录制时应用有时会感觉卡顿？
A: 屏幕录制是资源密集型操作，可能影响设备性能。我们已通过仅处理部分帧和降低处理频率来最小化影响。

### Q: 如何访问录制的文件？
A: 录制的帧图像保存在应用的 App Group 容器中，通常不直接对用户可见。可通过 MirrorChild 应用的界面访问。

## 技术支持

如需进一步的技术支持，请联系：support@mirrochild.com 