import Foundation
import SwiftUI
import FirebaseAuth

// 本地化文本系统 - 支持中英韩三语
struct LocalizedText {
    // MARK: - 共享单例
    static let shared = LocalizedText()
    
    // MARK: - 通用文本
    enum Common: String {
        case appTitle
        case dailyVerse
        case settings
        case connect
        case versionInfo
        case copyright
        case bibleVersionInfo
        case wordCardsTab // New key for the tab title
        case newsletterTab // Newsletter tab title
        case praiseTab // Praise tab title
        
        // 获取对应语言的文本
        func text(for language: CoreModels.VerseLanguage) -> String {
            switch self {
            case .appTitle:
                switch language {
                case .chinese: return "但以理和他的朋友们"
                case .english: return "Daniel and his Friends"
                case .korean: return "다니엘과 친구들"
                }
            case .dailyVerse:
                switch language {
                case .chinese: return "每日经文"
                case .english: return "Daily Verse"
                case .korean: return "일일 성경 구절"
                }
            case .settings:
                switch language {
                case .chinese: return "设置"
                case .english: return "Settings"
                case .korean: return "설정"
                }
            case .connect:
                switch language {
                case .chinese: return "连接"
                case .english: return "Connect"
                case .korean: return "연결하기"
                }
            case .versionInfo:
                switch language {
                case .chinese: return "版本信息"
                case .english: return "Version Info"
                case .korean: return "버전 정보"
                }
            case .copyright:
                switch language {
                case .chinese: return "© 2025 Daniel & his friends"
                case .english: return "© 2025 Daniel & his friends"
                case .korean: return "© 2025 다니엘과 그의 친구들"
                }
            case .bibleVersionInfo:
                switch language {
                case .chinese: return "我们所使用的圣经版本皆为公开领域版本，仅供个人灵修目的非商用"
                case .english: return "The Bible versions we use are all in the public domain, for personal devotional purposes only and not for commercial use"
                case .korean: return "우리가 사용하는 성경 버전은 모두 공개 도메인 버전으로, 개인 경건 목적으로만 사용되며 상업적 사용은 금지됩니다"
                }
            case .wordCardsTab:
                switch language {
                case .chinese: return "话语卡片"
                case .english: return "Words of Life" // Refined translation
                case .korean: return "생명의 말씀" // Refined translation (Saengmyeong-ui Malsseum)
                }
            case .newsletterTab:
                switch language {
                case .chinese: return "教会通讯"
                case .english: return "Newsletter"
                case .korean: return "교회 소식지"
                }
            case .praiseTab:
                switch language {
                case .chinese: return "赞美响起"
                case .english: return "Praise Resounds"
                case .korean: return "찬양이 울려퍼져"
                }
            }
        }
    }
    
    // MARK: - 设置页面文本
    enum Settings: String {
        case pushSettings
        case updateMode
        case autoUpdate
        case manualUpdate
        case manualSelect
        case displayLanguage
        case languageHint
        case selectVerse
        case setVerse
        case currentFixedVerse
        case unfixVerse
        case autoUpdateMode
        case bookPlaceholder
        case chapterPlaceholder
        case versePlaceholder
        
