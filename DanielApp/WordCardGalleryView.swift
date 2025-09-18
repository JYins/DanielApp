import SwiftUI
import FirebaseStorage
// No need to import CoreModels, it's part of the target

struct WordCardGalleryView: View {
    @EnvironmentObject var appState: AppState // Access AppState for language
    @StateObject private var viewModel = WordCardViewModel()
    @StateObject private var authManager = AuthManager.shared

    // Define category keys for localization and state management
    let categoryKeys: [LocalizedText.WordCardGallery] = [.categoryAll, .categoryGrace, .categoryEncouragement, .categoryWisdom]
    @State private var selectedCategoryKey: LocalizedText.WordCardGallery = .categoryAll

    // Filtered cards based on selected category key
    var filteredCards: [WordCard] {
        if selectedCategoryKey == .categoryAll {
            return viewModel.cards
        } else {
            return viewModel.cards.filter { $0.categoryKey == selectedCategoryKey }
        }
    }

    var body: some View {
        ZStack {
            // 背景色
            DesignSystem.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部标题区域
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text(LocalizedText.WordCardGallery.navTitle.text(for: appState.selectedLanguage))
                            .font(DesignSystem.Typography.title(DesignSystem.Typography.title1, weight: .bold, language: appState.selectedLanguage))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.contentMargin)
                    .padding(.top, DesignSystem.Spacing.lg)
                }
                
                // 分类选择器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(categoryKeys, id: \.self) { key in
                            let categoryText = key.text(for: appState.selectedLanguage)
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategoryKey = key
                                }
                            } label: {
                                Text(categoryText)
                                    .font(DesignSystem.Typography.smart(DesignSystem.Typography.callout, weight: .medium, language: appState.selectedLanguage))
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                                    .padding(.vertical, DesignSystem.Spacing.sm)
                                    .background(
                                        selectedCategoryKey == key ? 
                                        DesignSystem.Colors.accent :
                                        DesignSystem.Colors.cardBackground
                                    )
                                    .foregroundColor(
                                        selectedCategoryKey == key ? 
                                        Color.white : 
                                        DesignSystem.Colors.primaryText
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                selectedCategoryKey == key ? 
                                                DesignSystem.Colors.accent : 
                                                DesignSystem.Colors.border, 
                                                lineWidth: selectedCategoryKey == key ? 0 : 1
                                            )
                                    )
                                    .shadow(
                                        color: selectedCategoryKey == key ? 
                                        DesignSystem.Colors.accent.opacity(0.3) : Color.clear, 
                                        radius: 4, x: 0, y: 2
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.contentMargin)
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
                .background(DesignSystem.Colors.background)

                // 内容区域
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent))
                        .scaleEffect(1.2)
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Text("加载出错")
                            .font(DesignSystem.Typography.title(DesignSystem.Typography.title3, weight: .semibold, language: appState.selectedLanguage))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        Text(errorMessage)
                            .font(DesignSystem.Typography.body(DesignSystem.Typography.callout))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                        
                        Button("重试") {
                            viewModel.loadCards()
                        }
                        .buttonStyle(ModernButtonStyle(language: appState.selectedLanguage))
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .modernCard()
                    .padding(.horizontal, DesignSystem.Spacing.contentMargin)
                    Spacer()
                } else if filteredCards.isEmpty {
                    Spacer()
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.mutedText)
                        
                        Text("没有找到卡片")
                            .font(DesignSystem.Typography.body(DesignSystem.Typography.callout, language: appState.selectedLanguage))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    Spacer()
                } else {
                    // 话语卡片列表
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.lg) {
                            ForEach(filteredCards) { card in
                                ModernWordCardView(card: card, language: appState.selectedLanguage)
                            }
                        }
                        .padding(.top, DesignSystem.Spacing.md)
                        .padding(.bottom, DesignSystem.Spacing.xxl)
                        .padding(.horizontal, DesignSystem.Spacing.contentMargin)
                    }
                }
            }
        }
        .watermark("@但以理和他的朋友们")
        .onAppear {
            // 话语卡片无需登录即可查看
            viewModel.loadCards()
        }
    }
}

