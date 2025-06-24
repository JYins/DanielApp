import SwiftUI
import FirebaseStorage
// No need to import CoreModels, it's part of the target

struct WordCardGalleryView: View {
    @EnvironmentObject var appState: AppState // Access AppState for language
    @StateObject private var viewModel = WordCardViewModel()

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
        NavigationView { // Use NavigationView for potential title/navigation bar features
            VStack(spacing: 0) {
                // 添加与其他页面一致的标题
                Text(LocalizedText.WordCardGallery.navTitle.text(for: appState.selectedLanguage))
                    .font(StyleConstants.serifTitle(24, language: appState.selectedLanguage))
                    .foregroundColor(StyleConstants.goldColor)
                    .padding(.top, StyleConstants.standardSpacing)
                    .padding(.bottom, StyleConstants.compactSpacing)
                
                // 添加分隔线
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
                
                // Category Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: StyleConstants.compactSpacing + 2) {
                        ForEach(categoryKeys, id: \.self) { key in
                            let categoryText = key.text(for: appState.selectedLanguage)
                            Button {
                                selectedCategoryKey = key
                            } label: {
                                Text(categoryText)
                                    .font(StyleConstants.sansFontBody(14))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedCategoryKey == key ? 
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                StyleConstants.goldColor,
                                                StyleConstants.goldColor.opacity(0.8)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ) :
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.15),
                                                Color.white.opacity(0.1)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .foregroundColor(selectedCategoryKey == key ? Color(hex: "#020f2e") : Color.white)
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                selectedCategoryKey == key ? 
                                                StyleConstants.goldColor.opacity(0.3) : 
                                                StyleConstants.goldColor.opacity(0.4), 
                                                lineWidth: selectedCategoryKey == key ? 0.5 : 1
                                            )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(
                                        color: selectedCategoryKey == key ? 
                                        StyleConstants.goldColor.opacity(0.3) : Color.clear, 
                                        radius: 4, x: 0, y: 2
                                    )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, StyleConstants.compactSpacing)
                }
                .background(Color(hex: "#020f2e")) // Ensure background covers pill area

                // Content area - conditionally show loading, error, or cards
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
                            viewModel.loadCards()
                        }
                        .padding()
                        .background(StyleConstants.goldColor)
                        .foregroundColor(Color(hex: "#020f2e"))
                        .cornerRadius(8)
                    }
                    Spacer()
                } else if filteredCards.isEmpty {
                    Spacer()
                    Text("没有找到卡片")
                        .font(StyleConstants.serifBody(16, language: appState.selectedLanguage))
                        .foregroundColor(.white)
                    Spacer()
                } else {
                    // Gallery List with actual card data
                    ScrollView {
                        LazyVStack(spacing: StyleConstants.mediumSpacing - 2) {
                            ForEach(filteredCards) { card in
                                FirebaseWordCardView(card: card, language: appState.selectedLanguage)
                                    .padding(.horizontal, 12)
                            }
                        }
                        .padding(.top, StyleConstants.standardSpacing)
                        .padding(.bottom, StyleConstants.mediumSpacing)
                    }
                }
            }
            .background(Color(hex: "#020f2e").edgesIgnoringSafeArea(.all)) // Set background color
            .navigationBarHidden(true) // 隐藏导航栏，避免与自定义标题重复
            .onAppear {
                viewModel.loadCards() // 加载卡片数据
                
                // 设置导航栏外观
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(Color(hex: "#020f2e"))
                appearance.titleTextAttributes = [.foregroundColor: UIColor(StyleConstants.goldColor)]
                appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(StyleConstants.goldColor)]

                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
            }
        }
        .navigationViewStyle(.stack) // Use stack style for consistent behavior
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