        // 获取对应语言的文本
        func text(for language: CoreModels.VerseLanguage) -> String {
            switch self {
            case .pushSettings:
                switch language {
                case .chinese: return "推送设置"
                case .english: return "Notification Settings"
                case .korean: return "알림 설정"
                }
            case .updateMode:
                switch language {
                case .chinese: return "更新模式"
                case .english: return "Update Mode"
                case .korean: return "업데이트 모드"
                }
            case .autoUpdate:
                switch language {
                case .chinese: return "自动每日更新"
                case .english: return "Auto Daily Update"
                case .korean: return "자동 일일 업데이트"
                }
            case .manualUpdate:
                switch language {
                case .chinese: return "手动更新"
                case .english: return "Manual Update"
                case .korean: return "수동 업데이트"
                }
            case .manualSelect:
                switch language {
                case .chinese: return "手动选择"
                case .english: return "Manual Selection"
                case .korean: return "수동 선택"
                }
            case .displayLanguage:
                switch language {
                case .chinese: return "显示语言"
                case .english: return "Display Language"
                case .korean: return "표시 언어"
                }
            case .languageHint:
                switch language {
                case .chinese: return "切换语言将同时更新主应用和小组件"
                case .english: return "Changing language will update both app and widget"
                case .korean: return "언어를 변경하면 앱과 위젯이 모두 업데이트됩니다"
                }
            case .selectVerse:
                switch language {
                case .chinese: return "选择经文"
                case .english: return "Select Verse"
                case .korean: return "구절 선택"
                }
            case .setVerse:
                switch language {
                case .chinese: return "设置经文"
                case .english: return "Set Verse"
                case .korean: return "구절 설정"
                }
            case .currentFixedVerse:
                switch language {
                case .chinese: return "当前已固定经文:"
                case .english: return "Current Fixed Verse:"
                case .korean: return "현재 고정된 구절:"
                }
            case .unfixVerse:
                switch language {
                case .chinese: return "取消固定"
                case .english: return "Unfix Verse"
                case .korean: return "고정 해제"
                }
            case .autoUpdateMode:
                switch language {
                case .chinese: return "自动每日更新模式"
                case .english: return "Auto Daily Update Mode"
                case .korean: return "자동 일일 업데이트 모드"
                }
            case .bookPlaceholder:
                switch language {
                case .chinese: return "选择书卷"
                case .english: return "Select Book"
                case .korean: return "책 선택"
                }
            case .chapterPlaceholder:
                switch language {
                case .chinese: return "选择章"
                case .english: return "Select Chapter"
                case .korean: return "장 선택"
                }
            case .versePlaceholder:
                switch language {
                case .chinese: return "经文引用 (例如: John 3:16)"
                case .english: return "Verse Reference (e.g. John 3:16)"
                case .korean: return "구절 참조 (예: John 3:16)"
                }
            }
        }
    }
    
    // MARK: - 每日经文页面文本
    enum VerseView: String {
        case dailyVerse
        case switchVerse
        case setAsFixed
        case unfixVerse
        case modifyInSettings
        case currentStatus
        case autoUpdateStatus
        case fixedVerseStatus
        case manualSelectStatus
        
        // 获取对应语言的文本
        func text(for language: CoreModels.VerseLanguage) -> String {
            switch self {
            case .dailyVerse:
                switch language {
                case .chinese: return "每日经文"
                case .english: return "Daily Verse"
                case .korean: return "일일 성경 구절"
                }
            case .switchVerse:
                switch language {
                case .chinese: return "切换经文"
                case .english: return "Switch Verse"
                case .korean: return "구절 변경"
                }
            case .setAsFixed:
                switch language {
                case .chinese: return "设置为固定经文"
                case .english: return "Set as Fixed Verse"
                case .korean: return "고정 구절로 설정"
                }
            case .unfixVerse:
                switch language {
                case .chinese: return "取消固定"
                case .english: return "Unfix Verse"
                case .korean: return "고정 해제"
                }
            case .modifyInSettings:
                switch language {
                case .chinese: return "在设置中修改经文"
                case .english: return "Modify Verse in Settings"
                case .korean: return "설정에서 구절 수정"
                }
            case .currentStatus:
                switch language {
                case .chinese: return "当前状态："
                case .english: return "Current Status: "
                case .korean: return "현재 상태: "
                }
            case .autoUpdateStatus:
                switch language {
                case .chinese: return "自动每日更新"
                case .english: return "Auto Daily Update"
                case .korean: return "자동 일일 업데이트"
                }
            case .fixedVerseStatus:
                switch language {
                case .chinese: return "自动模式 - 已固定经文"
                case .english: return "Auto Mode - Fixed Verse"
                case .korean: return "자동 모드 - 고정된 구절"
                }
            case .manualSelectStatus:
                switch language {
                case .chinese: return "手动选择经文"
                case .english: return "Manual Verse Selection"
                case .korean: return "수동 구절 선택"
                }
            }
        }
    }

    // MARK: - 话语卡片页面文本
    enum WordCardGallery: String {
        case navTitle
        case categoryAll
        case categoryGrace
        case categoryEncouragement
        case categoryWisdom

        // 获取对应语言的文本
        func text(for language: CoreModels.VerseLanguage) -> String {
            switch self {
            case .navTitle: // Use refined translations, same as tab title
                switch language {
                case .chinese: return "话语卡片"
                case .english: return "Words of Life" // Refined translation
                case .korean: return "생명의 말씀" // Refined translation
                }
            case .categoryAll:
                switch language {
                case .chinese: return "全部"
                case .english: return "All"
                case .korean: return "전체"
                }
            case .categoryGrace:
                switch language {
                case .chinese: return "恩典"
                case .english: return "Grace"
                case .korean: return "은혜"
                }
            case .categoryEncouragement:
                switch language {
                case .chinese: return "鼓励"
                case .english: return "Encouragement"
                case .korean: return "격려"
                }
            case .categoryWisdom:
                switch language {
                case .chinese: return "智慧"
                case .english: return "Wisdom"
                case .korean: return "지혜"
                }
            }
        }
    }
    
