#!/bin/bash

# 设置广播扩展的Bundle ID
BROADCAST_EXTENSION_BUNDLE_ID="name.KrypotoZ.MirrorChild.MirrorChildScreenShare"

# 设置主应用的Bundle ID
MAIN_APP_BUNDLE_ID="name.KrypotoZ.MirrorChild"

# 确保广播扩展被启用
defaults write com.apple.ScreenSharing ShowBroadcastPickerForExtension -string $BROADCAST_EXTENSION_BUNDLE_ID

# 添加广播服务注册
defaults write com.apple.broadcastservices ShowBroadcastPickerForExtension -string $BROADCAST_EXTENSION_BUNDLE_ID
defaults write com.apple.broadcastservices BroadcastServiceName -string "MirrorChild广播"

# 重新启动相关服务
killall -9 ReplayKit 2>/dev/null || true
killall -9 BroadcastServices 2>/dev/null || true

echo "广播扩展 $BROADCAST_EXTENSION_BUNDLE_ID 已启用"

# 将此脚本添加到Xcode的构建后脚本中，确保每次构建后都启用扩展
# 在Xcode项目设置的"Build Phases"中添加一个"Run Script"阶段，
# 并添加以下命令：
# ${SRCROOT}/enable_broadcast_extension.sh