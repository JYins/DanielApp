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
                    .font(StyleConstants.sansFontBody(14, language: appState.selectedLanguage))
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
            
            Text(LocalizedText.NewsletterView.title.text(for: appState.selectedLanguage))
                .font(StyleConstants.serifTitle(22, language: appState.selectedLanguage))
                .foregroundColor(StyleConstants.goldColor)
            
            Text(LocalizedText.NewsletterView.loginPrompt.text(for: appState.selectedLanguage))
                .font(StyleConstants.sansFontBody(16, language: appState.selectedLanguage))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                showingLogin = true
            }) {
                Text(LocalizedText.NewsletterView.loginButton.text(for: appState.selectedLanguage))
                    .font(StyleConstants.sansFontBody(18, language: appState.selectedLanguage))
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
    @EnvironmentObject var appState: AppState
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
                        .font(StyleConstants.sansFontBody(14, language: appState.selectedLanguage))
                        .foregroundColor(StyleConstants.goldColor)
                        .lineLimit(1)
                } else {
                    Text(LocalizedText.NewsletterView.defaultUserName.text(for: appState.selectedLanguage))
                        .font(StyleConstants.sansFontBody(14, language: appState.selectedLanguage))
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
                        .aspectRatio(1004.0/1440.0, contentMode: .fit) // Newsletter专用尺寸比例
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: StyleConstants.goldColor))
                                .scaleEffect(1.2)
                        )
                } else if images.isEmpty {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(1004.0/1440.0, contentMode: .fit) // Newsletter专用尺寸比例
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
                    .aspectRatio(1004.0/1440.0, contentMode: .fit) // Newsletter专用尺寸比例
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
        
        // 添加测试Newsletter来验证文字显示
        addTestNewsletter()
        
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
                
                // 调试：下载配置文件进行检查
                self.downloadConfigForDebug(folderName: folder)
                
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
                print("正在解析Newsletter配置文件: \(configFile.name)")
                
                self.storageService.getJSONFile(reference: configFile, type: Newsletter.NewsletterConfig.self) { config, error in
                    if let error = error {
                        print("❌ 解析Newsletter配置失败: \(error.localizedDescription)")
                        // 尝试读取为文本，看看内容是什么
                        self.storageService.getTextFile(reference: configFile) { text, _ in
                            if let text = text {
                                print("📄 配置文件内容: \(text)")
                            }
                        }
                        // 使用默认值而不是返回nil
                        self.createDefaultNewsletter(folderName: folderName, imageFiles: imageFiles, completion: completion)
                        return
                    }
                    
                    if let config = config {
                        print("✅ 成功解析Newsletter配置，文字内容：")
                        print("  - 中文: \(config.captions.chinese)")
                        print("  - 英文: \(config.captions.english)")
                        print("  - 韩文: \(config.captions.korean)")
                        
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
                        
                        print("✅ 创建Newsletter成功，ID: \(folderName)")
                        completion(newsletter)
                    } else {
                        print("❌ 配置解析结果为nil")
                        self.createDefaultNewsletter(folderName: folderName, imageFiles: imageFiles, completion: completion)
                    }
                }
            } else {
                // 如果没有配置文件，使用默认值
                self.createDefaultNewsletter(folderName: folderName, imageFiles: imageFiles, completion: completion)
            }
        }
    }
    
    private func createDefaultNewsletter(folderName: String, imageFiles: [StorageReference], completion: @escaping (Newsletter?) -> Void) {
        print("⚠️ 为\(folderName)创建默认Newsletter")
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
    
    // 添加测试Newsletter来验证文字显示
    private func addTestNewsletter() {
        print("🧪 添加测试Newsletter")
        let testCaption = NewsletterCaption(
            chinese: "【测试】亲爱的弟兄姐妹们，新年快乐！愿主的恩典与平安常与你们同在。这个月我们一同学习了关于信心的功课，让我们继续在主的道路上前行。",
            english: "【Test】Dear brothers and sisters, Happy New Year! May the grace and peace of the Lord be with you always. This month we learned about faith together, let us continue on the Lord's path.",
            korean: "【테스트】사랑하는 형제자매 여러분, 새해 복 많이 받으세요! 주님의 은혜와 평안이 항상 여러분과 함께하시길 기원합니다. 이번 달 우리는 함께 믿음에 대해 배웠습니다. 계속해서 주님의 길을 걸어갑시다."
        )
        
        let testNewsletter = Newsletter(
            id: "test-2025-01",
            publishDate: Date(),
            imageURLs: [], // 暂时没有图片
            caption: testCaption,
            isPublished: true
        )
        
        DispatchQueue.main.async {
            self.newsletters.insert(testNewsletter, at: 0) // 插入到最前面
            print("✅ 测试Newsletter已添加")
        }
    }
    
    // 新增调试方法：直接下载配置文件进行检查
    private func downloadConfigForDebug(folderName: String) {
        storageService.getFilesInNewsletterFolder(folderName: folderName) { [weak self] files, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 调试：获取\(folderName)文件失败: \(error.localizedDescription)")
                return
            }
            
            print("🔍 调试：\(folderName)文件夹包含的文件:")
            for file in files {
                print("  - \(file.name) (全路径: \(file.fullPath))")
            }
            
            if let configFile = files.first(where: { $0.name.lowercased() == "config.json" }) {
                print("🔍 调试：找到配置文件\(configFile.name)，正在下载...")
                
                self.storageService.getTextFile(reference: configFile) { text, error in
                    if let error = error {
                        print("❌ 调试：下载配置文件失败: \(error.localizedDescription)")
                    } else if let text = text {
                        print("📄 调试：配置文件原始内容:")
                        print(text)
                        
                        // 尝试手动解析JSON
                        if let data = text.data(using: .utf8) {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data, options: [])
                                print("📄 调试：JSON解析成功:")
                                print(json)
                            } catch {
                                print("❌ 调试：JSON解析失败: \(error)")
                            }
                        }
                    }
                }
            } else {
                print("❌ 调试：未找到config.json文件")
            }
        }
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