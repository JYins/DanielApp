import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct NewsletterView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var viewModel = NewsletterViewModel()
    @State private var showingLogin = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色 - 使用统一的设计系统
                DesignSystem.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 标题和用户按钮
                    HStack {
                        Text(LocalizedText.Newsletter.navTitle.text(for: appState.selectedLanguage))
                            .font(DesignSystem.Typography.title(DesignSystem.Typography.title2, weight: .bold, language: appState.selectedLanguage))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        Spacer()
                        
                        // 用户按钮（仅在登录后显示）
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
                        // 已登录用户可以访问内容
                        AuthenticatedContentView(viewModel: viewModel)
                    } else {
                        // 未登录用户显示登录提示
                        LoginPromptView(showingLogin: $showingLogin)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if authManager.hasContentAccess() {
                    viewModel.loadNewsletters()
                }
            }
            .onChange(of: authManager.authState) { newState in
                if authManager.hasContentAccess() {
                    viewModel.loadNewsletters()
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

// 已认证用户的内容视图
struct AuthenticatedContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: NewsletterViewModel
    
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
                    viewModel.loadNewsletters()
                }
                .buttonStyle(ModernButtonStyle(language: appState.selectedLanguage))
            }
            Spacer()
        } else if viewModel.newsletters.isEmpty {
            Spacer()
            Text("暂无Newsletter")
                .font(DesignSystem.Typography.body(DesignSystem.Typography.body, language: appState.selectedLanguage))
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Spacer()
        } else {
            // Newsletter列表
            ScrollView {
                LazyVStack(spacing: StyleConstants.mediumSpacing - 2) {
                    ForEach(viewModel.newsletters) { newsletter in
                        NewsletterCardView(newsletter: newsletter, language: appState.selectedLanguage)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.top, StyleConstants.standardSpacing)
                .padding(.bottom, StyleConstants.mediumSpacing)
            }
        }
    }
}

// 未登录用户的提示视图
struct LoginPromptView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showingLogin: Bool
    
    var body: some View {
        Spacer()
        VStack(spacing: StyleConstants.mediumSpacing) {
            Image(systemName: "newspaper")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.accent.opacity(0.8))
            
            Text(LocalizedText.NewsletterView.title.text(for: appState.selectedLanguage))
                .font(DesignSystem.Typography.title(DesignSystem.Typography.title2, weight: .semibold, language: appState.selectedLanguage))
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text(LocalizedText.NewsletterView.loginPrompt.text(for: appState.selectedLanguage))
                .font(DesignSystem.Typography.body(DesignSystem.Typography.body, language: appState.selectedLanguage))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingLogin = true
            }) {
                Text(LocalizedText.NewsletterView.loginButton.text(for: appState.selectedLanguage))
                    .font(DesignSystem.Typography.body(DesignSystem.Typography.body, weight: .semibold, language: appState.selectedLanguage))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding(.vertical, StyleConstants.standardSpacing)
                    .background(DesignSystem.Colors.accent)
                    .cornerRadius(StyleConstants.buttonCornerRadius)
            }
        }
        Spacer()
    }
}

// 用户按钮组件
struct UserButtonView: View {
    @StateObject private var authManager = AuthManager.shared
    @EnvironmentObject var appState: AppState
    @State private var showingUserMenu = false
    
    var body: some View {
        Button(action: {
            showingUserMenu = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DesignSystem.Colors.accent)
                
                if case .signedIn(let profile) = authManager.authState {
                    Text(profile.name)
                        .font(DesignSystem.Typography.smart(DesignSystem.Typography.callout, language: appState.selectedLanguage))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)
                } else {
                    Text(LocalizedText.NewsletterView.defaultUserName.text(for: appState.selectedLanguage))
                        .font(DesignSystem.Typography.smart(DesignSystem.Typography.callout, language: appState.selectedLanguage))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .actionSheet(isPresented: $showingUserMenu) {
            ActionSheet(
                title: Text(LocalizedText.NewsletterView.userMenuTitle.text(for: appState.selectedLanguage)),
                message: getUserInfo(),
                buttons: [
                    .destructive(Text(LocalizedText.NewsletterView.logout.text(for: appState.selectedLanguage))) {
                        authManager.signOut()
                    },
                    .cancel(Text(LocalizedText.NewsletterView.cancel.text(for: appState.selectedLanguage)))
                ]
            )
        }
    }
    
    private func getUserInfo() -> Text {
        if case .signedIn(let profile) = authManager.authState {
            let userText = LocalizedText.NewsletterView.defaultUserName.text(for: appState.selectedLanguage)
            let emailText = appState.selectedLanguage == .chinese ? "邮箱" : (appState.selectedLanguage == .english ? "Email" : "이메일")
            return Text("\(userText)：\(profile.name)\n\(emailText)：\(profile.email)")
        } else {
            return Text(LocalizedText.NewsletterView.userInfo.text(for: appState.selectedLanguage))
        }
    }
}

// Newsletter卡片视图 (采用AsyncImage直接加载URL)
struct NewsletterCardView: View {
    let newsletter: Newsletter
    let language: CoreModels.VerseLanguage
    @State private var currentImageIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图片区域
            ZStack(alignment: .bottom) {
                if newsletter.image_urls.isEmpty {
                    Rectangle()
                        .fill(DesignSystem.Colors.cardBackground)
                        .aspectRatio(1004.0/1440.0, contentMode: .fit) // Newsletter专用尺寸比例
                        .overlay(
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        )
                } else {
                    TabView(selection: $currentImageIndex) {
                        ForEach(0..<newsletter.image_urls.count, id: \.self) { index in
                            let urlStr = newsletter.image_urls[index]
                            if let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } else if phase.error != nil {
                                        Rectangle()
                                            .fill(DesignSystem.Colors.cardBackground)
                                            .overlay(Image(systemName: "exclamationmark.triangle").foregroundColor(.gray))
                                    } else {
                                        Rectangle()
                                            .fill(DesignSystem.Colors.cardBackground)
                                            .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent)))
                                    }
                                }
                                .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .aspectRatio(1004.0/1440.0, contentMode: .fit) // Newsletter专用尺寸比例
                    .clipped()
                    
