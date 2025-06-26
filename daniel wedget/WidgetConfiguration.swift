import SwiftUI
import WidgetKit

// 定义时间段枚举
enum DayTimePeriod {
    case morning    // 清晨 (5:00-10:00)
    case daytime    // 白天 (10:00-18:00)
    case nighttime  // 晚上 (18:00-5:00)
    
    // 根据当前时间返回对应的时间段
    static func current() -> DayTimePeriod {
        #if DEBUG
        // 仅在调试模式启用 - 可以强制设置当前时间段进行测试
        if let forcedPeriod = forcedTimePeriodForTesting {
            print("🧪 使用测试时间段: \(forcedPeriod)")
            return forcedPeriod
        }
        #endif
        
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<10:
            return .morning
        case 10..<18:
            return .daytime
        default:
            return .nighttime
        }
    }
    
    // 获取对应的背景图片名称
    var backgroundImageName: String {
        switch self {
        case .morning:
            return "widget_background 1"
        case .daytime:
            return "widget_background"
        case .nighttime:
            return "widget_background 2"
        }
    }
}

// 开发测试用 - 仅在DEBUG模式有效
#if DEBUG
private var forcedTimePeriodForTesting: DayTimePeriod? = nil

// 设置测试时间段函数
func setTestTimePeriod(_ period: DayTimePeriod?) {
    forcedTimePeriodForTesting = period
    print("🧪 已设置测试时间段: \(String(describing: period))")
    // 强制刷新
    WidgetCenter.shared.reloadAllTimelines()
}
#endif

// Widget数据Entry
struct WidgetVerseEntry: TimelineEntry {
    let date: Date
    let verse: MultiLanguageVerse
    let preferredLanguage: String
    let timePeriod: DayTimePeriod
    
    // 根据首选语言获取要显示的经文内容
    var verseText: String {
        switch preferredLanguage {
        case "zh-CN":
            return verse.cn
        case "en":
            return verse.en
        case "ko":
            return verse.kr
        default:
            return verse.cn
        }
    }
    
    // 占位符 - 仅用于预览Gallery 
    static var placeholder: WidgetVerseEntry {
        // 使用最明确的标记，避免被误认为是真实数据
        let placeholderVerse = MultiLanguageVerse(
            reference: "##预览## John 3:16",
            cn: "##预览## 这只是Widget预览占位符，添加Widget后将显示实际经文。",
            en: "##PREVIEW## This is just a widget preview placeholder. After adding the widget, you'll see the actual verse.",
            kr: "##미리보기## 이것은 위젯 미리보기 자리 표시자입니다. 위젯을 추가한 후 실제 구절이 표시됩니다."
        )
        
        return WidgetVerseEntry(
            date: Date(),
            verse: placeholderVerse,
            preferredLanguage: "zh-CN",
            timePeriod: DayTimePeriod.current()
        )
    }
}

// Widget独立数据提供者 - 不再依赖主App
struct VerseTimelineProvider: TimelineProvider {
    typealias Entry = WidgetVerseEntry
    
    // 获取占位符Entry
    func placeholder(in context: Context) -> WidgetVerseEntry {
        print("📍 请求占位符 - 仅用于Widget Gallery预览")
        return WidgetVerseEntry.placeholder
    }
    
    // 获取快照 - 用于Widget Gallery和首次添加Widget时
    func getSnapshot(in context: Context, completion: @escaping (WidgetVerseEntry) -> Void) {
        print("📸 Widget快照请求 - 使用独立数据管理器")
        
        // 🔄 添加生命周期检查，确保快照数据是最新的
        let lifecycleManager = WidgetLifecycleManager.shared
        lifecycleManager.checkAndUpdateIfNeeded()
        
        // 使用Widget独立数据管理器
        let dataManager = WidgetDataManager.shared
        let verse = dataManager.getTodaysVerse()
        let currentTimePeriod = DayTimePeriod.current()
        
        print("✅ Widget快照获取今日经文: \(verse.reference)")
        print("📊 数据管理器状态: \(dataManager.isDataReady() ? "已就绪" : "未就绪")")
        
        // 从主App获取语言设置
        let preferredLanguage = dataManager.getLanguageFromMainApp()
        print("🌐 Widget快照使用语言: \(preferredLanguage)")
        
        completion(WidgetVerseEntry(
            date: Date(),
            verse: verse,
            preferredLanguage: preferredLanguage,
            timePeriod: currentTimePeriod
        ))
    }
    
    // 获取时间线 - Widget独立更新
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        print("🚀 Widget独立时间线开始...")
        print("📊 组件类型: \(context.family == .accessoryRectangular ? "锁屏矩形" : "主屏幕中号")")
        
        let now = Date()
        print("⏰ 当前时间: \(now)")
        
        // 🔥 核心修复：添加Widget生命周期管理 - 执行跨天检测和自动更新逻辑
        print("🔄 执行Widget生命周期检查...")
        let lifecycleManager = WidgetLifecycleManager.shared
        lifecycleManager.checkAndUpdateIfNeeded()
        lifecycleManager.syncDataState()
        print("✅ Widget生命周期检查完成")
        
        // 使用Widget独立数据管理器
        let dataManager = WidgetDataManager.shared
        
        // 获取当前时间段（用于背景样式）
        let currentTimePeriod = DayTimePeriod.current()
        print("⏰ 当前时间段: \(currentTimePeriod), 背景图片: \(currentTimePeriod.backgroundImageName)")
        
        // Widget独立获取今日经文
        let todaysVerse = dataManager.getTodaysVerse()
        print("✅ Widget独立获取今日经文: \(todaysVerse.reference)")
        print("📊 数据状态: \(dataManager.getDebugInfo())")
        
        // 从主App获取语言设置
        let preferredLanguage = dataManager.getLanguageFromMainApp()
        print("🌐 Widget时间线使用语言: \(preferredLanguage)")
        
        // 创建当前Entry
        let currentEntry = WidgetVerseEntry(
            date: now, 
            verse: todaysVerse,
            preferredLanguage: preferredLanguage,
            timePeriod: currentTimePeriod
        )
        
        // 计算下一次更新时间 - 使用WidgetLifecycleManager的智能计算
        let nextUpdateDate = lifecycleManager.calculateNextUpdateTime()
        print("⏰ 下次智能更新时间: \(nextUpdateDate)")
        print("⏰ 距离下次更新还有: \(String(format: "%.1f", nextUpdateDate.timeIntervalSince(now)/3600.0)) 小时")
        
        // 创建Timeline，设置在下次更新时间刷新
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdateDate))
        completion(timeline)
        
        print("✅ Widget独立时间线设置完成")
        print("📊 Widget当前显示: \(todaysVerse.reference)")
        print("🎨 当前背景: \(currentTimePeriod.backgroundImageName)")
        print("🔄 生命周期状态: \(lifecycleManager.getWidgetStatus())")
        print("─────────────────────────────────────")
    }
}

// Widget URL处理
extension URL {
    static let widgetDeepLink = URL(string: "danielapp://widget/")!
}

extension View {
    func widgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            return background(backgroundView)
        }
    }
} 