import SwiftUI

struct MainTabView: View {
    @StateObject private var tabSelection = TabSelection()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $tabSelection.selectedTab) {
            // Tab 0: Daily Verse (No change)
            VerseOfTheDayView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text(LocalizedText.Common.dailyVerse.text(for: appState.selectedLanguage))
                }
                .tag(0)
                .onChange(of: appState.selectedVerseReference) { newValue in
                    if newValue != nil {
                        // 如果从Widget点击进来，切换到第一个标签
                        tabSelection.selectedTab = 0
                    }
                }

            // Tab 1: Word Cards (Moved up, new icon)
            WordCardGalleryView()
                .tabItem {
                    Image(systemName: "quote.bubble.fill") // Changed icon
                    Text(LocalizedText.Common.wordCardsTab.text(for: appState.selectedLanguage))
                }
                .tag(1) // Changed tag

            // Tab 2: Newsletter (New tab)
            NewsletterView()
                .tabItem {
                    Image(systemName: "newspaper.fill")
                    Text(LocalizedText.Common.newsletterTab.text(for: appState.selectedLanguage))
                }
                .tag(2)

            // Tab 3: Settings (Moved down)
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text(LocalizedText.Common.settings.text(for: appState.selectedLanguage))
                }
                .tag(3) // Changed tag

            // Tab 4: Connect (Moved down)
            ConnectView()
                .tabItem {
                    Image(systemName: "link")
                    Text(LocalizedText.Common.connect.text(for: appState.selectedLanguage))
                }
                .tag(4) // Changed tag
        }
        .accentColor(StyleConstants.goldColor) // Use StyleConstants for consistency
        .onAppear {
            // 将tabSelection与appState同步
            appState.selectedTab = tabSelection.selectedTab
        }
        .onChange(of: tabSelection.selectedTab) { newValue in
            // 保持同步
            appState.selectedTab = newValue
        }
        .onChange(of: appState.selectedTab) { newValue in
            // 如果appState的selectedTab改变，更新tabSelection
            tabSelection.selectedTab = newValue
        }
    }
}

// 可观察的标签选择
class TabSelection: ObservableObject {
    @Published var selectedTab: Int = 0
}
