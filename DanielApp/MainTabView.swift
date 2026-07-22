import SwiftUI

// MARK: - 现代化的自定义TabView
struct MainTabView: View {
    @StateObject private var tabSelection = TabSelection()
    @EnvironmentObject var appState: AppState
    
    // App shell: Daily Verse, Connect, Resources, Settings.
    let tabItems: [(icon: String, title: (CoreModels.VerseLanguage) -> String, tag: Int)] = [
        ("house", { language in LocalizedText.Common.dailyVerse.text(for: language) }, 0),
        ("person.2", { language in LocalizedText.Common.communicationTab.text(for: language) }, 1),
        ("books.vertical", { language in LocalizedText.Common.resourcesTab.text(for: language) }, 2),
        ("gearshape", { language in LocalizedText.Common.settings.text(for: language) }, 3)
    ]
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Group {
                    switch tabSelection.selectedTab {
                    case 0:
                        VerseOfTheDayView()
                    case 1:
                        ChurchCommunicationView()
                    case 2:
                        ChurchResourcesView()
                    case 3:
                        SettingsView()
                    default:
                        VerseOfTheDayView()
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
            if newValue >= 0 && newValue <= 3 {
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
                tabSelection.selectedTab = 3
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
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(DesignSystem.Colors.surface)
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
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? DesignSystem.Colors.accentDark : DesignSystem.Colors.mutedText)
                    .frame(height: 24)
                
                Text(title)
                    .font(DesignSystem.Typography.smart(12, weight: .regular, language: language))
                    .foregroundColor(isSelected ? DesignSystem.Colors.accentDark : DesignSystem.Colors.mutedText)
                    .lineLimit(1)
                    .frame(height: 14)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? DesignSystem.Colors.cardBackground : Color.clear)
            )
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
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
