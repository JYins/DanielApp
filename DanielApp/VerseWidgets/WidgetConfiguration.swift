import SwiftUI
import WidgetKit

// Widget数据Entry
struct WidgetVerseEntry: TimelineEntry {
    let date: Date
    let verse: MultiLanguageVerse
    let preferredLanguage: CoreModels.VerseLanguage
    
    // 根据语言获取经文文本
    var verseText: String {
        switch preferredLanguage {
        case .chinese: return verse.cn
        case .english: return verse.en
        case .korean: return verse.kr
        }
    }
    
    // 创建占位符Entry
    static var placeholder: WidgetVerseEntry {
        WidgetVerseEntry(
            date: Date(),
            verse: MultiLanguageVerse(
                reference: "John 3:16",
                cn: "神爱世人，甚至将他的独生子赐给他们...",
                en: "For God so loved the world, that he gave his only Son...",
                kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니..."
            ),
            preferredLanguage: .chinese
        )
    }
}

// Widget数据提供者
struct VerseTimelineProvider: TimelineProvider {
    typealias Entry = WidgetVerseEntry
    
    // 占位符数据
    func placeholder(in context: Context) -> Entry {
        return WidgetVerseEntry.placeholder
    }
    
    // 快照数据（预览）
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        // 尝试获取实际数据，如果失败则使用占位符
        if let verse = VerseDataService.shared.getCurrentVerseToDisplay() {
            let language = VerseWidgetSettingsManager.getPreferredLanguage()
            let entry = WidgetVerseEntry(date: Date(), verse: verse, preferredLanguage: language)
            completion(entry)
        } else {
            completion(WidgetVerseEntry.placeholder)
        }
    }
    
    // 获取时间线
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // 从共享设置获取信息
        let language = VerseWidgetSettingsManager.getPreferredLanguage()
        let updateMode = VerseWidgetSettingsManager.getUpdateMode()
        let isFixed = VerseWidgetSettingsManager.isVerseFixed()
        
        // 获取要显示的经文
        let currentVerse = VerseDataService.shared.getCurrentVerseToDisplay() ?? MultiLanguageVerse(
            reference: "John 3:16",
            cn: "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不致灭亡，反得永生。",
            en: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
            kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라."
        )
        
        // 创建当前Entry
        let currentEntry = WidgetVerseEntry(
            date: Date(),
            verse: currentVerse,
            preferredLanguage: language
        )
        
        // 确定下一次更新时间
        let calendar = Calendar.current
        var nextUpdateDate: Date
        
        if updateMode == "automatic" && !isFixed {
            // 自动模式且未固定：每天凌晨更新
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
            nextUpdateDate = calendar.startOfDay(for: tomorrow)
            print("Widget将在明天凌晨更新: \(nextUpdateDate)")
        } else {
            // 手动模式或已固定：较长时间后更新（由应用程序触发更新）
            nextUpdateDate = calendar.date(byAdding: .day, value: 7, to: Date())!
            print("Widget将在应用程序通知时更新（最长7天后）: \(nextUpdateDate)")
        }
        
        // 创建Timeline
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdateDate))
        completion(timeline)
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

// 注释掉SceneDelegate扩展，因为在SwiftUI生命周期中我们不使用SceneDelegate
/*
extension SceneDelegate {
    func handleWidgetURL(_ url: URL) {
        guard url.isVerseDeepLink, let verseId = url.verseId else {
            return
        }
        
        // 将导航设置为显示经文详情
        // 注意：此代码仅供参考，需要根据实际应用架构调整
        NotificationCenter.default.post(
            name: Notification.Name("ShowVerseDetail"),
            object: nil,
            userInfo: ["verseId": verseId]
        )
    }
}
*/

// 使用主应用AppState类，不要在这里重复定义
// DanielAppApp.swift中已经定义了AppState类 