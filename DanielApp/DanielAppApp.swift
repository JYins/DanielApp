//
//  DanielAppApp.swift
//  DanielApp
//
//  Created by 殷实 on 2025-03-29.
//

import SwiftUI
import CoreText
import Firebase
import FirebaseAuth
import FirebaseFirestore
import UserNotifications
import GoogleSignIn

@main
struct DanielAppApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate: AppDelegate
    @Environment(\.scenePhase) var scenePhase
    
    // 添加UserDefaults属性来保存上次刷新日期
    private let defaults = UserDefaults.standard
    private let lastRefreshDateKey = "lastDailyVerseRefreshDate"
    
    init() {
        // 配置全局UI样式
        configureGlobalAppearance()
        
        // 设置应用通知
        setupNotifications()
        
        // 配置Firebase
        FirebaseApp.configure()
        configureFirebaseEmulatorsIfNeeded()
        
        // 注册自定义字体
        registerCustomFonts()
        
        // 初始化应用数据
        initializeAppData()
        
        // 初始化午夜更新管理器
        _ = MidnightUpdateManager.shared
        
        // 初始化背景时间段管理器
        _ = BackgroundTimePeriodManager.shared
        
        print("✅ DanielApp主应用初始化完成")
    }

    private func configureFirebaseEmulatorsIfNeeded() {
        let environment = ProcessInfo.processInfo.environment
        let arguments = ProcessInfo.processInfo.arguments
        let shouldUseEmulator = environment["USE_FIREBASE_EMULATOR"] == "1" || arguments.contains("-UseFirebaseEmulator")

        guard shouldUseEmulator else {
            return
        }

        let host = environment["FIREBASE_EMULATOR_HOST"] ?? "127.0.0.1"
        let firestorePort = Int(environment["FIRESTORE_EMULATOR_PORT"] ?? "8080") ?? 8080
        let authPort = Int(environment["FIREBASE_AUTH_EMULATOR_PORT"] ?? "9099") ?? 9099

        Auth.auth().useEmulator(withHost: host, port: authPort)

        let settings = Firestore.firestore().settings
        settings.host = "\(host):\(firestorePort)"
        settings.isSSLEnabled = false
        settings.isPersistenceEnabled = false
        Firestore.firestore().settings = settings

        print("🧪 Firebase emulator enabled: Firestore \(host):\(firestorePort), Auth \(host):\(authPort)")
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(appState.preferredColorScheme)
                .dynamicTypeSize(appState.dynamicTypeSize)
                .onOpenURL { url in
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }

                    // 处理深层链接
                    if url.isVerseDeepLink {
                        appState.handleWidgetURL(url)
                    }
                }
                .onAppear {
                    // 优化启动时的初始化流程
                    initializeAppData()
                    
                    // 注册应用激活时的处理
                    NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                        self.handleAppActivation()
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // 应用变为活动状态时检查是否需要刷新
                checkAndRefreshDailyVerse()
            }
        }
    }
    
    // 注册自定义字体函数
    private func registerCustomFonts() {
        // 宋体
        if let fontURL = Bundle.main.url(forResource: "爱点风雅黑长体(商用免费)", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            print("成功注册宋体字体")
        } else {
            print("未找到宋体字体文件")
        }
        
        // 韩文字体
        if let fontURL = Bundle.main.url(forResource: "GowunDodum-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            print("成功注册韩文字体")
        } else {
            print("未找到韩文字体文件")
        }
    }
    
    // 优化的应用数据初始化
    private func initializeAppData() {
        print("🚀 应用启动 - 初始化数据...")
        
        // 异步初始化，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async {
            // 立即加载并缓存当前经文
            if let currentVerse = VerseDataService.shared.getCurrentVerseToDisplay() {
                print("应用启动：已加载当前经文 - \(currentVerse.reference)")
            } else {
                print("应用启动：无法加载当前经文")
            }
        }
    }
    
    // 优化的应用激活处理
    private func handleAppActivation() {
        print("📱 应用激活 - 检查数据更新...")
        
        // 使用DispatchQueue延迟执行，实现防抖动效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.performAppActivationTasks()
        }
    }
    
    private func performAppActivationTasks() {
        // 每次应用被激活时，确保数据是最新的
        if let currentVerse = VerseDataService.shared.getCurrentVerseToDisplay() {
            print("应用激活：已更新当前经文 - \(currentVerse.reference)")
        }
    }
    
    // 检查并刷新每日经文
    private func checkAndRefreshDailyVerse() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        print("=== 开始检查每日经文刷新 ===")
        print("📅 今天日期: \(today)")
        
        // 获取当前设置
        let updateMode = VerseDataService.shared.getUpdateMode()
        let isFixed = VerseDataService.shared.isVerseFixed()
        let currentRef = VerseDataService.shared.getCurrentVerseReference()
        
        print("📋 当前设置 - 更新模式: \(updateMode), 固定经文: \(isFixed ? "是" : "否")")
        print("📄 当前引用: \(currentRef ?? "无")")
        
        // 只有在自动模式且非固定时才需要检查日期刷新
        if updateMode != "automatic" || isFixed {
            print("ℹ️ 当前模式不需要日期刷新 - \(isFixed ? "固定模式" : "手动模式")")
            print("=== 检查完成：无需刷新 ===\n")
            return
        }
        
        // 获取上次刷新日期
        let lastRefreshDate: Date
        if let savedDate = defaults.object(forKey: lastRefreshDateKey) as? Date {
            lastRefreshDate = calendar.startOfDay(for: savedDate)
            print("📅 上次刷新日期: \(lastRefreshDate)")
        } else {
            // 首次运行，设置为前一天以确保首次刷新
            lastRefreshDate = calendar.date(byAdding: .day, value: -1, to: today)!
            print("📅 首次运行，设置上次刷新日期为: \(lastRefreshDate)")
        }
        
        // 计算日期间隔
        let components = calendar.dateComponents([.day], from: lastRefreshDate, to: today)
        let daysDifference = components.day ?? 0
        print("📊 日期间隔: \(daysDifference) 天")
        
        // 如果是新的一天，执行刷新
        if daysDifference > 0 {
            print("🌅 检测到新的一天，开始刷新每日经文...")
            
            // === 第一步：清除用户切换状态 ===
            if currentRef != nil {
                print("🧹 清除用户昨日切换的经文引用: \(currentRef!)")
                VerseDataService.shared.setCurrentVerseReference(nil)
            } else {
                print("📝 没有用户切换的引用需要清除")
            }
            
            // === 第二步：强制清除所有缓存 ===
            print("🧹 清除经文数据缓存...")
            VerseDataService.shared.clearCache()
            
            // === 第三步：强制重新获取今日经文 ===
            print("📆 强制获取今日经文...")
            if let todayVerse = VerseDataService.shared.getVerseForToday() {
                print("✅ 成功获取今日经文: \(todayVerse.reference)")
                
                // 立即缓存今日经文
                VerseDataService.shared.cacheCurrentVerse(todayVerse)
                print("💾 已缓存今日经文")
            } else {
                print("❌ 无法获取今日经文")
            }
            
            // === 第四步：更新刷新日期记录 ===
            defaults.set(today, forKey: lastRefreshDateKey)
            defaults.synchronize()
            print("📝 已更新刷新日期为今天: \(today)")
            
            print("✅ 每日经文刷新过程完成")
        } else {
            print("ℹ️ 今天已经刷新过，无需重复刷新")
            
            // 即使不需要刷新，也要确保数据是最新的
            if let currentVerse = VerseDataService.shared.getCurrentVerseToDisplay() {
                print("📋 当前显示经文: \(currentVerse.reference)")
            }
        }
        
        print("=== 检查每日经文刷新完成 ===\n")
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        print("📱 Scene 变为活跃状态")
        
        // 应用回到前台时，检查和刷新每日经文
        checkAndRefreshDailyVerse()
        
        // 通知午夜更新管理器应用回到前台
        MidnightUpdateManager.shared.applicationWillEnterForeground()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        print("📱 Scene 即将失去活跃状态")
        // 通知午夜更新管理器应用即将进入后台
        MidnightUpdateManager.shared.applicationDidEnterBackground()
    }
    
    // 配置全局UI样式
    private func configureGlobalAppearance() {
        print("🎨 配置全局UI样式")
        // 在这里添加全局UI配置代码
    }
    
    // 设置应用通知
    private func setupNotifications() {
        print("🔔 设置应用通知")
        // 在这里添加通知设置代码
    }
}

