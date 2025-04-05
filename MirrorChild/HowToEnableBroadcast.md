# 如何启用MirrorChild的屏幕录制功能

如果您在使用屏幕录制功能时，点击录制按钮后没有看到MirrorChild应用出现在选项列表中，请按照以下步骤操作：

## 在iOS设备上启用屏幕录制

1. 确保您已将"屏幕录制"按钮添加到控制中心
   - 打开设备的"设置"
   - 点击"控制中心"
   - 如果"屏幕录制"不在已包含的控制项目中，请在下方的"更多控制"中找到它并点击"+"添加

2. 确保MirrorChild应用有屏幕录制权限
   - 打开设备的"设置"
   - 滚动找到并点击"MirrorChild"应用
   - 确保"屏幕录制"权限已开启

3. 重新启动MirrorChild应用
   - 完全关闭MirrorChild应用（从后台应用列表中上滑删除）
   - 重新打开MirrorChild应用

4. 使用控制中心启动屏幕录制
   - 从屏幕顶部向下滑动打开控制中心
   - 长按"屏幕录制"按钮
   - 在弹出的选项中应该能看到"MirrorChild"选项
   - 选择它并点击"开始录制"

5. 如果以上步骤都不起作用，尝试重启设备
   - 重启iOS设备后再次尝试

## 开发者选项

如果您是开发者，还可以检查以下内容：

1. 确保App Group配置正确
   - 主应用和广播扩展都应该使用同一个App Group: `group.name.KrypotoZ.MirrorChild`

2. 检查Bundle ID配置
   - 广播扩展的Bundle ID应为: `name.KrypotoZ.MirrorChild.MirrorChildBroadcast`
   - RPSystemBroadcastPickerView的preferredExtension设置应匹配此Bundle ID

3. 验证Entitlements文件
   - 主应用和广播扩展的entitlements文件都应包含正确的App Group

4. 确认Info.plist设置
   - 检查主应用的Info.plist是否包含必要的屏幕录制权限描述
   - 确认广播扩展的Info.plist配置正确

如果问题仍然存在，请联系技术支持获取进一步帮助。 