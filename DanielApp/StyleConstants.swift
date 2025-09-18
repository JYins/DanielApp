import SwiftUI

// MARK: - 全新的设计系统
struct DesignSystem {
    
    // MARK: - 颜色系统
    struct Colors {
        // 主要背景色 - 极浅米粉色
        static let background = Color(hex: "#f9f2ef")
        
        // 卡片和内容区域 - 淡绿半透明
        static let cardBackground = Color(hex: "#e1eac1").opacity(0.6)
        static let cardBackgroundSolid = Color(hex: "#e1eac1")
        
        // 文字颜色 - 深灰色系
        static let primaryText = Color(hex: "#4a4a4a")
        static let secondaryText = Color(hex: "#6a6a6a")
        static let mutedText = Color(hex: "#8a8a8a")
        
        // 强调色 - 橙色
        static let accent = Color(hex: "#f98c53")
        static let accentLight = Color(hex: "#f98c53").opacity(0.7)
        
        // 水印色 - 淡金色
        static let watermark = Color(hex: "#e0b199")
        
        // 边框和分隔线
        static let border = Color(hex: "#d0d0d0")
        static let divider = Color(hex: "#e5e5e5")
        
        // 问候区域背景
        static let greetingBackground = Color.white.opacity(0.8)
        
        // 按钮颜色
        static let buttonBorder = Color(hex: "#4a4a4a")
        static let buttonBackground = Color.clear
        static let buttonBackgroundPressed = Color(hex: "#4a4a4a").opacity(0.1)
    }
    
    // MARK: - 间距系统
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        
        // 特定用途的间距
        static let cardPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 28
        static let buttonPadding: CGFloat = 14
        static let contentMargin: CGFloat = 20
    }
    
    // MARK: - 圆角系统
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let card: CGFloat = 16
        static let button: CGFloat = 12
    }
    
    // MARK: - 字体系统
    struct Typography {
        // 标题字体
        static func title(_ size: CGFloat, weight: Font.Weight = .bold, language: CoreModels.VerseLanguage = .chinese) -> Font {
            switch language {
            case .chinese:
                return Font.custom("AidianFengYaHeiChangTi", size: size).weight(weight)
            case .english:
                return Font.system(size: size, weight: weight, design: .rounded)
            case .korean:
                return Font.custom("GowunDodum-Regular", size: size).weight(weight)
            }
        }
        
        // 正文字体
        static func body(_ size: CGFloat, weight: Font.Weight = .regular, language: CoreModels.VerseLanguage = .chinese) -> Font {
            switch language {
            case .chinese:
                return Font.custom("AidianFengYaHeiChangTi", size: size).weight(weight)
            case .english:
                return Font.system(size: size, weight: weight, design: .rounded)
            case .korean:
                return Font.custom("GowunDodum-Regular", size: size).weight(weight)
            }
        }
        
        // 系统字体（用于按钮等UI元素）
        static func system(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return Font.system(size: size, weight: weight)
        }
        
        // 智能字体：根据上下文自动选择合适的字体
        static func smart(_ size: CGFloat, weight: Font.Weight = .regular, language: CoreModels.VerseLanguage? = nil, preferLanguageFont: Bool = true) -> Font {
            // 如果明确指定了语言且希望使用语言字体，则使用对应语言字体
            if let language = language, preferLanguageFont {
                return body(size, weight: weight, language: language)
            }
            // 否则使用系统字体
            return Font.system(size: size, weight: weight)
        }
        
        // 预设字体大小 - 全部放大
        static let largeTitle: CGFloat = 34
        static let title1: CGFloat = 30
        static let title2: CGFloat = 26
        static let title3: CGFloat = 22
        static let headline: CGFloat = 19
        static let body: CGFloat = 17
        static let callout: CGFloat = 16
        static let subhead: CGFloat = 15
        static let footnote: CGFloat = 14
        static let caption: CGFloat = 13
    }
    
    // MARK: - 阴影系统
    struct Shadow {
        static let card = (color: Color.black.opacity(0.08), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(2))
        static let elevated = (color: Color.black.opacity(0.12), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(4))
        static let soft = (color: Color.black.opacity(0.04), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(1))
    }
}

struct StyleConstants {
    // 向后兼容的颜色定义
    static let backgroundColor = DesignSystem.Colors.background
    static let goldColor = DesignSystem.Colors.primaryText
    static let lightGoldColor = DesignSystem.Colors.secondaryText
    
