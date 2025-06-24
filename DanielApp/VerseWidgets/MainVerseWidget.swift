import WidgetKit
import SwiftUI

// 主桌面大尺寸Widget
struct MainVerseWidget: Widget {
    let kind: String = "MainVerseWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseTimelineProvider()) { entry in
            MainVerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("每日经文")
        .description("显示精美排版的每日经文")
        .supportedFamilies([.systemLarge])
    }
}

// 主Widget视图
struct MainVerseWidgetEntryView: View {
    var entry: WidgetVerseEntry
    @Environment(\.colorScheme) var colorScheme
    
    // 获取背景渐变色 - 深蓝色渐变
    var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "001842"),  // 深蓝色
                Color(hex: "0A2B5E")   // 稍浅的蓝色
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // 淡金色文本
    var lightGoldColor: Color {
        Color(red: 0.85, green: 0.75, blue: 0.5)
    }
    
    var body: some View {
        ZStack {
            // 背景
            backgroundGradient
            
            // 主内容 - 使用HStack布局
            HStack(spacing: 10) {
                // 左侧图片
                Image("jesus_icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .padding(.leading, 20)
                
                // 右侧经文内容
                VStack(alignment: .leading, spacing: 12) {
                    // 经文引用
                    Text(entry.verse.reference)
                        .font(.custom("Times New Roman", size: 18))
                        .fontWeight(entry.preferredLanguage == .english ? .bold : .black)
                        .foregroundColor(entry.preferredLanguage == .english ? 
                            lightGoldColor : Color(red: 0.7, green: 0.6, blue: 0.3))
                    
                    // 经文内容
                    Text(entry.verseText)
                        .font(.body)
                        .foregroundColor(lightGoldColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .widgetURL(URL(string: "danielapp://verse/\(entry.verse.reference)"))
    }
}

// 简单的预览
struct MainVerseWidget_Previews: PreviewProvider {
    static var previews: some View {
        MainVerseWidgetEntryView(entry: WidgetVerseEntry.placeholder)
            .previewContext(WidgetPreviewContext(family: .systemLarge))
    }
}