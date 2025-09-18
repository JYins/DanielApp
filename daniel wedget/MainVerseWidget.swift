import WidgetKit
import SwiftUI
import UIKit

// 主桌面Widget
struct MainVerseWidget: Widget {
    let kind: String = "MainVerseWidget"
    
    init() {
        print("🔎🔎🔎 MainVerseWidget初始化开始")
        
        // 检查共享UserDefaults状态
        if let groupDefaults = UserDefaults(suiteName: "group.com.daniel.DanielApp") {
            print("✅ 成功获取App Group UserDefaults")
            
            // 强制同步获取最新数据
            groupDefaults.synchronize()
            
            // 输出所有键
            print("📋 UserDefaults中的所有键:")
            let allKeys = groupDefaults.dictionaryRepresentation().keys.sorted()
            for key in allKeys {
                print(" - \(key)")
            }
            
            // 检查关键数据
            if let cachedData = groupDefaults.data(forKey: "cachedCurrentVerse") {
                print("✅ 找到缓存数据: \(cachedData.count) 字节")
                
                do {
                    let verse = try JSONDecoder().decode(MultiLanguageVerse.self, from: cachedData)
                    print("✅ 解析成功: \(verse.reference)")
                    print("📝 内容: \(verse.cn.prefix(30))...")
                } catch {
                    print("❌ 解析失败: \(error.localizedDescription)")
                }
            } else {
                print("❌ 未找到经文缓存数据")
            }
            
            if let ref = groupDefaults.string(forKey: "currentVerseReference") {
                print("✅ 当前经文引用: \(ref)")
            } else {
                print("❌ 未找到经文引用")
            }
        }
        
        // 重新加载时间线
        WidgetCenter.shared.reloadAllTimelines()
        print("🔎🔎🔎 MainVerseWidget初始化完成")
    }
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseTimelineProvider()) { entry in
            MainVerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("每日经文")
        .description("显示精美排版的每日经文")
        .supportedFamilies([.systemMedium]) // 只保留中号
        .contentMarginsDisabled()
    }
}

// 主Widget视图
struct MainVerseWidgetEntryView: View {
    var entry: WidgetVerseEntry
    @Environment(\.colorScheme) var colorScheme
    
    // 浅金色文本 - 主标题/引用
    var goldColor: Color {
        Color(hex: "B39018") // 更深的金色
    }
    
