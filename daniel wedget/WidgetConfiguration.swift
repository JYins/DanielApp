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
    let preferredLanguage: CoreModels.VerseLanguage
    let timePeriod: DayTimePeriod
    
    // 根据首选语言获取要显示的经文内容
    var verseText: String {
        switch preferredLanguage {
        case .chinese:
            return verse.cn
        case .english:
            return verse.en
        case .korean:
            return verse.kr
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
            preferredLanguage: .chinese,
            timePeriod: DayTimePeriod.current()
        )
    }
}

// Widget数据提供者
struct VerseTimelineProvider: TimelineProvider {
    typealias Entry = WidgetVerseEntry
    
    // 获取占位符Entry
    func placeholder(in context: Context) -> WidgetVerseEntry {
        print("📍 请求占位符 - 仅用于Widget Gallery预览")
        return WidgetVerseEntry.placeholder
    }
    
    // 获取快照 - 用于Widget Gallery和首次添加Widget时
    func getSnapshot(in context: Context, completion: @escaping (WidgetVerseEntry) -> Void) {
        print("📸 请求快照 - 首次预览")
        
        // 强制同步UserDefaults
        UserDefaults(suiteName: "group.com.daniel.DanielApp")?.synchronize()
        
        // 获取实际数据
        let dataService = VerseDataService.shared
        
        // 获取当前时间段
        let currentTimePeriod = DayTimePeriod.current()
        print("⏰ 当前时间段: \(currentTimePeriod)")
        
        // 快照永远尝试获取真实数据，无论是否预览
        if let verse = dataService.getCurrentVerseToDisplay() {
            print("✅ 快照获取实际经文: \(verse.reference)")
            completion(WidgetVerseEntry(
                date: Date(),
                verse: verse,
                preferredLanguage: VerseWidgetSettingsManager.getPreferredLanguage(),
                timePeriod: currentTimePeriod
            ))
        } else {
            print("⚠️ 快照无法获取经文，使用占位符")
            completion(WidgetVerseEntry.placeholder)
        }
    }
    
    // 获取时间线
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        print("🚀 Widget开始获取时间线...")
        print("📊 组件类型: \(context.family == .accessoryRectangular ? "锁屏矩形" : "主屏幕中号")")
        
        let now = Date()
        print("⏰ 当前时间: \(now)")
        
        // 强制同步UserDefaults，获取主App的最新数据
        let defaults = UserDefaults(suiteName: "group.com.daniel.DanielApp")
        defaults?.synchronize()
        print("📱 Widget已同步UserDefaults，获取主App最新数据")
        
        // Widget只读取数据，不写入任何状态
        let dataService = VerseDataService.shared
        
        // 获取当前时间段（用于背景样式）
        let currentTimePeriod = DayTimePeriod.current()
        print("⏰ 当前时间段: \(currentTimePeriod), 背景图片: \(currentTimePeriod.backgroundImageName)")
        
        // Widget只从主App的缓存中读取经文
        var currentVerse: MultiLanguageVerse?
        
        if let verse = dataService.getCurrentVerseToDisplay() {
            print("✅ Widget成功读取主App缓存的经文: \(verse.reference)")
            currentVerse = verse
        } else {
            print("❌ Widget无法读取经文数据，可能主App尚未缓存")
            currentVerse = MultiLanguageVerse(
                reference: "[等待数据]",
                cn: "正在从主应用获取经文数据，请稍候...",
                en: "Loading verse data from main app, please wait...",
                kr: "메인 앱에서 구절 데이터를 로드하는 중입니다. 잠시만 기다려 주세요..."
            )
        }
        
        // 创建当前Entry
        let currentEntry = WidgetVerseEntry(
            date: now, 
            verse: currentVerse!,
            preferredLanguage: VerseWidgetSettingsManager.getPreferredLanguage(),
            timePeriod: currentTimePeriod
        )
        
        // 计算下一次更新时间：需要考虑背景变化时间和午夜经文更新时间
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        // 背景变化时间点：5:00 (早晨)、10:00 (白天)、18:00 (晚上)
        var nextBackgroundChangeHour: Int?
        if hour < 5 {
            nextBackgroundChangeHour = 5  // 今天5点变为早晨
        } else if hour < 10 {
            nextBackgroundChangeHour = 10 // 今天10点变为白天
        } else if hour < 18 {
            nextBackgroundChangeHour = 18 // 今天18点变为晚上
        } else {
            nextBackgroundChangeHour = 5  // 明天5点变为早晨
        }
        
        // 计算下次背景变化时间
        var nextBackgroundChangeDate: Date?
        if let changeHour = nextBackgroundChangeHour {
            if changeHour > hour || (changeHour == 5 && hour >= 18) {
                // 今天的背景变化时间或明天5点
                let targetDay = (changeHour == 5 && hour >= 18) ? 
                    calendar.date(byAdding: .day, value: 1, to: now)! : now
                nextBackgroundChangeDate = calendar.date(bySettingHour: changeHour, minute: 0, second: 0, of: targetDay)
            }
        }
        
        // 计算明天午夜0点（经文更新时间）
        let tomorrowMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        
        // 选择最近的更新时间
        var nextUpdateDate = tomorrowMidnight
        if let backgroundChangeDate = nextBackgroundChangeDate,
           backgroundChangeDate < tomorrowMidnight {
            nextUpdateDate = backgroundChangeDate
            print("🎨 下次更新时间: \(nextUpdateDate) (背景变化)")
        } else {
            print("🕛 下次更新时间: \(nextUpdateDate) (午夜经文更新)")
        }
        
        print("⏰ 距离下次更新还有: \(String(format: "%.1f", nextUpdateDate.timeIntervalSince(now)/3600.0)) 小时")
        
        // 创建Timeline，设置在下次更新时间刷新
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdateDate))
        completion(timeline)
        
        print("✅ Widget时间线设置完成")
        print("📊 Widget当前显示: \(currentVerse?.reference ?? "无数据")")
        print("🎨 当前背景: \(currentTimePeriod.backgroundImageName)")
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