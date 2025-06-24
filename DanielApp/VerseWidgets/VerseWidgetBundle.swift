import WidgetKit
import SwiftUI

struct VerseWidgetBundle: WidgetBundle {
    var body: some Widget {
        // 包含多个Widget
        MainVerseWidget()
        LockScreenVerseWidget()
    }
}