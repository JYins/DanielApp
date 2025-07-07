import SwiftUI
import FirebaseStorage

struct NewsletterView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var viewModel = NewsletterViewModel()
    @State private var showingLogin = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Color(hex: "#020f2e").edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    // 标题和用户按钮
                    HStack {
                        Text(LocalizedText.Newsletter.navTitle.text(for: appState.selectedLanguage))
                            .font(StyleConstants.serifTitle(24, language: appState.selectedLanguage))
                            .foregroundColor(StyleConstants.goldColor)
                        
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
                                    StyleConstants.goldColor.opacity(0.5),
                                    StyleConstants.goldColor.opacity(0.2),
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
                .progressViewStyle(CircularProgressViewStyle(tint: StyleConstants.goldColor))
                .scaleEffect(1.5)
            Spacer()
        } else if let errorMessage = viewModel.errorMessage {
            Spacer()
            VStack {
                Text("加载出错")
                    .font(StyleConstants.serifTitle(18, language: appState.selectedLanguage))
                    .foregroundColor(StyleConstants.goldColor)
                
                Text(errorMessage)
                    .font(StyleConstants.sansFontBody(14))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("重试") {
                    viewModel.loadNewsletters()
                }
                .padding()
                .background(StyleConstants.goldColor)
                .foregroundColor(Color(hex: "#020f2e"))
                .cornerRadius(8)
            }
            Spacer()
        } else if viewModel.newsletters.isEmpty {
            Spacer()
            Text("暂无Newsletter")
                .font(StyleConstants.serifBody(16, language: appState.selectedLanguage))
                .foregroundColor(.white)
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
                .foregroundColor(StyleConstants.goldColor.opacity(0.8))
            
            Text("教会Newsletter")
                .font(StyleConstants.serifTitle(22, language: appState.selectedLanguage))
                .foregroundColor(StyleConstants.goldColor)
            
            Text("请登录以查看教会每月Newsletter")
                .font(StyleConstants.sansFontBody(16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingLogin = true
            }) {
                Text("立即登录")
                    .font(StyleConstants.sansFontBody(18))
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#020f2e"))
                    .frame(maxWidth: 200)
                    .padding(.vertical, StyleConstants.standardSpacing)
                    .background(StyleConstants.goldColor)
                    .cornerRadius(StyleConstants.buttonCornerRadius)
            }
        }
        Spacer()
    }
}