// 应用状态管理
class AppState: ObservableObject {
    @Published var selectedVerseReference: String?
    @Published var selectedTab: Int = 0
    @Published var selectedLanguage: CoreModels.VerseLanguage = .chinese
    @Published var needsShowSettings: Bool = false
    @Published var needsRefreshVerseStatus: Bool = false
    @Published var fontSizeIndex: Int = AppPreferences.getFontSizeIndex()
    @Published var notificationsEnabled: Bool = AppPreferences.getNotificationsEnabled()
    @Published var appearanceMode: AppAppearanceMode = AppPreferences.getAppearanceMode()
    
    init(selectedVerseReference: String? = nil) {
        self.selectedVerseReference = selectedVerseReference
        
        // 初始化语言设置
        self.selectedLanguage = VerseDataService.shared.getSelectedLanguage()
    }
    
    var fontScale: CGFloat {
        AppPreferences.fontScale(for: fontSizeIndex)
    }
    
    var dynamicTypeSize: DynamicTypeSize {
        switch fontSizeIndex {
        case 0: return .small
        case 2: return .large
        case 3: return .xLarge
        default: return .medium
        }
    }
    
    var preferredColorScheme: ColorScheme? {
        appearanceMode.preferredColorScheme
    }
    
    func updateFontSizeIndex(_ index: Int) {
        let clampedIndex = min(max(index, 0), 3)
        fontSizeIndex = clampedIndex
        AppPreferences.setFontSizeIndex(clampedIndex)
    }
    
