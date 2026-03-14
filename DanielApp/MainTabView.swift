import SwiftUI

// MARK: - 现代化的自定义TabView
struct MainTabView: View {
    @StateObject private var tabSelection = TabSelection()
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    
    // Tab配置 - 移除设置选项，添加赞美页面
    let tabItems: [(icon: String, title: (CoreModels.VerseLanguage) -> String, tag: Int)] = [
        ("book.fill", { language in LocalizedText.Common.dailyVerse.text(for: language) }, 0),
        ("quote.bubble.fill", { language in LocalizedText.Common.wordCardsTab.text(for: language) }, 1),
        ("newspaper.fill", { language in LocalizedText.Common.newsletterTab.text(for: language) }, 2),
        ("music.note", { language in LocalizedText.Common.praiseTab.text(for: language) }, 3),
        ("link", { language in LocalizedText.Common.connect.text(for: language) }, 4)
    ]
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 主内容区域 - 添加右上角设置按钮
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
                            PraiseView()
                        case 4:
                            ConnectView()
                        default:
                            VerseOfTheDayView()
                        }
                    }
                    
                    // 右上角设置按钮 - 小方条样式，紧靠右边
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            
                            Button(action: {
                                showSettings = true
                            }) {
                                Image(systemName: "gear")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.accent)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(DesignSystem.Colors.cardBackground)
                                            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 60) // 避开状态栏
                        
                        Spacer(minLength: 0)
                    }
                }
                
                // 自定义Tab Bar
                ModernTabBar(
                    selectedTab: $tabSelection.selectedTab,
                    tabItems: tabItems,
                    selectedLanguage: appState.selectedLanguage
                )
            }
            
            // 设置页面叠加层
            if showSettings {
                SettingsOverlayView(
                    showSettings: $showSettings,
                    language: appState.selectedLanguage
                )
                .zIndex(999)
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
            // 确保新值是有效的tab索引（0-4，不包括原来的设置tab）
            if newValue >= 0 && newValue <= 4 {
                tabSelection.selectedTab = newValue
            }
        }
        .onChange(of: appState.selectedVerseReference) { newValue in
            if newValue != nil {
                // 如果从Widget点击进来，切换到第一个标签
                tabSelection.selectedTab = 0
            }
        }
        .onChange(of: appState.needsShowSettings) { newValue in
            // 如果需要显示设置页面，显示设置叠加层
            if newValue {
                showSettings = true
                appState.needsShowSettings = false
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
                            selectedTab = item.tag
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
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - 设置页面叠加层
struct SettingsOverlayView: View {
    @Binding var showSettings: Bool
    @EnvironmentObject var appState: AppState
    let language: CoreModels.VerseLanguage
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showSettings = false
                }
            
            // 设置页面内容
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    
                    // 右上角关闭按钮
                    Button(action: {
                        showSettings = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.accent)
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(DesignSystem.Colors.cardBackground)
                                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                            )
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 70)
                }
                
                // 设置页面内容
                SettingsView()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
        }
    }
}

// Removed PraiseViewPlaceholder
// MARK: - 自定义半圆形状（贴右边）
struct HalfCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // 创建一个半圆，圆心在右边边界上
        path.addArc(
            center: CGPoint(x: rect.maxX, y: rect.midY),
            radius: rect.height / 2,
            startAngle: .degrees(90),
            endAngle: .degrees(270),
            clockwise: false
        )
        // 添加直线连接到右边边界
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 左半圆形状（为设置按钮优化）
struct LeftHalfCircleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // 计算圆的半径，使用高度的一半
        let radius = rect.height / 2
        // 圆心位置：在矩形右边界上，垂直居中
        let center = CGPoint(x: rect.maxX, y: rect.midY)
        
        // 创建左半圆（从上方90度到下方270度）
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(90),  // 从顶部开始
            endAngle: .degrees(270),   // 到底部结束
            clockwise: false
        )
        
        // 连接弧线到右边界，形成封闭的半圆
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 可观察的标签选择
class TabSelection: ObservableObject {
    @Published var selectedTab: Int = 0
}
