import SwiftUI
import WidgetKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    // 状态变量
    @State private var updateMode: String = "automatic"
    @State private var selectedLanguage: CoreModels.VerseLanguage = .chinese
    @State private var manualVerseReference: String = ""
    
    // 为手动选择经文准备的数据结构
    @State private var selectedBook = ""
    @State private var selectedChapter = 1
    @State private var selectedVerse = 1
    @State private var availableBooks: [String] = []
    @State private var availableChapters: [Int] = []
    @State private var availableVerses: [Int] = []
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // 问候语区域 - 使用动态语言
                    HeaderSection(language: selectedLanguage)
                    
                    // Widget设置卡片
                    VStack(spacing: 36) {
                        // 更新模式设置
                        VStack(alignment: .leading, spacing: 24) {
                            Text(LocalizedText.Settings.updateMode.text(for: selectedLanguage))
                                .font(DesignSystem.Typography.system(DesignSystem.Typography.headline, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            
                            VStack(spacing: 16) {
                                // 自动更新按钮
                                Button(action: {
                                    updateMode = "automatic"
                                    VerseDataService.shared.setUpdateMode("automatic")
                                    WidgetCenter.shared.reloadAllTimelines()
                                }) {
                                    HStack(spacing: 24) {
                                        Image(systemName: updateMode == "automatic" ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 26))
                                            .foregroundColor(updateMode == "automatic" ? DesignSystem.Colors.accent : DesignSystem.Colors.mutedText)
                                        
                                        Text(LocalizedText.Settings.autoUpdate.text(for: selectedLanguage))
                                            .font(DesignSystem.Typography.smart(DesignSystem.Typography.body, weight: .medium, language: selectedLanguage))
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                        
                                        Spacer(minLength: 28)
                                    }
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 22)
                                            .fill(updateMode == "automatic" ? DesignSystem.Colors.cardBackground : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 22)
                                                    .stroke(DesignSystem.Colors.divider.opacity(0.8), lineWidth: 1.5)
                                            )
                                    )
                                }
                                
                                // 手动更新按钮
                                Button(action: {
                                    updateMode = "manual"
                                    VerseDataService.shared.setUpdateMode("manual")
                                    WidgetCenter.shared.reloadAllTimelines()
                                }) {
                                    HStack(spacing: 24) {
                                        Image(systemName: updateMode == "manual" ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 26))
                                            .foregroundColor(updateMode == "manual" ? DesignSystem.Colors.accent : DesignSystem.Colors.mutedText)
                                        
                                        Text(LocalizedText.Settings.manualUpdate.text(for: selectedLanguage))
                                            .font(DesignSystem.Typography.smart(DesignSystem.Typography.body, weight: .medium, language: selectedLanguage))
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                        
                                        Spacer(minLength: 28)
                                    }
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 22)
                                    .background(
                                        RoundedRectangle(cornerRadius: 22)
                                            .fill(updateMode == "manual" ? DesignSystem.Colors.cardBackground : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 22)
                                                    .stroke(DesignSystem.Colors.divider.opacity(0.8), lineWidth: 1.5)
                                            )
                                    )
                                }
                            }
                            
                            // 手动模式下显示经文选择器
                            if updateMode == "manual" {
                                VStack(spacing: 20) {
                                    Rectangle()
                                        .fill(DesignSystem.Colors.divider)
                                        .frame(height: 1)
                                        .padding(.horizontal, 10)
                                    
                                    Text(LocalizedText.Settings.selectVerse.text(for: selectedLanguage))
                                        .font(DesignSystem.Typography.smart(DesignSystem.Typography.callout, weight: .semibold, language: selectedLanguage))
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    // 书卷选择
                                    Picker(LocalizedText.Settings.bookPlaceholder.text(for: selectedLanguage), selection: $selectedBook) {
                                        ForEach(availableBooks, id: \.self) { book in
                                            Text(getLocalizedBookName(book, language: selectedLanguage)).tag(book)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .onChange(of: selectedBook) { newBook in
                                        updateChaptersForBook(newBook)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(DesignSystem.Colors.cardBackground.opacity(0.6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(DesignSystem.Colors.divider, lineWidth: 1)
                                            )
                                    )
                                    
                                    HStack(spacing: 12) {
                                        // 章选择
                                        Picker(LocalizedText.Settings.chapterPlaceholder.text(for: selectedLanguage), selection: $selectedChapter) {
                                            ForEach(availableChapters, id: \.self) { chapter in
                                                Text("\(chapter)").tag(chapter)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .onChange(of: selectedChapter) { newChapter in
                                            updateVersesForChapter(newChapter)
                                        }
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(DesignSystem.Colors.cardBackground.opacity(0.6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(DesignSystem.Colors.divider, lineWidth: 1)
                                                )
                                        )
                                        
                                        Text(":")
                                            .font(DesignSystem.Typography.system(DesignSystem.Typography.title3, weight: .semibold))
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                            .padding(.horizontal, 4)
                                        
                                        // 节选择
                                        Picker(LocalizedText.Settings.versePlaceholder.text(for: selectedLanguage), selection: $selectedVerse) {
                                            ForEach(availableVerses, id: \.self) { verse in
                                                Text("\(verse)").tag(verse)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .onChange(of: selectedVerse) { newVerse in
                                            if !selectedBook.isEmpty {
                                                manualVerseReference = "\(selectedBook) \(selectedChapter):\(selectedVerse)"
                                            }
                                        }
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(DesignSystem.Colors.cardBackground.opacity(0.6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(DesignSystem.Colors.divider, lineWidth: 1)
                                                )
                                        )
                                    }
                                    
                                    // 经文引用输入框
                                    TextField(LocalizedText.Settings.versePlaceholder.text(for: selectedLanguage), text: $manualVerseReference)
                                        .padding(16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(DesignSystem.Colors.cardBackground.opacity(0.6))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(DesignSystem.Colors.accent.opacity(0.4), lineWidth: 1)
                                                )
                                        )
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                        .font(DesignSystem.Typography.smart(DesignSystem.Typography.body, language: selectedLanguage))
                                    
                                    // 保存选择的经文
                                    Button(LocalizedText.Settings.setVerse.text(for: selectedLanguage)) {
                                        setManualVerse()
                                    }
                                    .buttonStyle(ModernButtonStyle(language: selectedLanguage))
                                    .padding(.top, 8)
                                }
                            }
                        }
                        
                        Rectangle()
                            .fill(DesignSystem.Colors.divider)
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                        
                        // 语言设置
                        VStack(alignment: .leading, spacing: 24) {
                            Text(LocalizedText.Settings.displayLanguage.text(for: selectedLanguage))
                                .font(DesignSystem.Typography.system(DesignSystem.Typography.headline, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            
                            VStack(spacing: 16) {
                                LanguageButton(
                                    title: "中文 (Chinese)",
                                    language: .chinese,
                                    selectedLanguage: selectedLanguage
                                ) {
                                    selectLanguage(.chinese)
                                }
                                
                                LanguageButton(
                                    title: "한국어 (Korean)",
                                    language: .korean,
                                    selectedLanguage: selectedLanguage
                                ) {
                                    selectLanguage(.korean)
                                }
                                
                                LanguageButton(
                                    title: "English",
                                    language: .english,
                                    selectedLanguage: selectedLanguage
                                ) {
                                    selectLanguage(.english)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 28)
                    .modernCard()
                    .padding(.horizontal, 24)
                    
                    // 版本信息卡片
                    VStack(spacing: 24) {
                        Text(LocalizedText.Common.versionInfo.text(for: selectedLanguage))
                            .font(DesignSystem.Typography.system(DesignSystem.Typography.headline, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        VStack(spacing: 14) {
                            Text(LocalizedText.Common.bibleVersionInfo.text(for: selectedLanguage))
                                .font(DesignSystem.Typography.smart(DesignSystem.Typography.callout, language: selectedLanguage))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                            
                            Text("App Version 1.0")
                                .font(DesignSystem.Typography.smart(DesignSystem.Typography.footnote, language: selectedLanguage))
                                .foregroundColor(DesignSystem.Colors.mutedText)
                        }
                    }
                    .padding(.vertical, 32)
                    .padding(.horizontal, 28)
                    .modernCard()
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 30)
                }
            }
        }
        .watermark("@但以理和他的朋友们")
        .onAppear {
            initializeSettings()
        }
    }
    
    // MARK: - 私有方法
    
    private func initializeSettings() {
        selectedLanguage = appState.selectedLanguage
        updateMode = VerseDataService.shared.getUpdateMode()
        
        // 初始化手动模式数据
        availableBooks = loadBibleBooks()
        if let ref = VerseDataService.shared.getCurrentVerseReference() {
            manualVerseReference = ref
            if let parsedRef = parseReference(ref) {
                selectedBook = parsedRef.book
                selectedChapter = parsedRef.chapter
                selectedVerse = parsedRef.verse
                updateChaptersForBook(parsedRef.book)
                updateVersesForChapter(parsedRef.chapter)
            }
        }
    }
    
    private func selectLanguage(_ language: CoreModels.VerseLanguage) {
        selectedLanguage = language
        VerseDataService.shared.setSelectedLanguage(language)
        appState.selectedLanguage = language
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func setManualVerse() {
        var reference: String
        
        if !manualVerseReference.isEmpty {
            reference = manualVerseReference
            if selectedLanguage != .english {
                let standardizedRef = CoreModels.VerseLanguage.standardizeReference(reference, from: selectedLanguage)
                if standardizedRef != reference {
                    reference = standardizedRef
                }
            }
        } else if !selectedBook.isEmpty {
            reference = "\(selectedBook) \(selectedChapter):\(selectedVerse)"
        } else {
            return
        }
        
        if let verse = VerseDataService.shared.findVerse(byReference: reference) {
            VerseDataService.shared.setCurrentVerseReference(reference)
            VerseDataService.shared.setVerseFixed(true)
            appState.selectedVerseReference = reference
            
            let verseText = selectedLanguage == .chinese ? verse.cn : 
                           (selectedLanguage == .english ? verse.en : verse.kr)
            print("已设置经文: \(reference) - \(verseText.prefix(20))...")
            
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            print("未找到经文: \(reference)")
        }
    }
    
    private func loadBibleBooks() -> [String] {
        return ["Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
                "Joshua", "Judges", "Ruth", "I Samuel", "II Samuel",
                "I Kings", "II Kings", "I Chronicles", "II Chronicles",
                "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
                "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
                "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
                "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk", "Zephaniah",
                "Haggai", "Zechariah", "Malachi", "Matthew", "Mark", "Luke",
                "John", "Acts", "Romans", "I Corinthians", "II Corinthians",
                "Galatians", "Ephesians", "Philippians", "Colossians",
                "I Thessalonians", "II Thessalonians", "I Timothy", "II Timothy",
                "Titus", "Philemon", "Hebrews", "James", "I Peter", "II Peter",
                "I John", "II John", "III John", "Jude", "Revelation"]
    }
    
    private func updateChaptersForBook(_ book: String) {
        var maxChapter = 28
        
        switch book {
        case "Genesis": maxChapter = 50
        case "Exodus": maxChapter = 40
        case "Psalms": maxChapter = 150
        case "Matthew": maxChapter = 28
        case "Mark": maxChapter = 16
        case "Luke": maxChapter = 24
        case "John": maxChapter = 21
        default: maxChapter = 28
        }
        
        availableChapters = Array(1...maxChapter)
        selectedChapter = 1
        updateVersesForChapter(1)
    }
    
    private func updateVersesForChapter(_ chapter: Int) {
        var maxVerse = 30
        
        if selectedBook == "Psalms" && chapter == 119 {
            maxVerse = 176
        } else {
            maxVerse = 40
        }
        
        availableVerses = Array(1...maxVerse)
        selectedVerse = 1
        
        if !selectedBook.isEmpty {
            manualVerseReference = "\(selectedBook) \(selectedChapter):\(selectedVerse)"
        }
    }
    
    private func parseReference(_ reference: String) -> (book: String, chapter: Int, verse: Int)? {
        let pattern = "([\\w\\s]+)\\s+(\\d+):(\\d+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        if let regex = regex,
           let match = regex.firstMatch(in: reference, options: [], range: NSRange(location: 0, length: reference.count)) {
            let nsString = reference as NSString
            
            let bookRange = match.range(at: 1)
            let chapterRange = match.range(at: 2)
            let verseRange = match.range(at: 3)
            
            let book = nsString.substring(with: bookRange).trimmingCharacters(in: .whitespaces)
            let chapter = Int(nsString.substring(with: chapterRange)) ?? 1
            let verse = Int(nsString.substring(with: verseRange)) ?? 1
            
            return (book, chapter, verse)
        }
        
        return nil
    }
    
    private func getLocalizedBookName(_ englishBookName: String, language: CoreModels.VerseLanguage) -> String {
        if language == .english {
            return englishBookName
        }
        
        let localizedReference = CoreModels.VerseLanguage.localizeReference("\(englishBookName) 1:1", to: language)
        let localizedComponents = localizedReference.components(separatedBy: " ")
        
        if localizedComponents.count >= 2 {
            let localizedBookName = localizedComponents.dropLast().joined(separator: " ")
            return localizedBookName
        }
        
        return englishBookName
    }
}

struct HeaderSection: View {
    let language: CoreModels.VerseLanguage
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedText.Common.settings.text(for: language))
                        .font(DesignSystem.Typography.system(DesignSystem.Typography.title1, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                Spacer()
            }
            .greetingBar()
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
    }
}

struct LanguageButton: View {
    let title: String
    let language: CoreModels.VerseLanguage
    let selectedLanguage: CoreModels.VerseLanguage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 24) {
                Image(systemName: selectedLanguage == language ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundColor(selectedLanguage == language ? DesignSystem.Colors.accent : DesignSystem.Colors.mutedText)
                
                Text(title)
                    .font(DesignSystem.Typography.system(DesignSystem.Typography.body, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer(minLength: 28)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(selectedLanguage == language ? DesignSystem.Colors.cardBackground : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(DesignSystem.Colors.divider.opacity(0.8), lineWidth: 1.5)
                    )
            )
        }
    }
}
