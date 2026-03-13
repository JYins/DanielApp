import SwiftUI

struct PraiseView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var viewModel = PraiseViewModel()
    @State private var showingLogin = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                DesignSystem.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 标题和用户按钮
                    HStack {
                        Text(LocalizedText.Common.praiseTab.text(for: appState.selectedLanguage))
                            .font(DesignSystem.Typography.title(DesignSystem.Typography.title2, weight: .bold, language: appState.selectedLanguage))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        Spacer()
                        
                        // 用户按钮
                        if authManager.hasContentAccess() {
                            UserButtonView()
                        }
                    }
                    .padding(.horizontal, StyleConstants.standardSpacing)
                    .padding(.top, StyleConstants.standardSpacing)
                    .padding(.bottom, StyleConstants.compactSpacing)
                    
                    // 分隔线
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    DesignSystem.Colors.accent.opacity(0.5),
                                    DesignSystem.Colors.accent.opacity(0.2),
                                    Color.clear
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 40)
                        .padding(.bottom, StyleConstants.compactSpacing)
                    
                    // 内容区域
                    if authManager.hasContentAccess() {
                        PraiseContentView(viewModel: viewModel)
                    } else {
                        LoginPromptView(showingLogin: $showingLogin)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if authManager.hasContentAccess() {
                    viewModel.loadPraises()
                }
            }
            .onChange(of: authManager.authState) { newState in
                if authManager.hasContentAccess() {
                    viewModel.loadPraises()
                }
            }
            .sheet(isPresented: $showingLogin) {
                LoginView()
                    .environmentObject(appState)
            }
        }
        .navigationViewStyle(.stack)
    }
}

// 赞美列表内容视图
struct PraiseContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: PraiseViewModel
    
    var body: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent))
                .scaleEffect(1.5)
            Spacer()
        } else if let errorMessage = viewModel.errorMessage {
            Spacer()
            VStack {
                Text("加载出错")
                    .font(DesignSystem.Typography.title(DesignSystem.Typography.headline, weight: .semibold, language: appState.selectedLanguage))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(errorMessage)
                    .font(DesignSystem.Typography.body(DesignSystem.Typography.body, language: appState.selectedLanguage))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("重试") {
                    viewModel.loadPraises()
                }
                .buttonStyle(ModernButtonStyle(language: appState.selectedLanguage))
            }
            Spacer()
        } else if viewModel.praises.isEmpty {
            Spacer()
            VStack {
                Text(LocalizedText.Praise.comingSoon.text(for: appState.selectedLanguage))
                    .font(DesignSystem.Typography.title(DesignSystem.Typography.title2, weight: .semibold, language: appState.selectedLanguage))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(LocalizedText.Praise.description.text(for: appState.selectedLanguage))
                    .font(DesignSystem.Typography.body(DesignSystem.Typography.body, language: appState.selectedLanguage))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: StyleConstants.mediumSpacing) {
                    ForEach(viewModel.praises) { praise in
                        PraiseCardView(praise: praise, language: appState.selectedLanguage)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.top, StyleConstants.standardSpacing)
                .padding(.bottom, StyleConstants.mediumSpacing)
            }
        }
    }
}

struct PraiseCardView: View {
    let praise: Praise
    let language: CoreModels.VerseLanguage
    @State private var currentImageIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题区域
            VStack(alignment: .leading, spacing: 4) {
                Text(praise.title)
                    .font(DesignSystem.Typography.title(DesignSystem.Typography.headline, weight: .bold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(DateFormatter.newsletterFormatter.string(from: praise.uploadedAt.dateValue()))
                    .font(DesignSystem.Typography.smart(DesignSystem.Typography.footnote, language: language))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.cardBackground)
            
            // 图片区域
            ZStack(alignment: .bottom) {
                if praise.fileUrls.isEmpty {
                    Rectangle()
                        .fill(DesignSystem.Colors.background)
                        .aspectRatio(1.0, contentMode: .fit)
                        .overlay(
                            Image(systemName: "music.note.list")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        )
                } else {
                    TabView(selection: $currentImageIndex) {
                        ForEach(0..<praise.fileUrls.count, id: \.self) { index in
                            let urlStr = praise.fileUrls[index]
                            if let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFit() // 乐谱保持原比例
                                    } else if phase.error != nil {
                                        Rectangle()
                                            .fill(DesignSystem.Colors.background)
                                            .overlay(Image(systemName: "exclamationmark.triangle").foregroundColor(.gray))
                                    } else {
                                        Rectangle()
                                            .fill(DesignSystem.Colors.background)
                                            .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent)))
                                    }
                                }
                                .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .aspectRatio(1004.0/1440.0, contentMode: .fit) // 使用标准文档比例
                    .clipped()
                }
            }
            .background(Color.white)
        }
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: DesignSystem.Shadow.card.color, radius: DesignSystem.Shadow.card.radius, x: DesignSystem.Shadow.card.x, y: DesignSystem.Shadow.card.y)
        .padding(.horizontal, 4)
        .clipped()
    }
}

// 预览
struct PraiseView_Previews: PreviewProvider {
    static var previews: some View {
        PraiseView()
            .environmentObject(AppState())
    }
}
