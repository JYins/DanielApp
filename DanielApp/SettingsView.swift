import SwiftUI
import WidgetKit
import UserNotifications

// MARK: - Bubble按钮样式
struct BubbleButtonStyle: ButtonStyle {
    let language: CoreModels.VerseLanguage
    @State private var isPressed = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignSystem.Typography.smart(DesignSystem.Typography.callout, weight: .semibold, language: language))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                DesignSystem.Colors.accent,
                                DesignSystem.Colors.accent.opacity(0.8)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: DesignSystem.Colors.accent.opacity(0.3),
                        radius: configuration.isPressed ? 2 : 6,
                        x: 0,
                        y: configuration.isPressed ? 1 : 3
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var authManager = AuthManager.shared
    
    // 状态变量
    @State private var updateMode: String = "automatic"
    @State private var selectedLanguage: CoreModels.VerseLanguage = .chinese
    @State private var manualVerseReference: String = ""
    @State private var fontSizeIndex = 1
    @State private var notificationsEnabled = true
    @State private var appearanceMode: AppAppearanceMode = .system
    @State private var showingLogin = false
    @State private var showingSignOutConfirmation = false
    @State private var showingAccountError = false
    @State private var showingHelp = false
    @State private var showingFavorites = false
    
    // 为手动选择经文准备的数据结构
    @State private var selectedBook = ""
    @State private var selectedChapter = 1
    @State private var selectedVerse = 1
    @State private var availableBooks: [String] = []
    @State private var availableChapters: [Int] = []
    @State private var availableVerses: [Int] = []
    
    private var selectedLanguageLabel: String {
        switch selectedLanguage {
        case .chinese:
            return "中文"
        case .english:
            return "English"
        case .korean:
            return "한국어"
        }
    }
    
    private var fontSizeBinding: Binding<Int> {
        Binding(
            get: { fontSizeIndex },
            set: { newValue in
                fontSizeIndex = newValue
                appState.updateFontSizeIndex(newValue)
            }
        )
    }
    
    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { notificationsEnabled },
            set: { newValue in
                notificationsEnabled = newValue
                appState.updateNotificationsEnabled(newValue)
                if newValue {
                    requestNotificationPermission()
                }
            }
        )
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        switch selectedLanguage {
        case .chinese:
            return "App 版本 \(version) (\(build))"
        case .english:
            return "App Version \(version) (\(build))"
        case .korean:
            return "앱 버전 \(version) (\(build))"
        }
    }
    
    var body: some View {
        ZStack {
            DesignSystem.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    HeaderSection(language: selectedLanguage)
                    
                    SettingsSectionCard(title: localizedPreferencesTitle, language: selectedLanguage) {
                        VStack(spacing: 0) {
                            SettingsNavigationRow(
                                icon: "globe",
                                title: LocalizedText.Settings.displayLanguage.text(for: selectedLanguage),
                                subtitle: selectedLanguageLabel,
                                language: selectedLanguage
                            )
                            
                            SettingsDivider()
                            
                            SettingsFontSizeRow(fontSizeIndex: fontSizeBinding, language: selectedLanguage)
                            
                            SettingsDivider()
                            
                            SettingsToggleRow(
                                icon: "bell",
                                title: localizedNotificationsTitle,
                                subtitle: localizedNotificationsSubtitle,
                                isOn: notificationsBinding,
                                language: selectedLanguage
                            )
                            
                            SettingsDivider()
                            
                            SettingsAppearanceRow(
                                icon: "moon",
                                title: localizedAppearanceTitle,
                                subtitle: localizedAppearanceSubtitle,
                                selectedMode: $appearanceMode,
                                language: selectedLanguage
                            ) { mode in
                                appState.updateAppearanceMode(mode)
                            }
                            
                            SettingsDivider()
                            
                            VStack(alignment: .leading, spacing: 16) {
                                SettingsRowHeader(
                                    icon: "clock",
                                    title: LocalizedText.Settings.updateMode.text(for: selectedLanguage),
                                    subtitle: updateMode == "automatic" ? LocalizedText.Settings.autoUpdate.text(for: selectedLanguage) : LocalizedText.Settings.manualUpdate.text(for: selectedLanguage),
                                    language: selectedLanguage
                                )
                                
                                VStack(spacing: 10) {
                                    SettingsRadioButton(
                                        title: LocalizedText.Settings.autoUpdate.text(for: selectedLanguage),
                                        isSelected: updateMode == "automatic",
                                        language: selectedLanguage,
                                        action: switchToAutomaticMode
                                    )
                                    
                                    SettingsRadioButton(
                                        title: LocalizedText.Settings.manualUpdate.text(for: selectedLanguage),
                                        isSelected: updateMode == "manual",
                                        language: selectedLanguage,
                                        action: switchToManualMode
                                    )
                                }
                            }
                            .padding(.vertical, 16)
                            
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
                                    .onChange(of: selectedBook) { _, newBook in
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
                                        .onChange(of: selectedChapter) { _, newChapter in
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
                                        .onChange(of: selectedVerse) { _, _ in
                                            updateManualReferenceFromPicker()
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
                                    
                                    // 保存选择的经文 - 使用Bubble样式
                                    HStack {
                                        Spacer()
                                        Button(LocalizedText.Settings.setVerse.text(for: selectedLanguage)) {
                                            setManualVerse()
                                        }
                                        .buttonStyle(ModernButtonStyle(language: selectedLanguage, variant: .primary))
                                        Spacer()
                                    }
                                    .padding(.top, 16)
                                }
                                .padding(.bottom, 16)
                            }
                            
                            SettingsDivider()
                            
                            VStack(spacing: 12) {
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
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    SettingsSectionCard(title: localizedAccountTitle, language: selectedLanguage) {
                        VStack(spacing: 0) {
                            SettingsAccountRow(language: selectedLanguage) {
                                if !authManager.authState.isSignedIn {
                                    showingLogin = true
                                }
                            }

                            SettingsDivider()

                            SettingsActionRow(
                                icon: "heart.text.square",
                                title: localizedFavoritesTitle,
                                subtitle: localizedFavoritesSubtitle,
                                language: selectedLanguage
                            ) {
                                showingFavorites = true
                            }

                            if let profile = authManager.currentUser {
                                SettingsDivider()

                                SettingsBranchAccessRows(
                                    profile: profile,
                                    language: selectedLanguage
                                )
                            }
                            
                            SettingsDivider()
                            
                            if authManager.authState.isSignedIn {
                                SettingsActionRow(
                                    icon: "rectangle.portrait.and.arrow.right",
                                    title: localizedSignOutTitle,
                                    subtitle: localizedSignOutSubtitle,
                                    role: .destructive,
                                    language: selectedLanguage
                                ) {
                                    showingSignOutConfirmation = true
                                }
                            } else {
                                SettingsActionRow(
                                    icon: "person.crop.circle.badge.plus",
                                    title: localizedSignInTitle,
                                    subtitle: localizedSignInSubtitle,
                                    language: selectedLanguage
                                ) {
                                    showingLogin = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    SettingsSectionCard(title: localizedSupportTitle, language: selectedLanguage) {
                        VStack(spacing: 0) {
                            SettingsActionRow(
                                icon: "questionmark.circle",
                                title: localizedHelpTitle,
                                subtitle: localizedHelpSubtitle,
                                language: selectedLanguage
                            ) {
                                showingHelp = true
                            }
                            
                            SettingsDivider()
                            
                            SettingsActionRow(
                                icon: "envelope",
                                title: localizedContactTitle,
                                subtitle: localizedContactSubtitle,
                                language: selectedLanguage
                            ) {
                                showingHelp = true
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    SettingsSectionCard(title: LocalizedText.Common.versionInfo.text(for: selectedLanguage), language: selectedLanguage) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(LocalizedText.Common.bibleVersionInfo.text(for: selectedLanguage))
                                .font(DesignSystem.Typography.smart(14, language: selectedLanguage))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(4)
                        
                            Text(appVersionText)
                                .font(DesignSystem.Typography.smart(DesignSystem.Typography.footnote, language: selectedLanguage))
                                .foregroundColor(DesignSystem.Colors.mutedText)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 30)
                }
            }
        }
        .onAppear {
            initializeSettings()
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingHelp) {
            SettingsHelpView(language: selectedLanguage)
        }
        .sheet(isPresented: $showingFavorites) {
            NavigationStack {
                FavoritesView(language: selectedLanguage)
            }
        }
        .confirmationDialog(
            localizedSignOutConfirmationTitle,
            isPresented: $showingSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button(localizedSignOutTitle, role: .destructive) {
                signOut()
            }
            
            Button(LocalizedText.NewsletterView.cancel.text(for: selectedLanguage), role: .cancel) {}
        } message: {
            Text(localizedSignOutConfirmationMessage)
        }
        .alert(localizedAccountErrorTitle, isPresented: $showingAccountError) {
            Button(localizedOKTitle, role: .cancel) {
                authManager.clearError()
            }
        } message: {
            Text(authManager.errorMessage ?? localizedAccountFallbackError)
        }
    }
    
    // MARK: - 私有方法
    
    private func initializeSettings() {
        selectedLanguage = appState.selectedLanguage
        updateMode = VerseDataService.shared.getUpdateMode()
        fontSizeIndex = appState.fontSizeIndex
        notificationsEnabled = appState.notificationsEnabled
        appearanceMode = appState.appearanceMode
        
        // 初始化手动模式数据
        availableBooks = loadBibleBooks()
        if selectedBook.isEmpty {
            selectedBook = availableBooks.first ?? ""
        }
        updateChaptersForBook(selectedBook, resetToFirstChapter: false)
        
        if let ref = VerseDataService.shared.getCurrentVerseReference() {
            manualVerseReference = ref
            if let parsedRef = parseReference(ref) {
                selectedBook = parsedRef.book
                updateChaptersForBook(parsedRef.book, resetToFirstChapter: false)
                selectedChapter = availableChapters.contains(parsedRef.chapter) ? parsedRef.chapter : (availableChapters.first ?? parsedRef.chapter)
                updateVersesForChapter(selectedChapter, resetToFirstVerse: false)
                selectedVerse = availableVerses.contains(parsedRef.verse) ? parsedRef.verse : (availableVerses.first ?? parsedRef.verse)
                updateManualReferenceFromPicker()
            }
        }
    }
    
    private func selectLanguage(_ language: CoreModels.VerseLanguage) {
        selectedLanguage = language
        appState.updateLanguage(language)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 切换到自动模式
    private func switchToAutomaticMode() {
        print("🔄 切换到自动模式")
        
        // 更新本地状态
        updateMode = "automatic"
        
        // 更新服务状态
        VerseDataService.shared.setUpdateMode("automatic")
        
        // 取消固定状态（如果有的话）
        VerseDataService.shared.setVerseFixed(false)
        
        // 如果当前有手动选择的经文，保留它直到下一个零点
        // 这里不需要清除当前经文引用，让自动更新逻辑在零点处理
        print("已切换到自动模式，当前经文将保留到下一个零点")
        
        // 通知VerseOfTheDayView刷新状态
        appState.needsRefreshVerseStatus = true
        
        // 刷新Widget
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 切换到手动模式
    private func switchToManualMode() {
        print("🔄 切换到手动模式")
        
        // 更新本地状态
        updateMode = "manual"
        
        // 更新服务状态
        VerseDataService.shared.setUpdateMode("manual")
        
        // 确保当前有经文引用（如果没有的话使用当前显示的）
        if VerseDataService.shared.getCurrentVerseReference() == nil {
            if let currentVerse = VerseDataService.shared.getCurrentVerseToDisplay() {
                VerseDataService.shared.setCurrentVerseReference(currentVerse.reference)
                print("手动模式：设置当前经文为 \(currentVerse.reference)")
            }
        }
        
        print("已切换到手动模式")
        
        // 通知VerseOfTheDayView刷新状态
        appState.needsRefreshVerseStatus = true
        
        // 刷新Widget
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
            VerseDataService.shared.setCurrentVerseReference(verse.reference)
            VerseDataService.shared.setVerseFixed(true)
            appState.selectedVerseReference = verse.reference
            manualVerseReference = verse.reference
            
            let verseText = selectedLanguage == .chinese ? verse.cn : 
                           (selectedLanguage == .english ? verse.en : verse.kr)
            print("已设置经文: \(verse.reference) - \(verseText.prefix(20))...")
            
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            print("未找到经文: \(reference)")
        }
    }
    
    private func loadBibleBooks() -> [String] {
        VerseDataService.shared.getBibleBookNames()
    }
    
    private func updateChaptersForBook(_ book: String, resetToFirstChapter: Bool = true) {
        guard !book.isEmpty else {
            availableChapters = []
            availableVerses = []
            return
        }
        
        availableChapters = VerseDataService.shared.getAvailableChapters(forBook: book)
        if resetToFirstChapter || !availableChapters.contains(selectedChapter) {
            selectedChapter = availableChapters.first ?? 1
        }
        updateVersesForChapter(selectedChapter)
    }
    
    private func updateVersesForChapter(_ chapter: Int, resetToFirstVerse: Bool = true) {
        guard !selectedBook.isEmpty else {
            availableVerses = []
            return
        }
        
        availableVerses = VerseDataService.shared.getAvailableVerses(forBook: selectedBook, chapter: chapter)
        if resetToFirstVerse || !availableVerses.contains(selectedVerse) {
            selectedVerse = availableVerses.first ?? 1
        }
        updateManualReferenceFromPicker()
    }
    
    private func updateManualReferenceFromPicker() {
        guard !selectedBook.isEmpty else { return }
        manualVerseReference = "\(selectedBook) \(selectedChapter):\(selectedVerse)"
    }
    
    private func parseReference(_ reference: String) -> (book: String, chapter: Int, verse: Int)? {
        let standardizedReference = CoreModels.VerseLanguage.standardizeReference(reference, from: selectedLanguage)
        let pattern = "([\\w\\s]+)\\s+(\\d+):(\\d+)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        if let regex = regex,
           let match = regex.firstMatch(in: standardizedReference, options: [], range: NSRange(location: 0, length: standardizedReference.count)) {
            let nsString = standardizedReference as NSString
            
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
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("通知授权失败: \(error.localizedDescription)")
                }
                notificationsEnabled = granted
                appState.updateNotificationsEnabled(granted)
            }
        }
    }
    
    private func signOut() {
        authManager.signOut()
        if authManager.errorMessage != nil {
            showingAccountError = true
        }
    }
    
    private var localizedPreferencesTitle: String {
        switch selectedLanguage {
        case .chinese: return "偏好设置"
        case .english: return "Preferences"
        case .korean: return "환경설정"
        }
    }
    
    private var localizedAccountTitle: String {
        switch selectedLanguage {
        case .chinese: return "账户"
        case .english: return "Account"
        case .korean: return "계정"
        }
    }
    
    private var localizedSupportTitle: String {
        switch selectedLanguage {
        case .chinese: return "支持"
        case .english: return "Support"
        case .korean: return "지원"
        }
    }
    
    private var localizedNotificationsTitle: String {
        switch selectedLanguage {
        case .chinese: return "通知"
        case .english: return "Notifications"
        case .korean: return "알림"
        }
    }
    
    private var localizedNotificationsSubtitle: String {
        switch selectedLanguage {
        case .chinese: return "每日经文提醒"
        case .english: return "Daily verse reminders"
        case .korean: return "매일 말씀 알림"
        }
    }
    
    private var localizedAppearanceTitle: String {
        switch selectedLanguage {
        case .chinese: return "外观"
        case .english: return "Appearance"
        case .korean: return "화면 모드"
        }
    }
    
    private var localizedAppearanceSubtitle: String {
        switch selectedLanguage {
        case .chinese: return "默认跟随系统深色/浅色设置"
        case .english: return "Follows the system light or dark setting by default"
        case .korean: return "기본값은 시스템 라이트/다크 설정을 따릅니다"
        }
    }
    
    private var localizedHelpTitle: String {
        switch selectedLanguage {
        case .chinese: return "帮助与 FAQ"
        case .english: return "Help & FAQ"
        case .korean: return "도움말 및 FAQ"
        }
    }
    
    private var localizedHelpSubtitle: String {
        switch selectedLanguage {
        case .chinese: return "使用说明与常见问题"
        case .english: return "Guides and common questions"
        case .korean: return "사용 안내와 자주 묻는 질문"
        }
    }
    
    private var localizedSignOutTitle: String {
        switch selectedLanguage {
        case .chinese: return "退出登录"
        case .english: return "Sign Out"
        case .korean: return "로그아웃"
        }
    }
    
    private var localizedSignOutSubtitle: String {
        switch selectedLanguage {
        case .chinese: return "结束当前账户会话"
        case .english: return "End the current account session"
        case .korean: return "현재 계정 세션 종료"
        }
    }
    
    private var localizedSignInTitle: String {
        switch selectedLanguage {
        case .chinese: return "登录或注册"
        case .english: return "Sign In or Register"
        case .korean: return "로그인 또는 가입"
        }
    }
    
    private var localizedSignInSubtitle: String {
        switch selectedLanguage {
        case .chinese: return "连接分堂通讯和成员内容"
        case .english: return "Connect church communication and member content"
        case .korean: return "교회 소식과 회원 콘텐츠 연결"
        }
    }
    
    private var localizedSignOutConfirmationTitle: String {
        switch selectedLanguage {
        case .chinese: return "确认退出登录？"
        case .english: return "Sign out?"
        case .korean: return "로그아웃할까요?"
        }
    }
    
    private var localizedSignOutConfirmationMessage: String {
        switch selectedLanguage {
        case .chinese: return "退出后仍可阅读每日经文和公开资源，会员通讯需要重新登录。"
        case .english: return "You can still read Daily Verse and public resources. Member communication will require signing in again."
        case .korean: return "로그아웃 후에도 매일 말씀과 공개 자료는 볼 수 있습니다. 회원 소식은 다시 로그인해야 합니다."
        }
    }
    
    private var localizedContactTitle: String {
        switch selectedLanguage {
        case .chinese: return "联系支持"
        case .english: return "Contact Support"
        case .korean: return "지원 문의"
        }
    }
    
    private var localizedContactSubtitle: String {
        switch selectedLanguage {
        case .chinese: return "账户、访问权限或内容问题"
        case .english: return "Account, access, or content questions"
        case .korean: return "계정, 접근 권한 또는 콘텐츠 문의"
        }
    }

    private var localizedFavoritesTitle: String {
        switch selectedLanguage {
        case .chinese: return "收藏夹"
        case .english: return "Favorites"
        case .korean: return "즐겨찾기"
        }
    }

    private var localizedFavoritesSubtitle: String {
        switch selectedLanguage {
        case .chinese: return "按日期查看保存的经文和笔记"
        case .english: return "Saved verses and notes by date"
        case .korean: return "날짜별 저장 말씀과 노트"
        }
    }
    
    private var localizedAccountErrorTitle: String {
        switch selectedLanguage {
        case .chinese: return "账户操作失败"
        case .english: return "Account Action Failed"
        case .korean: return "계정 작업 실패"
        }
    }
    
    private var localizedAccountFallbackError: String {
        switch selectedLanguage {
        case .chinese: return "请稍后再试。"
        case .english: return "Please try again later."
        case .korean: return "나중에 다시 시도해 주세요."
        }
    }
    
    private var localizedOKTitle: String {
        switch selectedLanguage {
        case .chinese: return "好的"
        case .english: return "OK"
        case .korean: return "확인"
        }
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
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedText.Common.settings.text(for: language))
                    .font(DesignSystem.Typography.smart(30, weight: .bold, language: language))
                    .foregroundColor(DesignSystem.Colors.accentDark)
                
                Text(settingsSubtitle)
                    .font(DesignSystem.Typography.smart(16, weight: .medium, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
            }
            
            Spacer()
            
            VerseUserButtonView()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
    
    private var settingsSubtitle: String {
        switch language {
        case .chinese:
            return "自定义你的体验"
        case .english:
            return "Customize your experience"
        case .korean:
            return "경험을 맞춤 설정하세요"
        }
    }
}

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let language: CoreModels.VerseLanguage
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(DesignSystem.Typography.smart(18, weight: .bold, language: language))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)
            
            content
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .shadow(
            color: DesignSystem.Shadow.card.color,
            radius: DesignSystem.Shadow.card.radius,
            x: DesignSystem.Shadow.card.x,
            y: DesignSystem.Shadow.card.y
        )
    }
}

struct SettingsHelpView: View {
    let language: CoreModels.VerseLanguage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(helpItems, id: \.title) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .font(DesignSystem.Typography.smart(16, weight: .bold, language: language))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                
                                Text(item.body)
                                    .font(DesignSystem.Typography.smart(14, language: language))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                    .lineSpacing(4)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignSystem.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium))
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.medium)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                            )
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(closeTitle) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var title: String {
        switch language {
        case .chinese: return "帮助与 FAQ"
        case .english: return "Help & FAQ"
        case .korean: return "도움말 및 FAQ"
        }
    }
    
    private var closeTitle: String {
        switch language {
        case .chinese: return "关闭"
        case .english: return "Close"
        case .korean: return "닫기"
        }
    }
    
    private var helpItems: [(title: String, body: String)] {
        switch language {
        case .chinese:
            return [
                ("账户审核", "注册后需要管理员审核。审核通过后，可以访问会员通讯和分堂相关内容。"),
                ("退出登录", "退出后仍可阅读每日经文和公开资源。需要会员权限的内容会要求重新登录。"),
                ("通知提醒", "打开通知后，系统会请求 iOS 通知权限。若稍后需要修改，可以到 iOS 设置中调整。"),
                ("外观模式", "默认跟随 iOS 系统深色或浅色外观，也可以在设置中固定为浅色或深色。")
            ]
        case .english:
            return [
                ("Account Review", "New registrations require admin approval. Once approved, member communication and branch content become available."),
                ("Signing Out", "After signing out, Daily Verse and public resources remain available. Member-only content will ask you to sign in again."),
                ("Notifications", "When notifications are enabled, iOS will ask for permission. You can adjust that permission later in iOS Settings."),
                ("Appearance", "The app follows the iOS light or dark appearance by default. You can also pin the app to Light or Dark.")
            ]
        case .korean:
            return [
                ("계정 승인", "새 가입은 관리자 승인이 필요합니다. 승인 후 회원 소식과 지교회 콘텐츠를 볼 수 있습니다."),
                ("로그아웃", "로그아웃 후에도 매일 말씀과 공개 자료는 볼 수 있습니다. 회원 전용 콘텐츠는 다시 로그인을 요청합니다."),
                ("알림", "알림을 켜면 iOS 알림 권한을 요청합니다. 이후 권한은 iOS 설정에서 변경할 수 있습니다."),
                ("화면 모드", "기본값은 iOS 시스템의 라이트 또는 다크 모드를 따릅니다. 설정에서 라이트나 다크로 고정할 수도 있습니다.")
            ]
        }
    }
}

