import SwiftUI

struct VoiceLanguageSelectionView: View {
    @ObservedObject private var voiceCaptureManager = VoiceCaptureManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedLanguage: VoiceLanguage
    
    // 初始化时获取当前语言
    init() {
        _selectedLanguage = State(initialValue: VoiceCaptureManager.shared.currentLanguage)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 标题说明
                    Text("选择语音识别语言")
                        .font(.headline)
                        .padding(.top)
                    
                    // 简化的语言选择
                    VStack(spacing: 15) {
                        languageButton(for: .chinese)
                        languageButton(for: .english)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                    
                    // 显示当前选择的语言
                    Text("当前语言: \(selectedLanguage.localizedName)")
                        .font(.headline)
                        .padding()
                    
                    // 提示信息
                    Text("中文为默认语言，建议在中文环境下使用")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                    
                    // 应用按钮
                    Button(action: {
                        voiceCaptureManager.switchLanguage(to: selectedLanguage)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("切换语言")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.5, green: 0.5, blue: 0.8))
                            )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
                .navigationTitle("语音识别语言")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("完成")
                                .font(.system(size: 17))
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.light) // 强制使用浅色模式
    }
    
    // 为每种语言创建选择按钮
    private func languageButton(for language: VoiceLanguage) -> some View {
        Button(action: {
            selectedLanguage = language
        }) {
            HStack {
                Text(language.localizedName)
                    .foregroundColor(.primary)
                    .font(.system(size: 18))
                
                Spacer()
                
                // 显示选中状态
                if selectedLanguage == language {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.8))
                        .font(.system(size: 22))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedLanguage == language ? 
                        Color(red: 0.5, green: 0.5, blue: 0.8).opacity(0.1) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 2)
            )
        }
    }
}

#Preview {
    VoiceLanguageSelectionView()
} 