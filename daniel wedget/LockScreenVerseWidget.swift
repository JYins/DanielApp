import WidgetKit
import SwiftUI

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
                .font(getFontForLanguage(size: 30, isBold: true))
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
                .font(getFontForLanguage(size: 13))
                .foregroundColor(.white) // 锁屏上白色更易读
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            
            // 经文引用 - 底部对齐
            Text(localizeReference(entry.verse.reference, to: entry.preferredLanguage))
                .font(getFontForLanguage(size: 11, isBold: true))
                .foregroundColor(entry.preferredLanguage == "en" ? 
                    .white.opacity(0.95) : .white) // 中文和韩文使用不透明白色
                .fontWeight(entry.preferredLanguage == "en" ? .medium : .bold) // 中文和韩文使用粗体
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
        switch language {
        case "zh-CN":
            return reference // 中文引用保持原样
        case "en":
            return reference // 英文引用保持原样
        case "ko":
            return reference // 韩文引用保持原样
        default:
            return reference
        }
    }
    
    // 根据语言选择字体
    func getFontForLanguage(size: CGFloat, isBold: Bool = false) -> Font {
        switch entry.preferredLanguage {
        case "zh-CN":
            return isBold ? 
                .custom("SimSun", size: size).weight(.bold) : 
                .custom("SimSun", size: size)
        case "en":
            return isBold ? 
                .custom("TimesNewRomanPSMT", size: size).weight(.bold) : 
                .custom("TimesNewRomanPSMT", size: size)
        case "ko":
            return isBold ? 
                .custom("NanumMyeongjo", size: size).weight(.bold) : 
                .custom("NanumMyeongjo", size: size)
        default:
            return isBold ? 
                .custom("TimesNewRomanPSMT", size: size).weight(.bold) : 
                .custom("TimesNewRomanPSMT", size: size)
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