    // MARK: - 连接页面文本
    enum ConnectView: String {
        case connect
        case shareApp
        case contactUs
        
        // 获取对应语言的文本
        func text(for language: CoreModels.VerseLanguage) -> String {
            switch self {
            case .connect:
                switch language {
                case .chinese: return "连接"
                case .english: return "Connect"
                case .korean: return "연결하기"
                }
            case .shareApp:
                switch language {
                case .chinese: return "分享应用"
                case .english: return "Share App"
                case .korean: return "앱 공유하기"
                }
            case .contactUs:
                switch language {
                case .chinese: return "联系我们"
                case .english: return "Contact Us"
                case .korean: return "문의하기"
                }
            }
        }
    }
    
    // MARK: - Newsletter页面文本
    enum NewsletterView: String {
        case title
        case loginPrompt
        case loginButton
        case userMenuTitle
        case userInfo
        case logout
        case cancel
        case defaultUserName
        
        // 获取对应语言的文本
        func text(for language: CoreModels.VerseLanguage) -> String {
            switch self {
            case .title:
                switch language {
                case .chinese: return "教会Newsletter"
                case .english: return "Church Newsletter"
                case .korean: return "교회 뉴스레터"
                }
            case .loginPrompt:
                switch language {
                case .chinese: return "请登录以查看教会每月Newsletter"
                case .english: return "Please login to view the church monthly newsletter"
                case .korean: return "교회 월간 뉴스레터를 보려면 로그인하세요"
                }
            case .loginButton:
                switch language {
                case .chinese: return "立即登录"
                case .english: return "Login Now"
                case .korean: return "지금 로그인"
                }
            case .userMenuTitle:
                switch language {
                case .chinese: return "用户菜单"
                case .english: return "User Menu"
                case .korean: return "사용자 메뉴"
                }
            case .userInfo:
                switch language {
                case .chinese: return "当前用户信息"
                case .english: return "Current User Information"
                case .korean: return "현재 사용자 정보"
                }
            case .logout:
                switch language {
                case .chinese: return "退出登录"
                case .english: return "Logout"
                case .korean: return "로그아웃"
                }
            case .cancel:
                switch language {
                case .chinese: return "取消"
                case .english: return "Cancel"
                case .korean: return "취소"
                }
            case .defaultUserName:
                switch language {
                case .chinese: return "用户"
                case .english: return "User"
                case .korean: return "사용자"
                }
            }
        }
    }
    
    // MARK: - 赞美页面文本
    enum Praise: String {
        case subtitle
        case comingSoon
        case description
        case features
        
        // 获取对应语言的文本
        func text(for language: CoreModels.VerseLanguage) -> String {
            switch self {
            case .subtitle:
                switch language {
                case .chinese: return "让心灵响起赞美的声音"
                case .english: return "Let your heart echo with praise"
                case .korean: return "마음에서 찬양의 소리가 울려 퍼지게 하세요"
                }
            case .comingSoon:
                switch language {
                case .chinese: return "即将推出"
                case .english: return "Coming Soon"
                case .korean: return "곧 출시 예정"
                }
            case .description:
                switch language {
                case .chinese: return "我们正在精心准备丰富的敬拜音乐资源，包括精选敬拜歌曲、每日诗歌推荐等功能，敬请期待！"
                case .english: return "We are carefully preparing rich worship music resources, including curated worship songs, daily hymn recommendations, and more features. Stay tuned!"
                case .korean: return "엄선된 예배 음악, 매일의 찬송가 추천 등의 기능을 포함한 풍부한 예배 음악 리소스를 신중하게 준비하고 있습니다. 많은 기대 부탁드립니다!"
                }
            case .features:
                switch language {
                case .chinese: return "即将推出的功能"
                case .english: return "Upcoming Features"
                case .korean: return "출시 예정 기능"
                }
            }
        }
    }
}

// 扩展用于文本获取的属性包装器
// 使用方式: @LocalizedString(\.settings.displayLanguage) var displayLanguageText
struct LocalizedString<T>: DynamicProperty {
    @EnvironmentObject var appState: AppState
    
    private let keyPath: KeyPath<LocalizedStringKeys, (CoreModels.VerseLanguage) -> String>
    