    // 更浅的金色或米白色 - 经文内容
    var lightGoldColor: Color {
        Color(hex: "F5E8B7") // README中指定的米白色
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 文字层
                VStack(alignment: .leading, spacing: 0) { // 进一步减少整体间距
                    // 经文内容 - 左对齐
                    Text(entry.verseText)
                        .font(getFontForLanguage(size: entry.preferredLanguage == "ko" ? 14 : 16)) // 韩语使用更小字体
                        .foregroundColor(lightGoldColor)
                        .lineLimit(entry.preferredLanguage == "ko" ? 6 : 7) // 韩语限制6行，其他7行
                        .lineSpacing(entry.preferredLanguage == "ko" ? 0.2 : 1.6) // 韩语使用极小行距
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black.opacity(0.85), radius: 2.5, x: 1.2, y: 1.2) // 增强阴影效果
                        .fixedSize(horizontal: false, vertical: true) // 确保显示完整的内容
                        .minimumScaleFactor(entry.preferredLanguage == "ko" ? 0.7 : 0.8) // 韩语更强的自动缩放
                        .layoutPriority(1) // 给予文本更高的布局优先级
                    
                    Spacer(minLength: 0) // 进一步减少空间
                    
                    // 经文引用 - 右下角但更上移
                    Text(localizeReference(entry.verse.reference, to: entry.preferredLanguage))
                        .font(getFontForLanguage(size: entry.preferredLanguage == "ko" ? 14 : 16)) // 韩语使用更小字体
                        .foregroundColor(Color(hex: "F0C030")) // 统一使用相同的亮金色
                        .fontWeight(entry.preferredLanguage == "en" ? .medium : .semibold) // 减轻字重避免过粗
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 1, y: 1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 4) // 减少右侧内边距，使reference更靠右
                        .padding(.top, 5)
                }
                .padding(.horizontal, 16)
                .padding(.trailing, 6) // 减少整体右侧内边距，使reference更靠右
                .padding(.vertical, 8)
                .frame(width: geometry.size.width * 0.75, height: geometry.size.height * 0.85, alignment: .leading)
                .position(x: geometry.size.width * 0.62, y: geometry.size.height * 0.50) // 向下移动到中心位置
            }
        }
        .containerBackground(for: .widget) {
            // 背景图片 - 根据时间段选择不同的背景
            GeometryReader { geo in
                Image(entry.timePeriod.backgroundImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .widgetURL(URL(string: "danielapp://verse/\(entry.verse.reference)"))
        .onAppear {
            print("🖼️ Widget视图开始显示")
            print("📚 经文: \(entry.verse.reference)")
            print("📝 内容: \(entry.verseText.prefix(30))...")
            print("⏰ 当前时间段: \(entry.timePeriod), 使用背景: \(entry.timePeriod.backgroundImageName)")
            
            // 显示首选语言
            print("🌐 使用首选语言: \(entry.preferredLanguage)")
            
            // 当前缓存状态
            if let groupDefaults = UserDefaults(suiteName: "group.com.daniel.DanielApp") {
                if let ref = groupDefaults.string(forKey: "currentVerseReference") {
                    print("📌 UserDefaults中的引用: \(ref)")
                    print("引用匹配度: \(ref == entry.verse.reference ? "✅ 匹配" : "❌ 不匹配")")
                } else {
                    print("⚠️ UserDefaults中未找到引用")
                }
            } else {
                print("❌ 无法获取共享UserDefaults")
            }
        }
    }
    
    // 根据语言选择字体 - 简化版，字重通过fontWeight修饰符控制
    func getFontForLanguage(size: CGFloat) -> Font {
        print("🎨 Widget请求字体 - 语言: \(entry.preferredLanguage), 大小: \(size)")
        
        switch entry.preferredLanguage {
        case "zh-CN":
            // 测试中文字体是否可用
            if UIFont(name: "AidianFengYaHeiChangTi", size: size) != nil {
                print("✅ 中文字体可用，使用自定义字体")
                return .custom("AidianFengYaHeiChangTi", size: size)
            } else {
                print("❌ 中文字体不可用，使用系统字体")
                return .system(size: size, weight: .regular, design: .serif)
            }
        case "en":
            print("🔤 使用英文系统字体")
            return .system(size: size, weight: .regular, design: .rounded)
        case "ko":
            // 测试韩文字体是否可用
            if UIFont(name: "GowunDodum-Regular", size: size) != nil {
                print("✅ 韩文字体可用，使用自定义字体")
                return .custom("GowunDodum-Regular", size: size)
            } else {
                print("❌ 韩文字体不可用，使用系统字体")
                return .system(size: size, weight: .regular, design: .serif)
            }
        default:
            print("🔧 使用默认字体")
            // 默认尝试中文字体，如果不可用则使用系统字体
            if UIFont(name: "AidianFengYaHeiChangTi", size: size) != nil {
                print("✅ 默认中文字体可用")
                return .custom("AidianFengYaHeiChangTi", size: size)
            } else {
                print("❌ 默认使用系统字体")
                return .system(size: size, weight: .regular, design: .serif)
            }
        }
    }
    
    // 本地化经文引用
    func localizeReference(_ reference: String, to language: String) -> String {
        // 将字符串语言代码转换为VerseLanguage枚举
        let verseLanguage: CoreModels.VerseLanguage
        switch language {
        case "zh-CN":
            verseLanguage = .chinese
        case "en":
            verseLanguage = .english
        case "ko":
            verseLanguage = .korean
        default:
            verseLanguage = .chinese
        }
        
        // 使用CoreModels中的本地化方法
        return CoreModels.VerseLanguage.localizeReference(reference, to: verseLanguage)
    }
}

// 简单的预览
struct MainVerseWidget_Previews: PreviewProvider {
    static var previews: some View {
        // 只使用占位符预览
        MainVerseWidgetEntryView(entry: WidgetVerseEntry.placeholder)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("经文Widget预览")
    }
}
