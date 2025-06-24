import WidgetKit
import SwiftUI

// 锁屏Widget
struct LockScreenVerseWidget: Widget {
    let kind: String = "LockScreenVerseWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseTimelineProvider()) { entry in
            LockScreenVerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("锁屏经文")
        .description("在锁屏上展示简短经文")
        .supportedFamilies([.accessoryRectangular])
    }
}

// 锁屏Widget视图
struct LockScreenVerseWidgetEntryView: View {
    var entry: WidgetVerseEntry
    
    var body: some View {
        // 获取简短经文（只取前部分）
        let shortVerse = shortenVerse(entry.verseText)
        
        VStack(alignment: .leading, spacing: 2) {
            Text(shortVerse)
                .font(.footnote)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .widgetAccentable()
            
            HStack {
                Spacer()
                Text(entry.verse.reference)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .widgetURL(URL(string: "danielapp://verse/\(entry.verse.reference)"))
    }
    
    // 获取简短版本的经文
    private func shortenVerse(_ verse: String) -> String {
        let words = verse.split(separator: " ")
        if words.count <= 10 {
            return verse
        }
        
        let shortened = words.prefix(8).joined(separator: " ") + "..."
        return shortened
    }
}

// 锁屏Widget预览
struct LockScreenVerseWidget_Previews: PreviewProvider {
    static var previews: some View {
        LockScreenVerseWidgetEntryView(entry: WidgetVerseEntry.placeholder)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
} 