struct SettingsNavigationRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let language: CoreModels.VerseLanguage
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DesignSystem.Colors.mutedText)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.smart(14, weight: .semibold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.smart(12, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.mutedText.opacity(0.7))
        }
        .padding(.vertical, 16)
    }
}

struct SettingsActionRow: View {
    enum RowRole {
        case normal
        case destructive
    }
    
    let icon: String
    let title: String
    let subtitle: String
    var role: RowRole = .normal
    let language: CoreModels.VerseLanguage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignSystem.Typography.smart(14, weight: .semibold, language: language))
                        .foregroundColor(titleColor)
                    
                    Text(subtitle)
                        .font(DesignSystem.Typography.smart(12, language: language))
                        .foregroundColor(DesignSystem.Colors.mutedText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.mutedText.opacity(0.7))
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var iconColor: Color {
        role == .destructive ? .red : DesignSystem.Colors.mutedText
    }
    
    private var titleColor: Color {
        role == .destructive ? .red : DesignSystem.Colors.primaryText
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let language: CoreModels.VerseLanguage
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DesignSystem.Colors.mutedText)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.smart(14, weight: .semibold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.smart(12, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DesignSystem.Colors.accent)
        }
        .padding(.vertical, 16)
    }
}

struct SettingsAppearanceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var selectedMode: AppAppearanceMode
    let language: CoreModels.VerseLanguage
    let onChange: (AppAppearanceMode) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsRowHeader(
                icon: icon,
                title: title,
                subtitle: subtitle,
                language: language
            )
            
            HStack(spacing: 8) {
                ForEach(AppAppearanceMode.allCases, id: \.rawValue) { mode in
                    Button {
                        selectedMode = mode
                        onChange(mode)
                    } label: {
                        Text(mode.localizedTitle(for: language))
                            .font(DesignSystem.Typography.smart(13, weight: .semibold, language: language))
                            .foregroundColor(selectedMode == mode ? .white : DesignSystem.Colors.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                                    .fill(selectedMode == mode ? DesignSystem.Colors.accent : DesignSystem.Colors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                                    .stroke(selectedMode == mode ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 16)
    }
}

struct SettingsFontSizeRow: View {
    @Binding var fontSizeIndex: Int
    let language: CoreModels.VerseLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.mutedText)
                    .frame(width: 24)
                
                Text(title)
                    .font(DesignSystem.Typography.smart(14, weight: .semibold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    Button {
                        fontSizeIndex = index
                    } label: {
                        Text(["S", "M", "L", "XL"][index])
                            .font(.system(size: 13 + CGFloat(index * 2), weight: .semibold))
                            .foregroundColor(fontSizeIndex == index ? .white : DesignSystem.Colors.secondaryText)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                                    .fill(fontSizeIndex == index ? DesignSystem.Colors.accent : DesignSystem.Colors.cardBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                                    .stroke(fontSizeIndex == index ? Color.clear : DesignSystem.Colors.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            
            HStack {
                Text(smallLabel)
                Spacer()
                Text(extraLargeLabel)
            }
            .font(DesignSystem.Typography.smart(11, language: language))
            .foregroundColor(DesignSystem.Colors.mutedText)
        }
        .padding(.vertical, 16)
    }
    
    private var title: String {
        switch language {
        case .chinese: return "字体大小"
        case .english: return "Font Size"
        case .korean: return "글자 크기"
        }
    }
    
    private var smallLabel: String {
        switch language {
        case .chinese: return "小"
        case .english: return "Small"
        case .korean: return "작게"
        }
    }
    
    private var extraLargeLabel: String {
        switch language {
        case .chinese: return "超大"
        case .english: return "Extra Large"
        case .korean: return "아주 크게"
        }
    }
}

struct SettingsRadioButton: View {
    let title: String
    let isSelected: Bool
    let language: CoreModels.VerseLanguage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.mutedText)
                
                Text(title)
                    .font(DesignSystem.Typography.smart(14, weight: .semibold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .fill(isSelected ? DesignSystem.Colors.cardBackground : DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                            .stroke(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.divider, lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.divider)
            .frame(height: 1)
    }
}

struct SettingsAccountRow: View {
    @StateObject private var authManager = AuthManager.shared
    let language: CoreModels.VerseLanguage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(DesignSystem.Colors.cardBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: accountIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.accentDark)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(accountName)
                        .font(DesignSystem.Typography.smart(14, weight: .semibold, language: language))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text(accountSubtitle)
                        .font(DesignSystem.Typography.smart(12, language: language))
                        .foregroundColor(DesignSystem.Colors.mutedText)
                }
                
                Spacer()
                
                if !authManager.authState.isSignedIn {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.mutedText.opacity(0.7))
                }
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var accountIcon: String {
        switch authManager.authState {
        case .signedIn:
            return "person.fill"
        case .pending:
            return "clock.fill"
        default:
            return "person"
        }
    }
    
    private var accountName: String {
        if case .signedIn(let profile) = authManager.authState {
            return profile.name
        }
        
        if authManager.authState.isPending {
            switch language {
            case .chinese: return "账户审核中"
            case .english: return "Account Pending"
            case .korean: return "계정 승인 대기 중"
            }
        }
        
        switch language {
        case .chinese: return "未登录"
        case .english: return "Guest"
        case .korean: return "게스트"
        }
    }
    
    private var accountSubtitle: String {
        if case .signedIn(let profile) = authManager.authState {
            return profile.email
        }
        
        if authManager.authState.isPending {
            switch language {
            case .chinese: return "管理员通过后即可访问会员通讯"
            case .english: return "Member communication unlocks after admin approval"
            case .korean: return "관리자 승인 후 회원 소식을 볼 수 있습니다"
            }
        }
        
        switch language {
        case .chinese: return "登录后同步分堂通讯"
        case .english: return "Sign in to sync church access"
        case .korean: return "로그인 후 교회 접근 권한 동기화"
        }
    }
}

struct SettingsBranchAccessRows: View {
    let profile: UserProfile
    let language: CoreModels.VerseLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRowHeader(
                icon: "building.2",
                title: title,
                subtitle: subtitle,
                language: language
            )

            VStack(spacing: 8) {
                SettingsProfileInfoLine(
                    title: branchTitle,
                    value: profile.displayBranchName(for: language),
                    language: language
                )

                SettingsProfileInfoLine(
                    title: regionTitle,
                    value: profile.displayRegionName(for: language),
                    language: language
                )

                SettingsProfileInfoLine(
                    title: roleTitle,
                    value: profile.displayAccessRole(for: language),
                    language: language
                )

                SettingsProfileInfoLine(
                    title: statusTitle,
                    value: profile.displayMembershipStatus(for: language),
                    language: language
                )
            }
        }
        .padding(.vertical, 16)
    }

    private var title: String {
        switch language {
        case .chinese: return "分堂与权限"
        case .english: return "Branch & Access"
        case .korean: return "지교회 및 권한"
        }
    }

    private var subtitle: String {
        switch language {
        case .chinese: return "由管理员在 Firebase 中维护"
        case .english: return "Managed by admins in Firebase"
        case .korean: return "Firebase에서 관리자가 관리합니다"
        }
    }

    private var branchTitle: String {
        switch language {
        case .chinese: return "所属分堂"
        case .english: return "Branch"
        case .korean: return "소속 지교회"
        }
    }

    private var regionTitle: String {
        switch language {
        case .chinese: return "区域"
        case .english: return "Region"
        case .korean: return "지역"
        }
    }

    private var roleTitle: String {
        switch language {
        case .chinese: return "权限"
        case .english: return "Access"
        case .korean: return "권한"
        }
    }

    private var statusTitle: String {
        switch language {
        case .chinese: return "审核状态"
        case .english: return "Review Status"
        case .korean: return "승인 상태"
        }
    }
}

private struct SettingsProfileInfoLine: View {
    let title: String
    let value: String
    let language: CoreModels.VerseLanguage

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(DesignSystem.Typography.smart(12, weight: .medium, language: language))
                .foregroundColor(DesignSystem.Colors.mutedText)
                .frame(width: 84, alignment: .leading)

            Text(value)
                .font(DesignSystem.Typography.smart(13, weight: .semibold, language: language))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

struct SettingsRowHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    let language: CoreModels.VerseLanguage
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DesignSystem.Colors.mutedText)
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.smart(14, weight: .semibold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.smart(12, language: language))
                    .foregroundColor(DesignSystem.Colors.mutedText)
            }
            
            Spacer()
        }
    }
}

struct LanguageButton: View {
    let title: String
    let language: CoreModels.VerseLanguage
    let selectedLanguage: CoreModels.VerseLanguage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selectedLanguage == language ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(selectedLanguage == language ? DesignSystem.Colors.accent : DesignSystem.Colors.mutedText)
                
                Text(title)
                    .font(DesignSystem.Typography.system(14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .fill(selectedLanguage == language ? DesignSystem.Colors.cardBackground : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                            .stroke(selectedLanguage == language ? DesignSystem.Colors.accent : DesignSystem.Colors.divider, lineWidth: selectedLanguage == language ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
