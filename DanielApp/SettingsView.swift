import SwiftUI
import WidgetKit
import UserNotifications

struct SettingsView: View {
    // 环境对象
    @EnvironmentObject var appState: AppState
    
    // 状态变量
    @State private var notificationsEnabled = false
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
    
    // UserDefaults key
    private let notificationsEnabledKey = "notificationsEnabled"
    private let updateModeKey = "updateMode"
    private let languageKey = "preferredLanguage"
    private let manualVerseKey = "manualVerseReference"
    
    // 初始化时加载保存的设置
    init() {
        // 初始化语言选择
        let savedLanguage = VerseDataService.shared.getSelectedLanguage()
        _selectedLanguage = State(initialValue: savedLanguage)
        
        // 初始化更新模式
        let savedMode = VerseDataService.shared.getUpdateMode()
        _updateMode = State(initialValue: savedMode)
        
        // 初始化引用
        if let ref = VerseDataService.shared.getCurrentVerseReference() {
            _manualVerseReference = State(initialValue: ref)
            
            // 尝试解析引用格式，初始化书卷、章节和经文选择器
            if let parsedReference = parseReference(ref) {
                _selectedBook = State(initialValue: parsedReference.book)
                _selectedChapter = State(initialValue: parsedReference.chapter)
                _selectedVerse = State(initialValue: parsedReference.verse)
            }
        }
        
        // 初始化通知设置
        _notificationsEnabled = State(initialValue: UserDefaults.standard.bool(forKey: notificationsEnabledKey))
        
        // 初始化加载圣经书卷
        _availableBooks = State(initialValue: loadBibleBooks())
        
        // 预先计算章节和经文，如果已有选定的书卷
        if let ref = VerseDataService.shared.getCurrentVerseReference(),
           let parsedRef = parseReference(ref) {
            let chapters = getChaptersForBook(parsedRef.book)
            _availableChapters = State(initialValue: chapters)
            
            let verses = getVersesForChapter(parsedRef.book, parsedRef.chapter)
            _availableVerses = State(initialValue: verses)
        } else {
            // 默认初始化
            _availableChapters = State(initialValue: [1])
            _availableVerses = State(initialValue: [1])
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                StyleConstants.backgroundColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: StyleConstants.extraLargeSpacing) {
                        // 标题
                        Text(LocalizedText.Common.settings.text(for: appState.selectedLanguage))
                            .font(StyleConstants.serifTitle(30, language: appState.selectedLanguage))
                            .foregroundColor(StyleConstants.goldColor)
                            .padding(.top, StyleConstants.standardSpacing)
                            .padding(.bottom, StyleConstants.compactSpacing)
                        
                        // WIDGET 设置部分
                        VStack(alignment: .leading, spacing: StyleConstants.standardSpacing) {
                            Text(LocalizedText.Settings.pushSettings.text(for: appState.selectedLanguage))
                                .font(StyleConstants.sansFontBody(18))
                                .foregroundColor(StyleConstants.goldColor)
                                .padding(.horizontal)
                            
                            VStack(spacing: StyleConstants.standardSpacing) {
                                // 更新模式选择
                                Text(LocalizedText.Settings.updateMode.text(for: appState.selectedLanguage))
                                    .font(StyleConstants.sansFontBody(16))
                                    .foregroundColor(.white)
                                    .padding(.top, 5)
                                
                                // 自动模式选项
                                HStack {
                                    Image(systemName: updateMode == "automatic" ? "circle.fill" : "circle")
                                        .foregroundColor(StyleConstants.goldColor)
                                    
                                    Text(LocalizedText.Settings.autoUpdate.text(for: appState.selectedLanguage))
                                        .font(StyleConstants.sansFontBody(16))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if updateMode == "automatic" {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(StyleConstants.goldColor)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    updateMode = "automatic"
                                    VerseDataService.shared.setUpdateMode("automatic")
                                }
                                
                                // 手动模式选项
                                HStack {
                                    Image(systemName: updateMode == "manual" ? "circle.fill" : "circle")
                                        .foregroundColor(StyleConstants.goldColor)
                                    
                                    Text(LocalizedText.Settings.manualSelect.text(for: appState.selectedLanguage))
                                        .font(StyleConstants.sansFontBody(16))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    updateMode = "manual"
                                    VerseDataService.shared.setUpdateMode("manual")
                                }
                                
                                Divider()
                                    .background(StyleConstants.lightGoldColor.opacity(0.5))
                                    .padding(.vertical, 5)
                                
                                // Widget 语言选择
                                Text(LocalizedText.Settings.displayLanguage.text(for: appState.selectedLanguage))
                                    .font(StyleConstants.sansFontBody(16))
                                    .foregroundColor(.white)
                                    .padding(.top, 5)
                                
                                Text(LocalizedText.Settings.languageHint.text(for: appState.selectedLanguage))
                                    .font(StyleConstants.sansFontBody(12))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.bottom, 5)
                                
                                Picker("语言", selection: $selectedLanguage) {
                                    ForEach(CoreModels.VerseLanguage.allCases, id: \.self) { language in
                                        Text(language.description).tag(language)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.08))
                                )
                                .onChange(of: selectedLanguage) { newValue in
                                    VerseDataService.shared.setSelectedLanguage(newValue)
                                    
                                    // 更新App状态，确保主应用也更新
                                    appState.updateLanguage(newValue)
                                    
                                    // 重新加载Widget
                                    WidgetCenter.shared.reloadAllTimelines()
                                }
                                
                                // 手动选择经文选项 - 仅在手动模式下显示
                                if updateMode == "manual" {
                                    Divider()
                                        .background(StyleConstants.lightGoldColor.opacity(0.5))
                                        .padding(.vertical, 5)
                                    
                                    Text(LocalizedText.Settings.selectVerse.text(for: appState.selectedLanguage))
                                        .font(StyleConstants.sansFontBody(16))
                                        .foregroundColor(.white)
                                        .padding(.top, 5)
                                    
                                    // 书卷选择
                                    Picker(LocalizedText.Settings.bookPlaceholder.text(for: appState.selectedLanguage), selection: $selectedBook) {
                                        ForEach(availableBooks, id: \.self) { book in
                                            Text(getLocalizedBookName(book, language: selectedLanguage)).tag(book)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .onChange(of: selectedBook) { newBook in
                                        // 更新章节列表
                                        updateChaptersForBook(newBook)
                                    }
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.08))
                                    )
                                    
                                    HStack {
                                        // 章选择
                                        Picker("Chapter", selection: $selectedChapter) {
                                            ForEach(availableChapters, id: \.self) { chapter in
                                                Text("\(chapter)").tag(chapter)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .onChange(of: selectedChapter) { newChapter in
                                            // 更新经节列表
                                            updateVersesForChapter(newChapter)
                                        }
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.08))
                                        )
                                        
                                        Text(":")
                                            .foregroundColor(.white)
                                            .font(.title3)
                                            .padding(.horizontal, 5)
                                        
                                        // 节选择
                                        Picker("Verse", selection: $selectedVerse) {
                                            ForEach(availableVerses, id: \.self) { verse in
                                                Text("\(verse)").tag(verse)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .onChange(of: selectedVerse) { newVerse in
                                            // 更新引用
                                            if !selectedBook.isEmpty {
                                                manualVerseReference = "\(selectedBook) \(selectedChapter):\(selectedVerse)"
                                            }
                                        }
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.08))
                                        )
                                    }
                                    .padding(.vertical, 5)
                                    
                                    // 经文引用输入框
                                    TextField(LocalizedText.Settings.versePlaceholder.text(for: appState.selectedLanguage), text: $manualVerseReference)
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white.opacity(0.08))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(StyleConstants.goldColor.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                        .foregroundColor(.white)
                                        .onChange(of: manualVerseReference) { newValue in
                                            // 当手动输入时，尝试解析本地化引用
                                            if selectedLanguage != .english && !newValue.isEmpty {
                                                let standardizedRef = CoreModels.VerseLanguage.standardizeReference(newValue, from: selectedLanguage)
                                                if standardizedRef != newValue {
                                                    // 如果成功标准化，尝试解析标准化后的引用
                                                    if let parsedReference = parseReference(standardizedRef) {
                                                        // 延迟执行，避免输入冲突
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                            selectedBook = parsedReference.book
                                                            updateChaptersForBook(parsedReference.book)
                                                            selectedChapter = parsedReference.chapter
                                                            updateVersesForChapter(parsedReference.chapter)
                                                            selectedVerse = parsedReference.verse
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    
                                    // 保存选择的经文
                                    Button(LocalizedText.Settings.setVerse.text(for: appState.selectedLanguage)) {
                                        var reference: String
                                        
                                        if !manualVerseReference.isEmpty {
                                            // 使用文本框输入的引用
                                            reference = manualVerseReference
                                            
                                            // 如果是非英文引用，尝试标准化
                                            if selectedLanguage != .english {
                                                let standardizedRef = CoreModels.VerseLanguage.standardizeReference(reference, from: selectedLanguage)
                                                if standardizedRef != reference {
                                                    reference = standardizedRef
                                                }
                                            }
                                        } else if !selectedBook.isEmpty {
                                            // 使用Picker选择的引用
                                            reference = "\(selectedBook) \(selectedChapter):\(selectedVerse)"
                                        } else {
                                            return
                                        }
                                        
                                        // 验证经文存在
                                        if let verse = VerseDataService.shared.findVerse(byReference: reference) {
                                            VerseDataService.shared.setCurrentVerseReference(reference)
                                            VerseDataService.shared.setVerseFixed(true)
                                            
                                            // 更新应用状态
                                            appState.selectedVerseReference = reference
                                            
                                            // 提示信息
                                            let verseText = selectedLanguage == .chinese ? verse.cn : 
                                                           (selectedLanguage == .english ? verse.en : verse.kr)
                                            print("已设置经文: \(reference) - \(verseText.prefix(20))...")
                                            
                                            // 重新加载Widget
                                            WidgetCenter.shared.reloadAllTimelines()
                                        } else {
                                            // 经文不存在的处理
                                            print("未找到经文: \(reference)")
                                        }
                                    }
                                    .buttonStyle(GoldBorderButtonStyle())
                                    .padding(.top, StyleConstants.compactSpacing)
                                } else {
                                    // 自动模式下的固定/取消固定经文选项
                                    Divider()
                                        .background(StyleConstants.lightGoldColor.opacity(0.5))
                                        .padding(.vertical, 5)
                                    
                                    if VerseDataService.shared.isVerseFixed() {
                                        Text(LocalizedText.Settings.currentFixedVerse.text(for: appState.selectedLanguage))
                                            .font(StyleConstants.sansFontBody(14))
                                            .foregroundColor(.white)
                                            .padding(.top, 5)
                                        
                                        if let ref = VerseDataService.shared.getCurrentVerseReference() {
                                            Text(ref)
                                                .font(StyleConstants.sansFontBody(16))
                                                .foregroundColor(StyleConstants.goldColor)
                                                .padding(.bottom, 5)
                                        }
                                        
                                        Button(LocalizedText.Settings.unfixVerse.text(for: appState.selectedLanguage)) {
                                            VerseDataService.shared.setVerseFixed(false)
                                            VerseDataService.shared.setCurrentVerseReference(nil)
                                            
                                            // 更新应用状态
                                            appState.selectedVerseReference = nil
                                            
                                            // 提示信息
                                            print("已取消固定经文，恢复自动更新")
                                            
                                            // 重新加载Widget
                                            WidgetCenter.shared.reloadAllTimelines()
                                        }
                                        .buttonStyle(GoldBorderButtonStyle())
                                        .padding(.top, 5)
                                    } else {
                                        Text(LocalizedText.Settings.autoUpdateMode.text(for: appState.selectedLanguage))
                                            .font(StyleConstants.sansFontBody(14))
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(.top, 5)
                                    }
                                }
                            }
                            .settingContainer()
                        }
                        
                        // PUSH NOTIFICATIONS section removed
                        
                        // 圣经版本信息框
                        VStack(alignment: .center, spacing: StyleConstants.compactSpacing) {
                            Text(LocalizedText.Common.versionInfo.text(for: appState.selectedLanguage))
                                .font(StyleConstants.sansFontBody(18))
                                .foregroundColor(StyleConstants.goldColor)
                                .padding(.horizontal)
                            
                            VStack(spacing: 5) {
                                Text(LocalizedText.Common.bibleVersionInfo.text(for: appState.selectedLanguage))
                                    .font(StyleConstants.sansFontBody(16))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical, StyleConstants.compactSpacing)
                                    .padding(.horizontal, 5)
                            }
                            .settingContainer()
                        }
                        
                        // 版权信息框
                        VStack(alignment: .center, spacing: StyleConstants.compactSpacing) {
                            Text(LocalizedText.Common.versionInfo.text(for: appState.selectedLanguage))
                                .font(StyleConstants.sansFontBody(18))
                                .foregroundColor(StyleConstants.goldColor)
                                .padding(.horizontal)
                            
                            VStack(spacing: 5) {
                                Text("version 1.0")
                                    .font(StyleConstants.sansFontBody(16))
                                    .foregroundColor(.white)
                                    .padding(.top, 5)
                                
                                Text(LocalizedText.Common.copyright.text(for: appState.selectedLanguage))
                                    .font(StyleConstants.sansFontBody(14))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .settingContainer()
                        }
                        
                        // 调试工具部分
                        VStack(alignment: .center, spacing: StyleConstants.compactSpacing) {
                            Text("调试工具")
                                .font(StyleConstants.sansFontBody(18))
                                .foregroundColor(StyleConstants.goldColor)
                                .padding(.horizontal)
                            
                            VStack(spacing: 10) {
                                Text("如果小组件和主应用显示不同步，可以尝试重置")
                                    .font(StyleConstants.sansFontBody(14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                
                                Button("重置小组件状态") {
                                    print("🔄 用户触发重置操作")
                                    VerseDataService.shared.forceResetTempState()
                                }
                                .buttonStyle(GoldBorderButtonStyle())
                                .padding(.top, 5)
                            }
                            .settingContainer()
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.bottom, StyleConstants.mediumSpacing)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // 请求通知权限
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                print("通知权限获取成功")
            } else if let error = error {
                print("通知权限获取失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 从JSON加载可用的圣经书卷
    private func loadBibleBooks() -> [String] {
        // 使用与verses_merged.json一致的书卷名称格式，使用罗马数字
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
    
    // 根据选定书卷更新章节列表
    private func updateChaptersForBook(_ book: String) {
        // 初始化
        var maxChapter = 28 // 默认章节数

        // 根据书卷定制章节数量
        switch book {
        case "Genesis": maxChapter = 50
        case "Exodus": maxChapter = 40
        case "Leviticus": maxChapter = 27
        case "Numbers": maxChapter = 36
        case "Deuteronomy": maxChapter = 34
        case "Joshua": maxChapter = 24
        case "Judges": maxChapter = 21
        case "Ruth": maxChapter = 4
        case "I Samuel", "I Kings": maxChapter = 31
        case "II Samuel": maxChapter = 24
        case "II Kings": maxChapter = 25
        case "I Chronicles": maxChapter = 29
        case "II Chronicles": maxChapter = 36
        case "Ezra": maxChapter = 10
        case "Nehemiah": maxChapter = 13
        case "Esther": maxChapter = 10
        case "Job": maxChapter = 42
        case "Psalms": maxChapter = 150
        case "Proverbs": maxChapter = 31
        case "Ecclesiastes": maxChapter = 12
        case "Song of Solomon": maxChapter = 8
        case "Isaiah": maxChapter = 66
        case "Jeremiah": maxChapter = 52
        case "Lamentations": maxChapter = 5
        case "Ezekiel": maxChapter = 48
        case "Daniel": maxChapter = 12
        case "Hosea": maxChapter = 14
        case "Joel": maxChapter = 3
        case "Amos": maxChapter = 9
        case "Obadiah": maxChapter = 1
        case "Jonah": maxChapter = 4
        case "Micah": maxChapter = 7
        case "Nahum": maxChapter = 3
        case "Habakkuk": maxChapter = 3
        case "Zephaniah": maxChapter = 3
        case "Haggai": maxChapter = 2
        case "Zechariah": maxChapter = 14
        case "Malachi": maxChapter = 4
        case "Matthew": maxChapter = 28
        case "Mark": maxChapter = 16
        case "Luke": maxChapter = 24
        case "John": maxChapter = 21
        case "Acts": maxChapter = 28
        case "Romans": maxChapter = 16
        case "I Corinthians": maxChapter = 16
        case "II Corinthians": maxChapter = 13
        case "Galatians": maxChapter = 6
        case "Ephesians": maxChapter = 6
        case "Philippians": maxChapter = 4
        case "Colossians": maxChapter = 4
        case "I Thessalonians": maxChapter = 5
        case "II Thessalonians": maxChapter = 3
        case "I Timothy": maxChapter = 6
        case "II Timothy": maxChapter = 4
        case "Titus": maxChapter = 3
        case "Philemon": maxChapter = 1
        case "Hebrews": maxChapter = 13
        case "James": maxChapter = 5
        case "I Peter": maxChapter = 5
        case "II Peter": maxChapter = 3
        case "I John": maxChapter = 5
        case "II John", "III John": maxChapter = 1
        case "Jude": maxChapter = 1
        case "Revelation": maxChapter = 22
        default: maxChapter = 28 // 默认值
        }
            
        availableChapters = Array(1...maxChapter)
        selectedChapter = 1
        updateVersesForChapter(1)
    }
    
    // 根据选定章节更新经节列表
    private func updateVersesForChapter(_ chapter: Int) {
        // 初始化
        var maxVerse = 30 // 默认经文数量
        
        // 这里可以添加更精确的逻辑来确定每个书卷每章的具体经文数量
        // 为了实现简单，这里使用较长的默认值，确保大多数情况下可以选择
        if selectedBook == "Psalms" {
            if chapter == 119 {
                maxVerse = 176 // 诗篇119篇有176节
            } else {
                maxVerse = 50 // 诗篇其他章节最大约50节
            }
        } else if selectedBook == "Genesis" && chapter == 1 {
            maxVerse = 31 // 创世记第1章有31节
        } else {
            // 使用默认值，后期可以根据需要完善
            maxVerse = 40
        }
        
        availableVerses = Array(1...maxVerse)
        selectedVerse = 1
        
        // 更新引用字段
        if !selectedBook.isEmpty {
            manualVerseReference = "\(selectedBook) \(selectedChapter):\(selectedVerse)"
        }
    }
    
    // 解析经文引用
    private func parseReference(_ reference: String) -> (book: String, chapter: Int, verse: Int)? {
        // 匹配格式: "Book Chapter:Verse" 或 "I Book Chapter:Verse" 或 "II Book Chapter:Verse"
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
            
            // 检查书卷名称是否在我们的列表中
            if availableBooks.contains(book) {
                return (book, chapter, verse)
            } else {
                // 尝试查找替代格式 (比如 "1 Samuel" -> "I Samuel")
                for availableBook in availableBooks {
                    // 移除罗马数字前缀，比对书卷主名称
                    let mainBookName = book.replacingOccurrences(of: "^[\\d]+ ", with: "", options: .regularExpression)
                    let availableMainName = availableBook.replacingOccurrences(of: "^[IVX]+ ", with: "", options: .regularExpression)
                    
                    if mainBookName == availableMainName {
                        // 找到匹配的主名称，使用availableBook (正确格式)
                        return (availableBook, chapter, verse)
                    }
                }
            }
        }
        
        return nil
    }
    
    // 获取书卷对应的章节列表
    private func getChaptersForBook(_ book: String) -> [Int] {
        var maxChapter = 28 // 默认值
        
        switch book {
        case "Genesis": maxChapter = 50
        case "Exodus": maxChapter = 40
        case "Psalms": maxChapter = 150
        // ... 可以添加更多书卷的章节数量 ...
        default: break
        }
        
        return Array(1...maxChapter)
    }
    
    // 获取章节对应的经文列表
    private func getVersesForChapter(_ book: String, _ chapter: Int) -> [Int] {
        var maxVerse = 30 // 默认值
        
        if book == "Psalms" && chapter == 119 {
            maxVerse = 176
        } else if book == "Psalms" {
            maxVerse = 50
        }
        
        return Array(1...maxVerse)
    }
    
    // 获取本地化的书卷名称
    private func getLocalizedBookName(_ englishBookName: String, language: CoreModels.VerseLanguage) -> String {
        if language == .english {
            return englishBookName
        }
        
        // 临时变量保存标准化后的书卷名称
        var standardizedBookName = englishBookName
        
        // 转换罗马数字前缀为阿拉伯数字，以匹配映射表中的格式
        if englishBookName.hasPrefix("I ") {
            standardizedBookName = "1 " + englishBookName.dropFirst(2)
        } else if englishBookName.hasPrefix("II ") {
            standardizedBookName = "2 " + englishBookName.dropFirst(3)
        } else if englishBookName.hasPrefix("III ") {
            standardizedBookName = "3 " + englishBookName.dropFirst(4)
        }
        
        // 提取书卷名和章节
        let components = standardizedBookName.components(separatedBy: " ")
        guard components.count >= 1 else { return englishBookName }
        
        let bookName = standardizedBookName
        
        // 使用已有映射函数处理
        let localizedReference = CoreModels.VerseLanguage.localizeReference("\(bookName) 1:1", to: language)
        let localizedComponents = localizedReference.components(separatedBy: " ")
        
        if localizedComponents.count >= 2 {
            // 去掉章节部分，只返回书名
            let localizedBookName = localizedComponents.dropLast().joined(separator: " ")
            return localizedBookName
        }
        
        return englishBookName
    }
}
