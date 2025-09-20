import SwiftUI

// MARK: - 现代化的自定义TabView
struct MainTabView: View {
    @StateObject private var tabSelection = TabSelection()
    @EnvironmentObject var appState: AppState
    
    // Tab配置
    let tabItems: [(icon: String, title: (CoreModels.VerseLanguage) -> String, tag: Int)] = [
        ("book.fill", { language in LocalizedText.Common.dailyVerse.text(for: language) }, 0),
        ("quote.bubble.fill", { language in LocalizedText.Common.wordCardsTab.text(for: language) }, 1),
        ("newspaper.fill", { language in LocalizedText.Common.newsletterTab.text(for: language) }, 2),
        ("gear", { language in LocalizedText.Common.settings.text(for: language) }, 3),
        ("link", { language in LocalizedText.Common.connect.text(for: language) }, 4)
    ]
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 主内容区域
                ZStack {
                    Group {
                        switch tabSelection.selectedTab {
                        case 0:
                            VerseOfTheDayView()
                        case 1:
                            WordCardGalleryView()
                        case 2:
                            NewsletterView()
                        case 3:
                            SettingsView()
                        case 4:
                            ConnectView()
                        default:
                            VerseOfTheDayView()
                        }
                    }
                }
                
                // 自定义Tab Bar
                ModernTabBar(
                    selectedTab: $tabSelection.selectedTab,
                    tabItems: tabItems,
                    selectedLanguage: appState.selectedLanguage
                )
            }
        }
        .onAppear {
            // 将tabSelection与appState同步
            appState.selectedTab = tabSelection.selectedTab
        }
        .onChange(of: tabSelection.selectedTab) { newValue in
            // 保持同步
            appState.selectedTab = newValue
        }
        .onChange(of: appState.selectedTab) { newValue in
            // 如果appState的selectedTab改变，更新tabSelection
            tabSelection.selectedTab = newValue
        }
        .onChange(of: appState.selectedVerseReference) { newValue in
            if newValue != nil {
                // 如果从Widget点击进来，切换到第一个标签
                tabSelection.selectedTab = 0
            }
        }
    }
}

// MARK: - 现代化TabBar组件
struct ModernTabBar: View {
    @Binding var selectedTab: Int
    let tabItems: [(icon: String, title: (CoreModels.VerseLanguage) -> String, tag: Int)]
    let selectedLanguage: CoreModels.VerseLanguage
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部细线分隔
            Rectangle()
                .fill(DesignSystem.Colors.divider)
                .frame(height: 0.5)
            
            HStack(spacing: 0) {
                ForEach(tabItems, id: \.tag) { item in
                    TabBarButton(
                        icon: item.icon,
                        title: item.title(selectedLanguage),
                        isSelected: selectedTab == item.tag,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = item.tag
                            }
                        },
                        language: selectedLanguage
                    )
                }
            }
            .padding(.top, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.md)
            .background(
                DesignSystem.Colors.background
                    .overlay(
                        // 轻微的背景模糊效果
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                    )
            )
        }
    }
}

// MARK: - TabBar按钮组件
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    let language: CoreModels.VerseLanguage // 添加语言参数
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                                  // 图标
                  Image(systemName: icon)
                     .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                      .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.mutedText)
                    .frame(height: 24)
                
                // 标题
                Text(title)
                    .font(DesignSystem.Typography.smart(DesignSystem.Typography.caption, weight: isSelected ? .medium : .regular, language: language))
                    .foregroundColor(isSelected ? DesignSystem.Colors.primaryText : DesignSystem.Colors.mutedText)
                    .lineLimit(1)
                    .frame(height: 14)
                
                // 橙色指示条
                Rectangle()
                    .fill(isSelected ? DesignSystem.Colors.accent : Color.clear)
                    .frame(width: isSelected ? 24 : 0, height: 3)
                    .cornerRadius(1.5)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - 可观察的标签选择
class TabSelection: ObservableObject {
    @Published var selectedTab: Int = 0
}
