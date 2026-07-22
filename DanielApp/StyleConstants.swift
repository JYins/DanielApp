import SwiftUI

// MARK: - 全新的设计系统
struct DesignSystem {
    
    // MARK: - 颜色系统
    struct Colors {
        // Figma v2 base: warm devotional accents, with a calm dark appearance.
        static let background = Color(light: "#ffffff", dark: "#11100f")
        
        // 卡片和内容区域
        static let cardBackground = Color(light: "#fffbeb", dark: "#2a2119")
        static let cardBackgroundSolid = Color(light: "#fffbeb", dark: "#2a2119")
        static let surface = Color(light: "#ffffff", dark: "#1a1715")
        
        // 文字颜色 - 深灰色系
        static let primaryText = Color(light: "#101828", dark: "#fff7ed")
        static let secondaryText = Color(light: "#1e2939", dark: "#e7d8c9")
        static let mutedText = Color(light: "#6a7282", dark: "#b9a99a")
        
        // 强调色 - 橙色
        static let accent = Color(hex: "#ff8d28")
        static let accentDark = Color(light: "#c76e00", dark: "#ffb05c")
        static let accentLight = Color(hex: "#ff8d28").opacity(0.7)
        
        // 水印色 - 淡金色
        static let watermark = Color(light: "#c76e00", dark: "#ffb05c").opacity(0.2)
        
        // 边框和分隔线
        static let border = Color(light: "#ebe6e7", dark: "#3b332d")
        static let divider = Color(light: "#ebe6e7", dark: "#3b332d")
        
        // 问候区域背景
        static let greetingBackground = Color(light: "#ffffff", dark: "#1a1715").opacity(0.8)
        
        // 按钮颜色
        static let buttonBorder = Color(light: "#6a7282", dark: "#b9a99a")
        static let buttonBackground = Color.clear
        static let buttonBackgroundPressed = Color(light: "#4a4a4a", dark: "#ffffff").opacity(0.1)
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
        static let large: CGFloat = 18
        static let extraLarge: CGFloat = 24
        static let card: CGFloat = 24
        static let button: CGFloat = 8
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
        static let card = (color: Color(light: "#000000", dark: "#000000").opacity(0.18), radius: CGFloat(10), x: CGFloat(0), y: CGFloat(4))
        static let elevated = (color: Color(light: "#000000", dark: "#000000").opacity(0.24), radius: CGFloat(15), x: CGFloat(0), y: CGFloat(10))
        static let soft = (color: Color(light: "#000000", dark: "#000000").opacity(0.10), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(1))
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
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
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
    var variant: AppButtonVariant = .primary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .font(DesignSystem.Typography.smart(DesignSystem.Typography.body, weight: .medium, language: language))
            .foregroundColor(variant.foreground)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .stroke(variant.border, lineWidth: variant.borderWidth)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                            .fill(configuration.isPressed ? variant.pressedBackground : variant.background)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

enum AppButtonVariant {
    case primary
    case outline
    
    var foreground: Color {
        switch self {
        case .primary: return .white
        case .outline: return DesignSystem.Colors.secondaryText
        }
    }
    
    var background: Color {
        switch self {
        case .primary: return DesignSystem.Colors.accent
        case .outline: return .clear
        }
    }
    
    var pressedBackground: Color {
        switch self {
        case .primary: return DesignSystem.Colors.accentDark
        case .outline: return DesignSystem.Colors.cardBackground
        }
    }
    
    var border: Color {
        switch self {
        case .primary: return DesignSystem.Colors.accent
        case .outline: return DesignSystem.Colors.buttonBorder
        }
    }
    
    var borderWidth: CGFloat {
        switch self {
        case .primary: return 0
        case .outline: return 1
        }
    }
}

struct GreetingBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.surface)
    }
}

struct WatermarkStyle: ViewModifier {
    let text: String
    
    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
            
            Text(text)
                .font(DesignSystem.Typography.body(DesignSystem.Typography.footnote, language: .chinese)) // 水印始终使用中文字体
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

extension Color {
    init(light: String, dark: String) {
        self = Color(UIColor { traitCollection in
            UIColor(hexString: traitCollection.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let red: UInt64
        let green: UInt64
        let blue: UInt64
        switch hex.count {
        case 6:
            red = (int >> 16) & 0xFF
            green = (int >> 8) & 0xFF
            blue = int & 0xFF
        default:
            red = 255
            green = 255
            blue = 255
        }
        
        self.init(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: 1
        )
    }
}
