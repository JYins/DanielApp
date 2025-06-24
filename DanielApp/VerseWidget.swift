import SwiftUI
import WidgetKit
import Foundation
// 使用共享模型
import Foundation

// 直接使用模型定义，而不是导入

// 将通用功能移动到Helper命名空间
enum VerseWidgetUserHelper {
    // 从JSON加载经文数据的工具函数
    static func loadVersesFromJson() -> [MultiLanguageVerse]? {
        guard let url = Bundle.main.url(forResource: "verses_merged", withExtension: "json") else {
            print("无法找到verses_merged.json文件")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let verses = try JSONDecoder().decode([MultiLanguageVerse].self, from: data)
            return verses
        } catch {
            print("解析JSON失败: \(error)")
            return nil
        }
    }
    
    // 从JSON加载经文索引列表
    static func loadVerseIndexList() -> [String]? {
        guard let url = Bundle.main.url(forResource: "verses_index", withExtension: "json") else {
            print("无法找到verses_index.json文件")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let indices = try JSONDecoder().decode([String].self, from: data)
            return indices
        } catch {
            print("解析JSON失败: \(error)")
            return nil
        }
    }
    
    // 根据日期选择经文
    static func selectVerseForDate(from verses: [MultiLanguageVerse], date: Date) -> MultiLanguageVerse? {
        guard !verses.isEmpty else {
            return nil
        }
        
        // 先尝试从索引列表获取
        if let indices = loadVerseIndexList(), !indices.isEmpty {
            let calendar = Calendar.current
            let day = calendar.component(.day, from: date)
            let indexForToday = day % indices.count
            let referenceForToday = indices[indexForToday]
            
            // 查找对应的经文
            if let verse = verses.first(where: { $0.reference == referenceForToday }) {
                return verse
            }
        }
        
        // 如果索引列表不可用或找不到对应经文，直接从所有经文中选择
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let seed = day + month
        
        let index = seed % verses.count
        return verses[index]
    }
}

// 使用共享模型中的VerseEntry

// 使用共享模型中的Color扩展和StyleConstants

struct VerseWidgetEntryView: View {
    var entry: WidgetVerseEntry
    let widgetFamily: WidgetFamily
    
    // 获取当前语言的经文内容
    var verseText: String {
        switch entry.preferredLanguage {
        case .chinese:
            return entry.verse.cn
        case .english:
            return entry.verse.en
        case .korean:
            return entry.verse.kr
        }
    }
    
    var body: some View {
        ZStack {
            // 背景色渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(hex: "002366"),
                    Color(hex: "001947")
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
            
            HStack(spacing: 0) {
                // 卡通耶稣形象
                Image("jesus_cartoon") // 需要在Assets中添加图片
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: widgetFamily == .systemSmall ? 40 : 70)
                    .padding(.leading, widgetFamily == .systemSmall ? 8 : 16)
                
                // 经文内容
                VStack(alignment: .leading, spacing: 4) {
                    // 经文内容
                    Text(verseText)
                        .font(widgetFamily == .systemSmall ? 
                              .custom("Georgia", size: 12) : 
                              .custom("Georgia", size: 14))
                        .foregroundColor(StyleConstants.lightGoldColor)
                        .lineLimit(widgetFamily == .systemSmall ? 2 : 3)
                        .padding(.top, widgetFamily == .systemSmall ? 8 : 12)
                    
                    Spacer()
                    
                    // 引用
                    Text(entry.verse.reference)
                        .font(widgetFamily == .systemSmall ? 
                              .custom("Georgia", size: 10) : 
                              .custom("Georgia", size: 12))
                        .foregroundColor(StyleConstants.goldColor)
                        .padding(.bottom, widgetFamily == .systemSmall ? 8 : 12)
                }
                .padding(.horizontal, 10)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .widgetURL(URL(string: "danielapp://verse/\(entry.verse.reference)"))
        }
    }
}

struct VerseWidgetProvider: TimelineProvider {
    typealias Entry = WidgetVerseEntry
    
    func placeholder(in context: Context) -> WidgetVerseEntry {
        return WidgetVerseEntry.placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (WidgetVerseEntry) -> Void) {
        // 在真实环境中应该从数据源获取当前经文
        completion(WidgetVerseEntry.placeholder)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetVerseEntry>) -> Void) {
        // 创建时间线，真实环境中应该从数据源获取经文并设置更新时间
        let entry = WidgetVerseEntry.placeholder
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SmallVerseWidget: Widget {
    let kind = "SmallVerseWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseWidgetProvider()) { entry in
            VerseWidgetEntryView(entry: entry, widgetFamily: .systemSmall)
        }
        .configurationDisplayName("每日经文")
        .description("显示今日经文")
        .supportedFamilies([.systemSmall])
    }
}

struct MediumVerseWidget: Widget {
    let kind = "MediumVerseWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseWidgetProvider()) { entry in
            VerseWidgetEntryView(entry: entry, widgetFamily: .systemMedium)
        }
        .configurationDisplayName("每日经文")
        .description("显示今日经文，更大的尺寸")
        .supportedFamilies([.systemMedium])
    }
}

// Widget Bundle 例子 - 在真实环境下应放在Widget扩展中
struct DanielWidgets: WidgetBundle {
    var body: some Widget {
        SmallVerseWidget()
        MediumVerseWidget()
    }
}