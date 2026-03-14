import SwiftUI
import WebKit

struct PraiseView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var viewModel = PraiseViewModel()
    @State private var showingLogin = false
    @State private var searchText = ""
    
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
                        PraiseContentView(viewModel: viewModel, searchText: $searchText)
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

// 赞美列表内容视图 - Bookshelf style with search
struct PraiseContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: PraiseViewModel
    @Binding var searchText: String
    
    var filteredPraises: [Praise] {
        if searchText.isEmpty {
            return viewModel.praises
        }
        return viewModel.praises.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
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
            VStack(spacing: 0) {
                // 搜索栏
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    TextField("搜索乐谱...", text: $searchText)
                        .font(DesignSystem.Typography.body(DesignSystem.Typography.body, language: appState.selectedLanguage))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                }
                .padding(12)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal, StyleConstants.standardSpacing)
                .padding(.vertical, 8)
                
                // 书架列表 - 只显示标题，不加载文件内容
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPraises) { praise in
                            NavigationLink(destination: PraiseDetailView(praise: praise, language: appState.selectedLanguage)) {
                                PraiseShelfRow(praise: praise, language: appState.selectedLanguage)
                            }
                            
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                    .padding(.bottom, StyleConstants.mediumSpacing)
                }
            }
        }
    }
}

// 书架行 - 不加载任何文件内容，节省流量
struct PraiseShelfRow: View {
    let praise: Praise
    let language: CoreModels.VerseLanguage
    
    var fileTypeIcon: String {
        if let firstUrl = praise.fileUrls.first?.lowercased() {
            if firstUrl.contains(".pdf") || firstUrl.contains("pdf") {
                return "doc.richtext"
            } else if firstUrl.contains("image") || firstUrl.contains(".jpg") || firstUrl.contains(".png") {
                return "photo"
            }
        }
        return "music.note.list"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 文件图标
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                DesignSystem.Colors.accent.opacity(0.2),
                                DesignSystem.Colors.accent.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                Image(systemName: fileTypeIcon)
                    .font(.system(size: 22))
                    .foregroundColor(DesignSystem.Colors.accent)
            }
            
            // 标题和日期
            VStack(alignment: .leading, spacing: 4) {
                Text(praise.title)
                    .font(DesignSystem.Typography.body(DesignSystem.Typography.body, weight: .medium, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)
                
                Text(DateFormatter.newsletterFormatter.string(from: praise.uploadedAt.dateValue()))
                    .font(DesignSystem.Typography.smart(DesignSystem.Typography.footnote, language: language))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            
            Spacer()
            
            // 文件数量标签
            if praise.fileUrls.count > 1 {
                Text("\(praise.fileUrls.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(DesignSystem.Colors.accent)
                    .clipShape(Circle())
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.secondaryText.opacity(0.5))
        }
        .padding(.horizontal, StyleConstants.standardSpacing)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
}

// 详情页 - 查看乐谱文件（点进来才加载内容，节省流量）
struct PraiseDetailView: View {
    let praise: Praise
    let language: CoreModels.VerseLanguage
    @State private var currentIndex = 0
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            if praise.fileUrls.isEmpty {
                VStack {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text("没有文件")
                        .font(DesignSystem.Typography.body(DesignSystem.Typography.body, language: language))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            } else if praise.fileUrls.count == 1 {
                // 单文件：直接全屏显示
                FileContentView(urlStr: praise.fileUrls[0])
            } else {
                // 多文件：TabView 滑动切换
                TabView(selection: $currentIndex) {
                    ForEach(0..<praise.fileUrls.count, id: \.self) { index in
                        FileContentView(urlStr: praise.fileUrls[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
        }
        .navigationTitle(praise.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 通用文件内容视图 - 处理图片和PDF
struct FileContentView: View {
    let urlStr: String
    
    var isPDF: Bool {
        let lower = urlStr.lowercased()
        return lower.contains(".pdf") || lower.contains("application%2fpdf") || lower.contains("application/pdf")
    }
    
    var body: some View {
        if let url = URL(string: urlStr) {
            if isPDF {
                // PDF 使用 WebView 渲染
                WebView(url: url)
                    .ignoresSafeArea(edges: .bottom)
            } else {
                // 图片使用 AsyncImage + 可缩放滚动
                ScrollView(.vertical, showsIndicators: true) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFit()
                        } else if phase.error != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                Text("无法加载图片")
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                Link("在浏览器中打开", destination: url)
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent))
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                        }
                    }
                }
            }
        }
    }
}

// WKWebView wrapper for PDF rendering
struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 5.0
        webView.backgroundColor = .systemBackground
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

// 预览
struct PraiseView_Previews: PreviewProvider {
    static var previews: some View {
        PraiseView()
            .environmentObject(AppState())
    }
}
