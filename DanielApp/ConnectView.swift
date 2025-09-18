import SwiftUI
struct ConnectView: View {
    @EnvironmentObject var appState: AppState
    
    // 社交媒体链接
    let instagramUrl = URL(string: "https://www.instagram.com/daniel_fs0691/")
    let youtubeUrl = URL(string: "https://www.youtube.com/channel/UCv_vGKqXZGHjO6jRYQtufuA")
    
    // 本地化文本计算属性
    private var welcomeText: String {
        switch appState.selectedLanguage {
        case .chinese:
            return "欢迎加入社区！"
        case .english:
            return "Welcome to our community!"
        case .korean:
            return "커뮤니티에 오신 것을 환영합니다!"
        }
    }
    
    private var followText: String {
        switch appState.selectedLanguage {
        case .chinese:
            return "关注我们的社交媒体获取最新内容"
        case .english:
            return "Follow our social media for the latest content"
        case .korean:
            return "소셜 미디어를 팔로우하여 최신 콘텐츠를 받아보세요"
        }
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 40) {
                    // 顶部标题区域
                    VStack(spacing: 32) {
                        HStack {
                            Text(LocalizedText.ConnectView.connect.text(for: appState.selectedLanguage))
                                .font(DesignSystem.Typography.title(DesignSystem.Typography.title1, weight: .bold, language: appState.selectedLanguage))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 32)
                        
                        // 应用介绍卡片 - 大幅改进尺寸
                        VStack(spacing: 28) {
                            VStack(spacing: 20) {
                                Text("但以理和他的朋友们")
                                    .font(DesignSystem.Typography.title(DesignSystem.Typography.title2, weight: .bold, language: .chinese))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                
                                Text(welcomeText)
                                    .font(DesignSystem.Typography.body(DesignSystem.Typography.body, weight: .medium, language: appState.selectedLanguage))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(6)
                                    .lineLimit(nil)
                            }
                            
                            Text(followText)
                                .font(DesignSystem.Typography.smart(DesignSystem.Typography.callout, weight: .semibold, language: appState.selectedLanguage))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .lineLimit(nil)
                        }
                        .padding(.vertical, 36)
                        .padding(.horizontal, 32)
                        .modernCard()
                        .padding(.horizontal, 24)
                    
                    // 社交媒体链接区域
                    VStack(spacing: 20) {
                        // Instagram 链接
                        if let instagramUrl = instagramUrl {
                            Link(destination: instagramUrl) {
                                HStack(spacing: 24) {
                                    Image(systemName: "camera.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(DesignSystem.Colors.accent)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Instagram")
                                            .font(DesignSystem.Typography.title(DesignSystem.Typography.body, weight: .bold, language: appState.selectedLanguage))
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                        
                                        Text("@daniel_fs0691")
                                            .font(DesignSystem.Typography.body(DesignSystem.Typography.callout, language: appState.selectedLanguage))
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                    }
                                    
                                    Spacer(minLength: 24)
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 20))
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                                .padding(.horizontal, 28)
                                .padding(.vertical, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(DesignSystem.Colors.cardBackground.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(DesignSystem.Colors.divider, lineWidth: 1.2)
                                        )
                                )
                            }
                        }
                        
                        // YouTube 链接
                        if let youtubeUrl = youtubeUrl {
                            Link(destination: youtubeUrl) {
                                HStack(spacing: 24) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(DesignSystem.Colors.accent)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("YouTube")
                                            .font(DesignSystem.Typography.title(DesignSystem.Typography.body, weight: .bold, language: appState.selectedLanguage))
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                        
                                        Text("但以理和他的朋友们")
                                            .font(DesignSystem.Typography.body(DesignSystem.Typography.callout, language: appState.selectedLanguage))
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                            .lineLimit(nil)
                                    }
                                    
                                    Spacer(minLength: 24)
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 20))
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                                .padding(.horizontal, 28)
                                .padding(.vertical, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(DesignSystem.Colors.cardBackground.opacity(0.6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(DesignSystem.Colors.divider, lineWidth: 1.2)
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 50)
                }
            }
        }
        .watermark("@但以理和他的朋友们")
    }
}
}