                    // 如果有多张图片，显示分页指示器
                    if newsletter.image_urls.count > 1 {
                        HStack(spacing: 4) {
                            ForEach(0..<newsletter.image_urls.count, id: \.self) { index in
                                Circle()
                                    .fill(currentImageIndex == index ? Color.white : Color.white.opacity(0.5))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
            
            // 重新设计的文案区域（照搬话语卡片）
            VStack(alignment: .leading, spacing: 0) {
                // 添加顶部装饰线
                HStack {
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                DesignSystem.Colors.accent.opacity(0.6),
                                DesignSystem.Colors.accent.opacity(0.2),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 2)
                    
                    Spacer()
                    
                    // 小装饰图标
                    Image(systemName: "quote.opening")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(DesignSystem.Colors.accent.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // 文案内容
                Text(newsletter.caption.text(for: language))
                    .font(DesignSystem.Typography.body(DesignSystem.Typography.body, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineSpacing(6)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // 发布日期
                Text(DateFormatter.newsletterFormatter.string(from: newsletter.publishDate.dateValue()))
                    .font(DesignSystem.Typography.smart(DesignSystem.Typography.footnote, language: language))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                // 底部渐变装饰
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        DesignSystem.Colors.accent.opacity(0.1)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 8)
            }
            .background(
                // 奶白色渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: "#FEFCF8"), // 更纯净的奶白色顶部
                        Color(hex: "#FAF7F0"), // 中间色调
                        Color(hex: "#F5F1E8")  // 底部稍微偏暖的奶白色
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .background(Color.white) // 确保整体背景为白色
        .cornerRadius(26) // 增加圆角半径使其更现代
        .overlay(
            // 多层边框效果
            RoundedRectangle(cornerRadius: 26)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            DesignSystem.Colors.accent.opacity(0.5),
                            DesignSystem.Colors.accent.opacity(0.25),
                            DesignSystem.Colors.accent.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.8
                )
        )
        .shadow(color: DesignSystem.Shadow.card.color, radius: DesignSystem.Shadow.card.radius, x: DesignSystem.Shadow.card.x, y: DesignSystem.Shadow.card.y)
        .shadow(color: Color.black.opacity(0.03), radius: 32, x: 0, y: 12)
        .shadow(color: DesignSystem.Colors.accent.opacity(0.08), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 4)
        .clipped()
    }
}

// Newsletter视图模型
class NewsletterViewModel: ObservableObject {
    @Published var newsletters: [Newsletter] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    func loadNewsletters() {
        isLoading = true
        errorMessage = nil
        
        listenerRegistration?.remove()
        
        listenerRegistration = db.collection("newsletters")
            .whereField("published", isEqualTo: true)
            .order(by: "publishDate", descending: true)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("Error loading newsletters: \(error.localizedDescription)")
                        self.errorMessage = "加载教会通讯失败: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        print("No newsletters found")
                        return
                    }
                    
                    var fetchedNewsletters: [Newsletter] = []
                    
                    for document in documents {
                        do {
                            let newsletter = try document.data(as: Newsletter.self)
                            fetchedNewsletters.append(newsletter)
                        } catch {
                            print("Error decoding newsletter: \(document.documentID) - \(error)")
                        }
                    }
                    
                    self.newsletters = fetchedNewsletters
                    print("Found \(self.newsletters.count) published newsletters")
                }
            }
    }
    
    deinit {
        listenerRegistration?.remove()
    }
}

// 圆角扩展已在WordCardGalleryView中定义，无需重复

// 日期格式化器
extension DateFormatter {
    static let newsletterFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
    
    // 用于解析配置文件中的日期字符串
    static func parseNewsletterDate(from dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// Newsletter本地化文本
extension LocalizedText {
    enum Newsletter {
        case navTitle
        
        func text(for language: CoreModels.VerseLanguage) -> String {
            switch language {
            case .chinese:
                switch self {
                case .navTitle: return "教会通讯"
                }
            case .korean:
                switch self {
                case .navTitle: return "교회 소식지"
                }
            case .english:
                switch self {
                case .navTitle: return "Church Newsletter"
                }
            }
        }
    }
}

// 预览
struct NewsletterView_Previews: PreviewProvider {
    static var previews: some View {
        NewsletterView()
            .environmentObject(AppState())
    }
} 