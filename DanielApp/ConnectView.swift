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
            return "关注我们获取更多灵感内容："
        case .english:
            return "Follow us for more inspiring content:"
        case .korean:
            return "더 많은 영감을 주는 콘텐츠를 위해 팔로우하세요:"
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                StyleConstants.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: StyleConstants.largeSpacing) {
                    // 标题
                    Text(LocalizedText.ConnectView.connect.text(for: appState.selectedLanguage))
                        .font(StyleConstants.serifTitle(30, language: appState.selectedLanguage))
                        .foregroundColor(StyleConstants.goldColor)
                        .padding(.top, StyleConstants.standardSpacing)
                    
                    // 应用名称
                    Text(LocalizedText.Common.appTitle.text(for: appState.selectedLanguage))
                        .font(StyleConstants.serifTitle(24, language: appState.selectedLanguage))
                        .foregroundColor(StyleConstants.goldColor)
                        .padding(.top, 5)
                    
                    // 欢迎文案
                    Text(welcomeText)
                        .font(StyleConstants.sansFontBody(18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, StyleConstants.mediumSpacing)
                    
                    // 关注提示
                    Text(followText)
                        .font(StyleConstants.sansFontBody(16))
                        .foregroundColor(.white)
                        .padding(.top, StyleConstants.compactSpacing)
                    
                    Spacer()
                        .frame(height: StyleConstants.mediumSpacing)
                    
                    // 社交媒体连接按钮
                    VStack(spacing: StyleConstants.standardSpacing + 2) {
                        // Instagram 按钮
                        Link(destination: instagramUrl!, label: {
                            HStack {
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 24))
                                
                                Text("Instagram")
                                    .font(StyleConstants.sansFontBody(18))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(StyleConstants.buttonPadding + 2)
                            .foregroundColor(StyleConstants.goldColor)
                            .background(
                                RoundedRectangle(cornerRadius: StyleConstants.buttonCornerRadius)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                StyleConstants.goldColor,
                                                StyleConstants.goldColor.opacity(0.6)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: StyleConstants.buttonBorderWidth
                                    )
                                    .background(
                                        RoundedRectangle(cornerRadius: StyleConstants.buttonCornerRadius)
                                            .fill(StyleConstants.goldColor.opacity(0.05))
                                    )
                            )
                        })
                        .padding(.horizontal, StyleConstants.largeSpacing)
                        
                        // YouTube 按钮
                        Link(destination: youtubeUrl!, label: {
                            HStack {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 24))
                                
                                Text("YouTube")
                                    .font(StyleConstants.sansFontBody(18))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(StyleConstants.buttonPadding + 2)
                            .foregroundColor(StyleConstants.goldColor)
                            .background(
                                RoundedRectangle(cornerRadius: StyleConstants.buttonCornerRadius)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                StyleConstants.goldColor,
                                                StyleConstants.goldColor.opacity(0.6)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: StyleConstants.buttonBorderWidth
                                    )
                                    .background(
                                        RoundedRectangle(cornerRadius: StyleConstants.buttonCornerRadius)
                                            .fill(StyleConstants.goldColor.opacity(0.05))
                                    )
                            )
                        })
                        .padding(.horizontal, StyleConstants.largeSpacing)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
} 