    func updateNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled
        AppPreferences.setNotificationsEnabled(enabled)
    }
    
    func updateAppearanceMode(_ mode: AppAppearanceMode) {
        appearanceMode = mode
        AppPreferences.setAppearanceMode(mode)
    }
    
    func handleWidgetURL(_ url: URL) {
        if url.isVerseDeepLink, let verseId = url.verseId {
            selectedVerseReference = verseId
        }
    }
    
    // 更新应用语言 - 这将触发所有使用此状态的视图更新
    func updateLanguage(_ language: CoreModels.VerseLanguage) {
        // 更新内存中的语言设置
        self.selectedLanguage = language
        
        // 同时更新持久化存储的语言设置
        VerseDataService.shared.setSelectedLanguage(language)
        
        print("应用语言已更新为: \(language.description)")
    }
    
    func cycleLanguage() {
        switch selectedLanguage {
        case .chinese:
            updateLanguage(.english)
        case .english:
            updateLanguage(.korean)
        case .korean:
            updateLanguage(.chinese)
        }
    }
}

enum AppAppearanceMode: String, CaseIterable {
    case system
    case light
    case dark
    
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    func localizedTitle(for language: CoreModels.VerseLanguage) -> String {
        switch self {
        case .system:
            switch language {
            case .chinese: return "跟随系统"
            case .english: return "System"
            case .korean: return "시스템"
            }
        case .light:
            switch language {
            case .chinese: return "浅色"
            case .english: return "Light"
            case .korean: return "라이트"
            }
        case .dark:
            switch language {
            case .chinese: return "深色"
            case .english: return "Dark"
            case .korean: return "다크"
            }
        }
    }
}

enum AppPreferences {
    private enum Keys {
        static let fontSizeIndex = "daniel.fontSizeIndex"
        static let notificationsEnabled = "daniel.notificationsEnabled"
        static let darkModeEnabled = "daniel.darkModeEnabled"
        static let appearanceMode = "daniel.appearanceMode"
    }
    
    private static var defaults: UserDefaults {
        VerseDataService.shared.getSharedDefaults()
    }
    
    static func getFontSizeIndex() -> Int {
        if defaults.object(forKey: Keys.fontSizeIndex) == nil {
            return 1
        }
        return min(max(defaults.integer(forKey: Keys.fontSizeIndex), 0), 3)
    }
    
    static func setFontSizeIndex(_ index: Int) {
        defaults.set(min(max(index, 0), 3), forKey: Keys.fontSizeIndex)
        defaults.synchronize()
    }
    
    static func getNotificationsEnabled() -> Bool {
        if defaults.object(forKey: Keys.notificationsEnabled) == nil {
            return true
        }
        return defaults.bool(forKey: Keys.notificationsEnabled)
    }
    
    static func setNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.notificationsEnabled)
        defaults.synchronize()
    }
    
    static func getAppearanceMode() -> AppAppearanceMode {
        if let rawValue = defaults.string(forKey: Keys.appearanceMode),
           let mode = AppAppearanceMode(rawValue: rawValue) {
            return mode
        }
        
        if defaults.object(forKey: Keys.darkModeEnabled) != nil {
            return defaults.bool(forKey: Keys.darkModeEnabled) ? .dark : .light
        }
        
        return .system
    }
    
    static func setAppearanceMode(_ mode: AppAppearanceMode) {
        defaults.set(mode.rawValue, forKey: Keys.appearanceMode)
        defaults.synchronize()
    }
    
    static func fontScale(for index: Int) -> CGFloat {
        switch min(max(index, 0), 3) {
        case 0: return 0.92
        case 2: return 1.12
        case 3: return 1.25
        default: return 1.0
        }
    }
}

// URL扩展
extension URL {
    var isVerseDeepLink: Bool {
        return absoluteString.hasPrefix("danielapp://verse/")
    }
    
    var verseId: String? {
        guard isVerseDeepLink,
              let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let path = components.path.split(separator: "/").last else {
            return nil
        }
        return String(path)
    }
}