// 用户按钮组件
struct UserButtonView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showingUserMenu = false
    
    var body: some View {
        Button(action: {
            showingUserMenu = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(StyleConstants.goldColor)
                
                if case .signedIn(let profile) = authManager.authState {
                    Text(profile.name)
                        .font(StyleConstants.sansFontBody(14))
                        .foregroundColor(StyleConstants.goldColor)
                        .lineLimit(1)
                } else {
                    Text("用户")
                        .font(StyleConstants.sansFontBody(14))
                        .foregroundColor(StyleConstants.goldColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(StyleConstants.goldColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .actionSheet(isPresented: $showingUserMenu) {
            ActionSheet(
                title: Text("用户菜单"),
                message: getUserInfo(),
                buttons: [
                    .destructive(Text("退出登录")) {
                        authManager.signOut()
                    },
                    .cancel(Text("取消"))
                ]
            )
        }
    }
    
    private func getUserInfo() -> Text {
        if case .signedIn(let profile) = authManager.authState {
            return Text("用户：\(profile.name)\n邮箱：\(profile.email)")
        } else {
            return Text("当前用户信息")
        }
    }
}

// Newsletter卡片视图（照搬话语卡片设计）
struct NewsletterCardView: View {
    let newsletter: Newsletter
    let language: CoreModels.VerseLanguage
    @State private var currentImageIndex = 0
    @State private var images: [UIImage?] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图片区域
            ZStack(alignment: .bottom) {
                if isLoading {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(1080/1350, contentMode: .fit)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: StyleConstants.goldColor))
                                .scaleEffect(1.2)
                        )
                } else if images.isEmpty {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(1080/1350, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.white.opacity(0.7))
                        )
                } else {
                    TabView(selection: $currentImageIndex) {
                        ForEach(0..<images.count, id: \.self) { index in
                            if let image = images[index] {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .tag(index)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .aspectRatio(1080/1350, contentMode: .fit)
                    .clipped()
                    
                    // 如果有多张图片，显示分页指示器
                    if images.count > 1 {
                        HStack(spacing: 4) {
                            ForEach(0..<images.count, id: \.self) { index in
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
                                StyleConstants.goldColor.opacity(0.6),
                                StyleConstants.goldColor.opacity(0.2),
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
                        .foregroundColor(StyleConstants.goldColor.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // 文案内容
                Text(newsletter.caption.text(for: language))
                    .font(StyleConstants.serifBody(16, language: language))
                    .foregroundColor(Color(hex: "#2D3748")) // 更深的灰色，增强对比度
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // 底部渐变装饰
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        StyleConstants.goldColor.opacity(0.1)
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
                            StyleConstants.goldColor.opacity(0.5),
                            StyleConstants.goldColor.opacity(0.25),
                            StyleConstants.goldColor.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.8
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 4) // 更柔和的阴影
        .shadow(color: Color.black.opacity(0.03), radius: 32, x: 0, y: 12) // 添加第二层阴影增加深度
        .shadow(color: StyleConstants.goldColor.opacity(0.08), radius: 24, x: 0, y: 8) // 添加金色阴影
        .padding(.horizontal, 4)
        .clipped()
        .onAppear {
            loadImages()
        }
    }
    
    private func loadImages() {
        isLoading = true
        images = Array(repeating: nil, count: newsletter.imageURLs.count)
        
        let group = DispatchGroup()
        
        for (index, imagePath) in newsletter.imageURLs.enumerated() {
            group.enter()
            
            // 使用Newsletter专用的图片下载方法
            FirebaseStorageService.shared.downloadNewsletterImage(imagePath: imagePath) { image, error in
                defer { group.leave() }
                
                if let image = image {
                    DispatchQueue.main.async {
                        if index < self.images.count {
                            self.images[index] = image
                        }
                    }
                } else if let error = error {
                    print("加载Newsletter图片失败: \(error.localizedDescription)")
                }
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
        }
    }
}

// Newsletter视图模型
class NewsletterViewModel: ObservableObject {
    @Published var newsletters: [Newsletter] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storageService = FirebaseStorageService.shared
    
    func loadNewsletters() {
        isLoading = true
        errorMessage = nil
        
        // 从Firebase Storage的newsletters文件夹加载真实数据
        storageService.getNewsletterFolders { [weak self] folders, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "加载Newsletter文件夹失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            if folders.isEmpty {
                // 如果没有Newsletter文件夹，显示提示信息
                DispatchQueue.main.async {
                    self.newsletters = []
                    self.isLoading = false
                    self.errorMessage = "暂时没有Newsletter内容"
                    print("ℹ️ Newsletter文件夹为空")
                }
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var newNewsletters: [Newsletter] = []
            
            for folder in folders {
                dispatchGroup.enter()
                self.loadNewsletterFromFolder(folder) { newsletter in
                    if let newsletter = newsletter {
                        newNewsletters.append(newsletter)
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                // 按文件夹名排序，最新的在前（假设文件夹命名为YYYY-MM格式）
                self.newsletters = newNewsletters.sorted { $0.id > $1.id }
                self.isLoading = false
                print("✅ Newsletter数据加载成功，共\(newNewsletters.count)个，排序：\(newNewsletters.map { $0.id })")
            }
        }
    }
    
    private func loadNewsletterFromFolder(_ folderName: String, completion: @escaping (Newsletter?) -> Void) {
        print("正在加载Newsletter文件夹: \(folderName)")
        
        storageService.getFilesInNewsletterFolder(folderName: folderName) { [weak self] files, error in
            guard let self = self else { return }
            
            if let error = error {
                print("获取Newsletter文件夹\(folderName)失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            // 分离图片文件和配置文件
            let imageFiles = files.filter { 
                $0.name.lowercased().hasSuffix(".jpg") || 
                $0.name.lowercased().hasSuffix(".jpeg") ||
                $0.name.lowercased().hasSuffix(".png") 
            }
            
            let configFile = files.first { $0.name.lowercased() == "config.json" }
            
            print("Newsletter文件夹 \(folderName) - 图片: \(imageFiles.count), 配置: \(configFile?.name ?? "无")")
            
            if let configFile = configFile {
                // 解析配置文件
                self.storageService.getJSONFile(reference: configFile, type: Newsletter.NewsletterConfig.self) { config, error in
                    if let error = error {
                        print("解析Newsletter配置失败: \(error.localizedDescription)")
                        completion(nil)
                        return
                    }
                    
                    if let config = config {
                        let caption = NewsletterCaption(
                            chinese: config.captions.chinese,
                            english: config.captions.english,
                            korean: config.captions.korean
                        )
                        
                        let newsletter = Newsletter(
                            id: folderName,
                            publishDate: DateFormatter.parseNewsletterDate(from: config.publishDate) ?? Date(),
                            imageURLs: imageFiles.map { "newsletters/\(folderName)/\($0.name)" },
                            caption: caption,
                            isPublished: config.isPublished ?? true
                        )
                        completion(newsletter)
                    } else {
                        completion(nil)
                    }
                }
            } else {
                // 如果没有配置文件，使用默认值
                self.createDefaultNewsletter(folderName: folderName, imageFiles: imageFiles, completion: completion)
            }
        }
    }
    
    private func createDefaultNewsletter(folderName: String, imageFiles: [StorageReference], completion: @escaping (Newsletter?) -> Void) {
        let caption = NewsletterCaption(
            chinese: "默认Newsletter内容 - \(folderName)",
            english: "Default Newsletter Content - \(folderName)",
            korean: "기본 Newsletter 내용 - \(folderName)"
        )
        
        let newsletter = Newsletter(
            id: folderName,
            publishDate: Date(),
            imageURLs: imageFiles.map { "newsletters/\(folderName)/\($0.name)" },
            caption: caption,
            isPublished: true
        )
        completion(newsletter)
    }
}

// 自定义圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

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