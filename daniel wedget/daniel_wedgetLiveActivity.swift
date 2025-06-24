//
//  daniel_wedgetLiveActivity.swift
//  daniel wedget
//
//  Created by 殷实 on 2025-03-30.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct daniel_wedgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct daniel_wedgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: daniel_wedgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension daniel_wedgetAttributes {
    fileprivate static var preview: daniel_wedgetAttributes {
        daniel_wedgetAttributes(name: "World")
    }
}

extension daniel_wedgetAttributes.ContentState {
    fileprivate static var smiley: daniel_wedgetAttributes.ContentState {
        daniel_wedgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: daniel_wedgetAttributes.ContentState {
         daniel_wedgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: daniel_wedgetAttributes.preview) {
   daniel_wedgetLiveActivity()
} contentStates: {
    daniel_wedgetAttributes.ContentState.smiley
    daniel_wedgetAttributes.ContentState.starEyes
}