    init(_ keyPath: KeyPath<LocalizedStringKeys, (CoreModels.VerseLanguage) -> String>) {
        self.keyPath = keyPath
    }
    
    var wrappedValue: String {
        let stringProvider = LocalizedStringKeys()[keyPath: keyPath]
        return stringProvider(appState.selectedLanguage)
    }
}

// 本地化字符串键路径
struct LocalizedStringKeys {
    var common: CommonKeys { CommonKeys() }
    var settings: SettingsKeys { SettingsKeys() }
    var verse: VerseKeys { VerseKeys() }
    var wordCardGallery: WordCardGalleryKeys { WordCardGalleryKeys() } // New keys struct
    var connect: ConnectKeys { ConnectKeys() }
    var newsletter: NewsletterKeys { NewsletterKeys() } // Newsletter keys struct
    var praise: PraiseKeys { PraiseKeys() } // Praise keys struct
    
    struct CommonKeys {
        var appTitle: (CoreModels.VerseLanguage) -> String { { LocalizedText.Common.appTitle.text(for: $0) } }
        var dailyVerse: (CoreModels.VerseLanguage) -> String { { LocalizedText.Common.dailyVerse.text(for: $0) } }
        var settings: (CoreModels.VerseLanguage) -> String { { LocalizedText.Common.settings.text(for: $0) } }
        var connect: (CoreModels.VerseLanguage) -> String { { LocalizedText.Common.connect.text(for: $0) } }
        var versionInfo: (CoreModels.VerseLanguage) -> String { { LocalizedText.Common.versionInfo.text(for: $0) } }
        var copyright: (CoreModels.VerseLanguage) -> String { { LocalizedText.Common.copyright.text(for: $0) } }
        var bibleVersionInfo: (CoreModels.VerseLanguage) -> String { { LocalizedText.Common.bibleVersionInfo.text(for: $0) } }
        var wordCardsTab: (CoreModels.VerseLanguage) -> String { { LocalizedText.Common.wordCardsTab.text(for: $0) } } // New key path
        var newsletterTab: (CoreModels.VerseLanguage) -> String { { LocalizedText.Common.newsletterTab.text(for: $0) } } // Newsletter tab key path
        var praiseTab: (CoreModels.VerseLanguage) -> String { { LocalizedText.Common.praiseTab.text(for: $0) } } // Praise tab key path
    }
    
