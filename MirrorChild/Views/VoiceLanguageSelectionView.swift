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
                    Text("languageSelectionPrompt".localized)
                        .font(.headline)
                        .padding(.top)
                    
                    // 语言列表
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(voiceCaptureManager.availableLanguages) { language in
                                languageButton(for: language)
                            }
                            
                            // 显示不可用的语言
                            let unavailableLanguages = VoiceLanguage.allCases.filter { 
                                !voiceCaptureManager.availableLanguages.contains($0) 
                            }
                            
                            if !unavailableLanguages.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                                
                                Text("languageNotAvailable".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                                
                                ForEach(unavailableLanguages) { language in
                                    HStack {
                                        Text(language.localizedName)
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Image(systemName: "xmark.circle")
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 显示当前选择的语言
                    Text("currentLanguage".localized(with: selectedLanguage.localizedName))
                        .font(.headline)
                        .padding()
                    
                    // 应用按钮
                    Button(action: {
                        voiceCaptureManager.switchLanguage(to: selectedLanguage)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("switchLanguage".localized)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                    }
                    .padding(.horizontal)
                    .disabled(!voiceCaptureManager.availableLanguages.contains(selectedLanguage))
                }
                .navigationTitle("voiceLanguageTitle".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("doneButton".localized)
                        }
                    }
                }
            }
        }
    }
    
    // 为每种语言创建选择按钮
    private func languageButton(for language: VoiceLanguage) -> some View {
        Button(action: {
            selectedLanguage = language
        }) {
            HStack {
                Text(language.localizedName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 显示选中状态
                if selectedLanguage == language {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedLanguage == language ? 
                        Color.blue.opacity(0.1) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 2)
            )
        }
    }
}

#Preview {
    VoiceLanguageSelectionView()
} 