    // 向后兼容的间距定义
    static let compactSpacing = DesignSystem.Spacing.sm
    static let standardSpacing = DesignSystem.Spacing.md
    static let mediumSpacing = DesignSystem.Spacing.lg
    static let largeSpacing = DesignSystem.Spacing.xl
    static let extraLargeSpacing = DesignSystem.Spacing.xxl
    
    static let containerPadding = DesignSystem.Spacing.md
    static let cardPadding = DesignSystem.Spacing.cardPadding
    static let buttonPadding = DesignSystem.Spacing.buttonPadding
    
    // 向后兼容的字体定义
    static func serifTitle(_ size: CGFloat, language: CoreModels.VerseLanguage = .chinese) -> Font {
        return DesignSystem.Typography.title(size, language: language)
    }
    
    static func serifBody(_ size: CGFloat, language: CoreModels.VerseLanguage = .chinese) -> Font {
        return DesignSystem.Typography.body(size, language: language)
    }
    
    static func sansFontBody(_ size: CGFloat, language: CoreModels.VerseLanguage = .chinese) -> Font {
        return DesignSystem.Typography.smart(size, language: language)
    }
    
    // 向后兼容的按钮样式
    static let buttonCornerRadius = DesignSystem.CornerRadius.button
    static let buttonBorderWidth: CGFloat = 1.5
}

// MARK: - 组件样式
struct ModernCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
            )
            .shadow(
                color: DesignSystem.Shadow.card.color,
                radius: DesignSystem.Shadow.card.radius,
                x: DesignSystem.Shadow.card.x,
                y: DesignSystem.Shadow.card.y
            )
    }
}

struct ModernButtonStyle: ButtonStyle {
    var language: CoreModels.VerseLanguage = .chinese
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignSystem.Spacing.buttonPadding + 6)
            .padding(.vertical, DesignSystem.Spacing.buttonPadding + 2)
            .font(DesignSystem.Typography.smart(DesignSystem.Typography.body, weight: .medium, language: language))
            .foregroundColor(DesignSystem.Colors.primaryText)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .stroke(DesignSystem.Colors.cardBackgroundSolid, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                            .fill(configuration.isPressed ? DesignSystem.Colors.cardBackground : DesignSystem.Colors.buttonBackground)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GreetingBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.greetingBackground)
            .cornerRadius(DesignSystem.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                    .stroke(DesignSystem.Colors.border.opacity(0.3), lineWidth: 0.5)
            )
    }
}

struct WatermarkStyle: ViewModifier {
    let text: String
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
            
            Text(text)
                .font(DesignSystem.Typography.system(DesignSystem.Typography.footnote))
                .foregroundColor(DesignSystem.Colors.watermark)
                .padding(.bottom, DesignSystem.Spacing.md)
                .padding(.trailing, DesignSystem.Spacing.md)
        }
    }
}

// 向后兼容的按钮样式
struct GoldBorderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, DesignSystem.Spacing.buttonPadding)
            .padding(.horizontal, DesignSystem.Spacing.buttonPadding * 1.5)
            .font(DesignSystem.Typography.system(DesignSystem.Typography.callout, weight: .medium))
            .foregroundColor(DesignSystem.Colors.primaryText)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .stroke(DesignSystem.Colors.primaryText, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                            .fill(configuration.isPressed ? DesignSystem.Colors.primaryText.opacity(0.1) : Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// 更新设置容器样式
struct SettingContainerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.cardPadding)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(DesignSystem.Colors.border.opacity(0.5), lineWidth: 1)
            )
            .shadow(
                color: DesignSystem.Shadow.card.color,
                radius: DesignSystem.Shadow.card.radius,
                x: DesignSystem.Shadow.card.x,
                y: DesignSystem.Shadow.card.y
            )
            .padding(.horizontal)
    }
}

// MARK: - View扩展
extension View {
    func modernCard() -> some View {
        self.modifier(ModernCardStyle())
    }
    
    func greetingBar() -> some View {
        self.modifier(GreetingBarStyle())
    }
    
    func watermark(_ text: String) -> some View {
        self.modifier(WatermarkStyle(text: text))
    }
    
    func settingContainer() -> some View {
        self.modifier(SettingContainerStyle())
    }
} 