    struct SettingsKeys {
        var pushSettings: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.pushSettings.text(for: $0) } }
        var updateMode: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.updateMode.text(for: $0) } }
        var autoUpdate: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.autoUpdate.text(for: $0) } }
        var manualSelect: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.manualSelect.text(for: $0) } }
        var displayLanguage: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.displayLanguage.text(for: $0) } }
        var languageHint: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.languageHint.text(for: $0) } }
        var selectVerse: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.selectVerse.text(for: $0) } }
        var setVerse: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.setVerse.text(for: $0) } }
        var currentFixedVerse: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.currentFixedVerse.text(for: $0) } }
        var unfixVerse: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.unfixVerse.text(for: $0) } }
        var autoUpdateMode: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.autoUpdateMode.text(for: $0) } }
        var bookPlaceholder: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.bookPlaceholder.text(for: $0) } }
        var versePlaceholder: (CoreModels.VerseLanguage) -> String { { LocalizedText.Settings.versePlaceholder.text(for: $0) } }
    }
    
    struct VerseKeys {
        var dailyVerse: (CoreModels.VerseLanguage) -> String { { LocalizedText.VerseView.dailyVerse.text(for: $0) } }
        var switchVerse: (CoreModels.VerseLanguage) -> String { { LocalizedText.VerseView.switchVerse.text(for: $0) } }
        var setAsFixed: (CoreModels.VerseLanguage) -> String { { LocalizedText.VerseView.setAsFixed.text(for: $0) } }
        var unfixVerse: (CoreModels.VerseLanguage) -> String { { LocalizedText.VerseView.unfixVerse.text(for: $0) } }
        var modifyInSettings: (CoreModels.VerseLanguage) -> String { { LocalizedText.VerseView.modifyInSettings.text(for: $0) } }
        var currentStatus: (CoreModels.VerseLanguage) -> String { { LocalizedText.VerseView.currentStatus.text(for: $0) } }
        var autoUpdateStatus: (CoreModels.VerseLanguage) -> String { { LocalizedText.VerseView.autoUpdateStatus.text(for: $0) } }
        var fixedVerseStatus: (CoreModels.VerseLanguage) -> String { { LocalizedText.VerseView.fixedVerseStatus.text(for: $0) } }
        var manualSelectStatus: (CoreModels.VerseLanguage) -> String { { LocalizedText.VerseView.manualSelectStatus.text(for: $0) } }
    }

    struct WordCardGalleryKeys { // New keys struct definition
        var navTitle: (CoreModels.VerseLanguage) -> String { { LocalizedText.WordCardGallery.navTitle.text(for: $0) } }
        var categoryAll: (CoreModels.VerseLanguage) -> String { { LocalizedText.WordCardGallery.categoryAll.text(for: $0) } }
        var categoryGrace: (CoreModels.VerseLanguage) -> String { { LocalizedText.WordCardGallery.categoryGrace.text(for: $0) } }
        var categoryEncouragement: (CoreModels.VerseLanguage) -> String { { LocalizedText.WordCardGallery.categoryEncouragement.text(for: $0) } }
        var categoryWisdom: (CoreModels.VerseLanguage) -> String { { LocalizedText.WordCardGallery.categoryWisdom.text(for: $0) } }
    }
    
    struct ConnectKeys {
        var connect: (CoreModels.VerseLanguage) -> String { { LocalizedText.ConnectView.connect.text(for: $0) } }
        var shareApp: (CoreModels.VerseLanguage) -> String { { LocalizedText.ConnectView.shareApp.text(for: $0) } }
        var contactUs: (CoreModels.VerseLanguage) -> String { { LocalizedText.ConnectView.contactUs.text(for: $0) } }
    }
    
    struct NewsletterKeys {
        var title: (CoreModels.VerseLanguage) -> String { { LocalizedText.NewsletterView.title.text(for: $0) } }
        var loginPrompt: (CoreModels.VerseLanguage) -> String { { LocalizedText.NewsletterView.loginPrompt.text(for: $0) } }
        var loginButton: (CoreModels.VerseLanguage) -> String { { LocalizedText.NewsletterView.loginButton.text(for: $0) } }
        var userMenuTitle: (CoreModels.VerseLanguage) -> String { { LocalizedText.NewsletterView.userMenuTitle.text(for: $0) } }
        var userInfo: (CoreModels.VerseLanguage) -> String { { LocalizedText.NewsletterView.userInfo.text(for: $0) } }
        var logout: (CoreModels.VerseLanguage) -> String { { LocalizedText.NewsletterView.logout.text(for: $0) } }
        var cancel: (CoreModels.VerseLanguage) -> String { { LocalizedText.NewsletterView.cancel.text(for: $0) } }
        var defaultUserName: (CoreModels.VerseLanguage) -> String { { LocalizedText.NewsletterView.defaultUserName.text(for: $0) } }
    }
    
    struct PraiseKeys {
        var subtitle: (CoreModels.VerseLanguage) -> String { { LocalizedText.Praise.subtitle.text(for: $0) } }
        var comingSoon: (CoreModels.VerseLanguage) -> String { { LocalizedText.Praise.comingSoon.text(for: $0) } }
        var description: (CoreModels.VerseLanguage) -> String { { LocalizedText.Praise.description.text(for: $0) } }
        var features: (CoreModels.VerseLanguage) -> String { { LocalizedText.Praise.features.text(for: $0) } }
    }
}

// 用于直接使用当前语言获取本地化文本的便捷函数
extension View {
    func localizedText(_ common: LocalizedText.Common, language: CoreModels.VerseLanguage) -> String {
        return common.text(for: language)
    }
    
    func localizedText(_ settings: LocalizedText.Settings, language: CoreModels.VerseLanguage) -> String {
        return settings.text(for: language)
    }
    
    func localizedText(_ verse: LocalizedText.VerseView, language: CoreModels.VerseLanguage) -> String {
        return verse.text(for: language)
    }

    func localizedText(_ wordCard: LocalizedText.WordCardGallery, language: CoreModels.VerseLanguage) -> String { // New helper function
        return wordCard.text(for: language)
    }
    
    func localizedText(_ connect: LocalizedText.ConnectView, language: CoreModels.VerseLanguage) -> String {
        return connect.text(for: language)
    }
    
    func localizedText(_ newsletter: LocalizedText.NewsletterView, language: CoreModels.VerseLanguage) -> String {
        return newsletter.text(for: language)
    }
    
    func localizedText(_ praise: LocalizedText.Praise, language: CoreModels.VerseLanguage) -> String {
        return praise.text(for: language)
    }
}