// Firebase版本的卡片视图
struct FirebaseWordCardView: View {
    let card: WordCard
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
            
            // 重新设计的文案区域
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
                Text(card.caption.text(for: language))
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
        images = Array(repeating: nil, count: card.images.count)
        
        let group = DispatchGroup()
        
        for (index, imageRef) in card.images.enumerated() {
            group.enter()
            
            FirebaseStorageService.shared.downloadImage(from: imageRef) { image, error in
                defer { group.leave() }
                
                if let image = image {
                    DispatchQueue.main.async {
                        // 更新特定索引的图片
                        if index < self.images.count {
                            self.images[index] = image
                        }
                    }
                } else if let error = error {
                    print("加载图片失败: \(error.localizedDescription)")
                }
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
        }
    }
}

// Preview Provider
struct WordCardGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock AppState for the preview
        let mockAppState = AppState()
        // Optionally set a specific language for preview
        // mockAppState.selectedLanguage = .chinese

        WordCardGalleryView()
            .environmentObject(mockAppState) // Inject the mock AppState
            .preferredColorScheme(.dark) // Preview in dark mode to match background
    }
}

// Ensure AppState is available or create a basic one if not already defined elsewhere
// This might already exist in your project (e.g., in DanielAppApp.swift or a shared models file)
// If not, you might need to add a basic definition like this:
/*
 import Combine
 import CoreModels

 class AppState: ObservableObject {
     @Published var selectedLanguage: CoreModels.VerseLanguage = .chinese // Default language
     @Published var selectedTab: Int = 0
     @Published var selectedVerseReference: String? = nil
     // Add other relevant state properties here
 }
 */
// Note: CoreModels.VerseLanguage is defined in DanielApp/SharedModels/VerseModels.swift

// MARK: - 现代化话语卡片组件
struct ModernWordCardView: View {
    let card: WordCard
    let language: CoreModels.VerseLanguage
    @State private var currentImageIndex = 0
    @State private var images: [UIImage?] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 图片区域
            ZStack(alignment: .bottom) {
                if isLoading {
                    Rectangle()
                        .fill(DesignSystem.Colors.mutedText.opacity(0.1))
                        .aspectRatio(1080/1350, contentMode: .fit)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent))
                                .scaleEffect(1.2)
                        )
                } else if images.isEmpty {
                    Rectangle()
                        .fill(DesignSystem.Colors.mutedText.opacity(0.1))
                        .aspectRatio(1080/1350, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(DesignSystem.Colors.mutedText)
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
                                    .fill(DesignSystem.Colors.mutedText.opacity(0.1))
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
            .cornerRadius(DesignSystem.CornerRadius.card, corners: [.topLeft, .topRight])
            
            // 文案区域
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // 装饰性分隔线
                HStack {
                    Rectangle()
                        .fill(DesignSystem.Colors.accent.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                    
                    Spacer()
                    
                    Image(systemName: "quote.opening")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(DesignSystem.Colors.accent.opacity(0.6))
                }
                
                // 文案内容
                Text(card.caption.text(for: language))
                    .font(DesignSystem.Typography.body(DesignSystem.Typography.callout, weight: .regular, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(DesignSystem.Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(DesignSystem.CornerRadius.card, corners: [.bottomLeft, .bottomRight])
        }
        .modernCard()
        .onAppear {
            loadImages()
        }
    }
    
    private func loadImages() {
        isLoading = true
        images = Array(repeating: nil, count: card.images.count)
        
        let group = DispatchGroup()
        
        for (index, imageRef) in card.images.enumerated() {
            group.enter()
            
            FirebaseStorageService.shared.downloadImage(from: imageRef) { image, error in
                defer { group.leave() }
                
                if let image = image {
                    DispatchQueue.main.async {
                        if index < self.images.count {
                            self.images[index] = image
                        }
                    }
                } else if let error = error {
                    print("加载图片失败: \(error.localizedDescription)")
                }
            }
        }
        
        group.notify(queue: .main) {
            isLoading = false
        }
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

