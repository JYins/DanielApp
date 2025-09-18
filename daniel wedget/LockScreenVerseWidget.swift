import WidgetKit
import SwiftUI
import UIKit

// 锁屏Widget
struct LockScreenVerseWidget: Widget {
    let kind: String = "LockScreenVerseWidget"
    
    init() {
        print("🔒 LockScreenVerseWidget初始化开始")
        
        // 检查共享UserDefaults状态
        if let groupDefaults = UserDefaults(suiteName: "group.com.daniel.DanielApp") {
            print("✅ 成功获取App Group UserDefaults (锁屏)")
            
            // 强制同步获取最新数据
            groupDefaults.synchronize()
            
            // 检查关键数据
            if let cachedData = groupDefaults.data(forKey: "cachedCurrentVerse") {
                print("✅ 锁屏widget找到缓存数据: \(cachedData.count) 字节")
                
                do {
                    let verse = try JSONDecoder().decode(MultiLanguageVerse.self, from: cachedData)
                    print("✅ 锁屏widget解析成功: \(verse.reference)")
                } catch {
                    print("❌ 锁屏widget解析失败: \(error.localizedDescription)")
                }
            } else {
                print("❌ 锁屏widget未找到经文缓存数据")
            }
        }
        
        // 重新加载时间线
        WidgetCenter.shared.reloadAllTimelines()
        print("🔒 LockScreenVerseWidget初始化完成")
    }
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseTimelineProvider()) { entry in
            LockScreenVerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("锁屏经文")
        .description("在锁屏上显示精美排版的经文")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular]) // 支持两种锁屏组件
        .contentMarginsDisabled()
    }
}

// 锁屏Widget视图
struct LockScreenVerseWidgetEntryView: View {
    var entry: WidgetVerseEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    // 浅金色文本 - 主标题/引用
    var goldColor: Color {
        Color(hex: "C4A028") // 更深的金色，原来是 D4AF37
    }
    
    // 更浅的金色或米白色 - 经文内容
    var lightGoldColor: Color {
        Color(hex: "F5E8B7") // 米白色
    }
    
    var body: some View {
        if family == .accessoryCircular {
            // 圆形锁屏组件 - 只显示经文引用
            circularView
        } else {
            // 矩形锁屏组件 - 显示经文内容和引用
            rectangularView
        }
    }
    
    // 圆形锁屏组件视图
    private var circularView: some View {
        ZStack {
            // 使用经文引用的首个字母作为图标
            Text(String(entry.verse.reference.prefix(1)))
                .font(getFontForLanguage(size: 28))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .minimumScaleFactor(0.6)
        }
        .widgetURL(URL(string: "danielapp://verse/\(entry.verse.reference)"))
        .containerBackground(for: .widget) {
            // 简单深色背景
            Color.black.opacity(0.8)
        }
        .onAppear {
            print("🔄 圆形锁屏Widget显示: \(entry.verse.reference)")
            print("⏰ 当前时间段: \(entry.timePeriod)")
        }
    }
    
    // 矩形锁屏组件视图
    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 经文内容 - 精简显示
            Text(entry.verseText)
                .font(getFontForLanguage(size: getLockScreenFontSize(for: entry.preferredLanguage))) // 根据语言调整字体
                .foregroundColor(.white) // 锁屏上白色更易读
                .lineLimit(2)
                .lineSpacing(entry.preferredLanguage == "ko" ? 0.3 : 1.0) // 韩语更紧凑行距
                .minimumScaleFactor(entry.preferredLanguage == "ko" ? 0.6 : 0.7) // 韩语更强缩放
            
            // 经文引用 - 底部对齐
            Text(localizeReference(entry.verse.reference, to: entry.preferredLanguage))
                .font(getFontForLanguage(size: getLockScreenReferenceFontSize(for: entry.preferredLanguage))) // 根据语言调整引用字体
                .foregroundColor(entry.preferredLanguage == "en" ? 
                    .white.opacity(0.95) : .white) // 中文和韩文使用不透明白色
                .fontWeight(entry.preferredLanguage == "en" ? .medium : .semibold) // 减轻字重
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 4)
        .widgetURL(URL(string: "danielapp://verse/\(entry.verse.reference)"))
        .containerBackground(for: .widget) {
            // 简单深色背景
            Color.black.opacity(0.8)
        }
        .onAppear {
            print("🔒 矩形锁屏Widget视图显示")
            print("📚 锁屏经文: \(entry.verse.reference)")
            print("🌐 锁屏使用首选语言: \(entry.preferredLanguage)")
            print("⏰ 当前时间段: \(entry.timePeriod), 使用背景: \(entry.timePeriod.backgroundImageName)")
        }
    }
    
    // 本地化经文引用
    private func localizeReference(_ reference: String, to language: String) -> String {
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
    
    // 根据语言选择字体 - 简化版，字重通过fontWeight修饰符控制
    func getFontForLanguage(size: CGFloat) -> Font {
        print("🔐 锁屏Widget请求字体 - 语言: \(entry.preferredLanguage), 大小: \(size)")
        
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
    
    // 根据语言获取锁屏经文字体大小
    private func getLockScreenFontSize(for language: String) -> CGFloat {
        switch language {
        case "ko": return 15 // 韩语增大
        case "en": return 16 // 英文增大
        case "zh-CN": return 15 // 中文保持
        default: return 15
        }
    }
    
    // 根据语言获取锁屏引用字体大小
    private func getLockScreenReferenceFontSize(for language: String) -> CGFloat {
        switch language {
        case "ko": return 13 // 韩语增大
        case "en": return 14 // 英文增大
        case "zh-CN": return 13 // 中文保持
        default: return 13
        }
    }
}

// 锁屏预览
struct LockScreenVerseWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LockScreenVerseWidgetEntryView(entry: WidgetVerseEntry.placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("锁屏矩形预览")
            
            LockScreenVerseWidgetEntryView(entry: WidgetVerseEntry.placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("锁屏圆形预览")
        }
    }
} 