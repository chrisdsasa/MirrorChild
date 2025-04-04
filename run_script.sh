#!/bin/bash

echo "开始配置MirrorChild广播扩展..."

# 1. 设置变量
MAIN_APP_BUNDLE_ID="name.KrypotoZ.MirrorChild"
BROADCAST_EXTENSION_BUNDLE_ID="name.KrypotoZ.MirrorChild.MirrorChildScreenShare"
BROADCAST_SERVICE_NAME="MirrorChild广播"

# 2. 确保广播扩展被iOS识别
echo ">> 注册广播扩展到系统..."
defaults write com.apple.ScreenSharing ShowBroadcastPickerForExtension -string $BROADCAST_EXTENSION_BUNDLE_ID

# 3. 确保App Group目录存在
echo ">> 设置App Group共享目录..."
GROUP_DIR=$(getconf DARWIN_USER_DIR)Library/Group\ Containers/group.com.mirrochild.screensharing
mkdir -p "$GROUP_DIR"
echo "App Group目录: $GROUP_DIR"

# 4. 在App Group目录中创建必要的文件
echo ">> 初始化共享文件..."
echo "stopped" > "$GROUP_DIR/broadcastStarted.txt"
mkdir -p "$GROUP_DIR/frames"
echo "已创建广播状态文件和帧目录"

# 5. 修复文件权限
echo ">> 设置文件权限..."
chmod -R 755 "$GROUP_DIR"

# 6. 注册为可用的广播扩展（添加多种可能的注册方式）
echo ">> 注册为可用的广播扩展..."
# 方式1：使用ScreenSharing
defaults write com.apple.ScreenSharing ShowBroadcastPickerForExtension -string "$BROADCAST_EXTENSION_BUNDLE_ID"
# 方式2：使用broadcastservices
defaults write com.apple.broadcastservices ShowBroadcastPickerForExtension -string "$BROADCAST_EXTENSION_BUNDLE_ID"
defaults write com.apple.broadcastservices BroadcastServiceName -string "$BROADCAST_SERVICE_NAME"
# 方式3：使用ReplayKit (iOS 12+)
defaults write com.apple.ReplayKit ShowPickerForExtension -string "$BROADCAST_EXTENSION_BUNDLE_ID"
# 方式4：设置系统全局偏好
defaults write -g RPBroadcastExtension -string "$BROADCAST_EXTENSION_BUNDLE_ID"

# 7. 删除应用缓存，让系统重新识别广播扩展
echo ">> 清理缓存..."
killall -9 ReplayKit 2>/dev/null || true
killall -9 BroadcastServices 2>/dev/null || true

echo "配置完成！请在系统广播界面中寻找'MirrorChild广播'选项。"
echo "如果未显示，请尝试重启设备或重新安装应用。" 