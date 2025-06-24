//
//  ContentView.swift
//  DanielApp
//
//  Created by 殷实 on 2025-03-29.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

// 各页面的预览
struct VerseOfTheDayView_Previews: PreviewProvider {
    static var previews: some View {
        VerseOfTheDayView()
            .environmentObject(AppState())
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppState())
    }
}

struct ConnectView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectView()
            .environmentObject(AppState())
    }
}
