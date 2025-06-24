import SwiftUI

struct StyleConstants {
    // 颜色
    static let backgroundColor = Color(hex: "002366") // 深蓝色背景
    static let goldColor = Color(hex: "D4AF37") // 金色
    static let lightGoldColor = Color(hex: "F5E8B7") // 浅金色
    
    // 新增：统一间距系统
    static let compactSpacing: CGFloat = 8
    static let standardSpacing: CGFloat = 15
    static let mediumSpacing: CGFloat = 20
    static let largeSpacing: CGFloat = 25
    static let extraLargeSpacing: CGFloat = 30
    
    // 新增：内边距系统
    static let containerPadding: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let buttonPadding: CGFloat = 12
    
    // 字体 - 根据不同语言使用不同字体
    static func serifTitle(_ size: CGFloat, language: CoreModels.VerseLanguage = .chinese) -> Font {
        switch language {
        case .chinese:
            return Font.custom("SimSun", size: size).weight(.bold) // 使用实际的宋体字体名
        case .english:
            return Font.custom("TimesNewRomanPSMT", size: size).weight(.bold) // 正确的iOS系统字体名
        case .korean:
            return Font.custom("NanumMyeongjo", size: size).weight(.bold) // 使用实际的韩文字体名
        }
    }
    
    static func serifBody(_ size: CGFloat, language: CoreModels.VerseLanguage = .chinese) -> Font {
        switch language {
        case .chinese:
            return Font.custom("SimSun", size: size) // 使用实际的宋体字体名
        case .english:
            return Font.custom("TimesNewRomanPSMT", size: size) // 正确的iOS系统字体名
        case .korean:
            return Font.custom("NanumMyeongjo", size: size) // 使用实际的韩文字体名
        }
    }
    
    static func sansFontBody(_ size: CGFloat) -> Font {
        Font.system(size: size)
    }
    
    // 按钮样式
    static let buttonCornerRadius: CGFloat = 10
    static let buttonBorderWidth: CGFloat = 1.5
}

// 优化的按钮样式
struct GoldBorderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, StyleConstants.buttonPadding)
            .padding(.horizontal, StyleConstants.buttonPadding * 2)
            .foregroundColor(StyleConstants.goldColor)
            .background(
                RoundedRectangle(cornerRadius: StyleConstants.buttonCornerRadius)
                    .stroke(StyleConstants.goldColor, lineWidth: StyleConstants.buttonBorderWidth)
                    .background(
                        RoundedRectangle(cornerRadius: StyleConstants.buttonCornerRadius)
                            .fill(configuration.isPressed ? StyleConstants.goldColor.opacity(0.1) : Color.clear)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// 优化的设置容器样式
struct SettingContainerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(StyleConstants.containerPadding)
            .background(
                RoundedRectangle(cornerRadius: StyleConstants.buttonCornerRadius)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                StyleConstants.lightGoldColor.opacity(0.6),
                                StyleConstants.lightGoldColor.opacity(0.3)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal)
    }
}

extension View {
    func settingContainer() -> some View {
        self.modifier(SettingContainerStyle())
    }
} 