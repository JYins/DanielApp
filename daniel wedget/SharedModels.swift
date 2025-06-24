import SwiftUI
import Foundation
import GameplayKit
import WidgetKit

// 经文数据模型 - 多语言支持
public struct MultiLanguageVerse: Codable, Identifiable {
    public var id: String { reference }
    public let reference: String
    public let cn: String
    public let en: String
    public let kr: String
}

// 核心命名空间，用于共享基础模型和工具
public enum CoreModels {
    // 支持的经文语言
    public enum VerseLanguage: String, CaseIterable, Identifiable {
        case chinese = "cn"
        case english = "en"
        case korean = "kr"
        
        // 实现Identifiable
        public var id: String { rawValue }
        
        // 获取本地化显示名称
        public var displayName: String {
            switch self {
            case .chinese: return "中文"
            case .english: return "English"
            case .korean: return "한국어"
            }
        }
        
        // 书卷名称映射 - 英文到其他语言
        private static let bookNameMapping: [String: [VerseLanguage: String]] = [
            // 旧约书卷
            "Genesis": [.chinese: "创世记", .korean: "창세기"],
            "Exodus": [.chinese: "出埃及记", .korean: "출애굽기"],
            "Leviticus": [.chinese: "利未记", .korean: "레위기"],
            "Numbers": [.chinese: "民数记", .korean: "민수기"],
            "Deuteronomy": [.chinese: "申命记", .korean: "신명기"],
            "Joshua": [.chinese: "约书亚记", .korean: "여호수아"],
            "Judges": [.chinese: "士师记", .korean: "사사기"],
            "Ruth": [.chinese: "路得记", .korean: "룻기"],
            "1 Samuel": [.chinese: "撒母耳记上", .korean: "사무엘상"],
            "2 Samuel": [.chinese: "撒母耳记下", .korean: "사무엘하"],
            "1 Kings": [.chinese: "列王纪上", .korean: "열왕기상"],
            "2 Kings": [.chinese: "列王纪下", .korean: "열왕기하"],
            "1 Chronicles": [.chinese: "历代志上", .korean: "역대상"],
            "2 Chronicles": [.chinese: "历代志下", .korean: "역대하"],
            "Ezra": [.chinese: "以斯拉记", .korean: "에스라"],
            "Nehemiah": [.chinese: "尼希米记", .korean: "느헤미야"],
            "Esther": [.chinese: "以斯帖记", .korean: "에스더"],
            "Job": [.chinese: "约伯记", .korean: "욥기"],
            "Psalms": [.chinese: "诗篇", .korean: "시편"],
            "Proverbs": [.chinese: "箴言", .korean: "잠언"],
            "Ecclesiastes": [.chinese: "传道书", .korean: "전도서"],
            "Song of Solomon": [.chinese: "雅歌", .korean: "아가"],
            "Isaiah": [.chinese: "以赛亚书", .korean: "이사야"],
            "Jeremiah": [.chinese: "耶利米书", .korean: "예레미야"],
            "Lamentations": [.chinese: "耶利米哀歌", .korean: "예레미야애가"],
            "Ezekiel": [.chinese: "以西结书", .korean: "에스겔"],
            "Daniel": [.chinese: "但以理书", .korean: "다니엘"],
            "Hosea": [.chinese: "何西阿书", .korean: "호세아"],
            "Joel": [.chinese: "约珥书", .korean: "요엘"],
            "Amos": [.chinese: "阿摩司书", .korean: "아모스"],
            "Obadiah": [.chinese: "俄巴底亚书", .korean: "오바댜"],
            "Jonah": [.chinese: "约拿书", .korean: "요나"],
            "Micah": [.chinese: "弥迦书", .korean: "미가"],
            "Nahum": [.chinese: "那鸿书", .korean: "나훔"],
            "Habakkuk": [.chinese: "哈巴谷书", .korean: "하박국"],
            "Zephaniah": [.chinese: "西番雅书", .korean: "스바냐"],
            "Haggai": [.chinese: "哈该书", .korean: "학개"],
            "Zechariah": [.chinese: "撒迦利亚书", .korean: "스가랴"],
            "Malachi": [.chinese: "玛拉基书", .korean: "말라기"],
            
            // 新约书卷
            "Matthew": [.chinese: "马太福音", .korean: "마태복음"],
            "Mark": [.chinese: "马可福音", .korean: "마가복음"],
            "Luke": [.chinese: "路加福音", .korean: "누가복음"],
            "John": [.chinese: "约翰福音", .korean: "요한복음"],
            "Acts": [.chinese: "使徒行传", .korean: "사도행전"],
            "Romans": [.chinese: "罗马书", .korean: "로마서"],
            "1 Corinthians": [.chinese: "哥林多前书", .korean: "고린도전서"],
            "2 Corinthians": [.chinese: "哥林多后书", .korean: "고린도후서"],
            "Galatians": [.chinese: "加拉太书", .korean: "갈라디아서"],
            "Ephesians": [.chinese: "以弗所书", .korean: "에베소서"],
            "Philippians": [.chinese: "腓立比书", .korean: "빌립보서"],
            "Colossians": [.chinese: "歌罗西书", .korean: "골로새서"],
            "1 Thessalonians": [.chinese: "帖撒罗尼迦前书", .korean: "데살로니가전서"],
            "2 Thessalonians": [.chinese: "帖撒罗尼迦后书", .korean: "데살로니가후서"],
            "1 Timothy": [.chinese: "提摩太前书", .korean: "디모데전서"],
            "2 Timothy": [.chinese: "提摩太后书", .korean: "디모데후서"],
            "Titus": [.chinese: "提多书", .korean: "디도서"],
            "Philemon": [.chinese: "腓利门书", .korean: "빌레몬서"],
            "Hebrews": [.chinese: "希伯来书", .korean: "히브리서"],
            "James": [.chinese: "雅各书", .korean: "야고보서"],
            "1 Peter": [.chinese: "彼得前书", .korean: "베드로전서"],
            "2 Peter": [.chinese: "彼得后书", .korean: "베드로후서"],
            "1 John": [.chinese: "约翰一书", .korean: "요한일서"],
            "2 John": [.chinese: "约翰二书", .korean: "요한이서"],
            "3 John": [.chinese: "约翰三书", .korean: "요한삼서"],
            "Jude": [.chinese: "犹大书", .korean: "유다서"],
            "Revelation": [.chinese: "启示录", .korean: "요한계시록"]
        ]
        
        // 反向映射表 - 其他语言到英文
        private static var reverseBookNameMapping: [VerseLanguage: [String: String]] = {
            var result: [VerseLanguage: [String: String]] = [.chinese: [:], .korean: [:], .english: [:]]
            
            for (englishName, translations) in bookNameMapping {
                for (language, translatedName) in translations {
                    result[language]?[translatedName] = englishName
                }
                // 英文映射到自身
                result[.english]?[englishName] = englishName
            }
            
            return result
        }()
        
        // 将经文引用转换为显示语言
        public static func localizeReference(_ reference: String, to language: VerseLanguage) -> String {
            // 如果是英文，直接返回
            if language == .english {
                return reference
            }
            
            // 分离书卷名和章节
            let components = reference.components(separatedBy: " ")
            guard components.count >= 2 else { return reference }
            
            // 提取书卷名和章节
            let lastIndex = components.count - 1
            let chapterVerse = components[lastIndex]
            let bookName = components[0..<lastIndex].joined(separator: " ")
            
            // 转换罗马数字格式 (I, II, III) 为阿拉伯数字格式 (1, 2, 3)
            var standardizedBookName = bookName
            if bookName.hasPrefix("I ") && !bookName.hasPrefix("II") && !bookName.hasPrefix("III") {
                standardizedBookName = "1 " + bookName.dropFirst(2)
            } else if bookName.hasPrefix("II ") {
                standardizedBookName = "2 " + bookName.dropFirst(3)
            } else if bookName.hasPrefix("III ") {
                standardizedBookName = "3 " + bookName.dropFirst(4)
            }
            
            // 获取本地化书卷名
            if let translatedName = bookNameMapping[standardizedBookName]?[language] {
                return "\(translatedName) \(chapterVerse)"
            }
            
            // 尝试使用原始书名
            if let translatedName = bookNameMapping[bookName]?[language] {
                return "\(translatedName) \(chapterVerse)"
            }
            
            return reference
        }
        
        // 将本地化引用转换为英文引用 (用于数据获取)
        public static func standardizeReference(_ reference: String, from language: VerseLanguage) -> String {
            // 如果是英文，直接返回
            if language == .english {
                return reference
            }
            
            // 分离书卷名和章节
            let components = reference.components(separatedBy: " ")
            guard components.count >= 2 else { return reference }
            
            // 提取书卷名和章节
            let lastIndex = components.count - 1
            let chapterVerse = components[lastIndex]
            let bookName = components[0..<lastIndex].joined(separator: " ")
            
            // 获取标准化(英文)书卷名
            if let englishName = reverseBookNameMapping[language]?[bookName] {
                // 检查是否需要转换为罗马数字格式
                var formattedEnglishName = englishName
                if englishName.hasPrefix("1 ") {
                    formattedEnglishName = "I " + englishName.dropFirst(2)
                } else if englishName.hasPrefix("2 ") {
                    formattedEnglishName = "II " + englishName.dropFirst(2)
                } else if englishName.hasPrefix("3 ") {
                    formattedEnglishName = "III " + englishName.dropFirst(2)
                }
                
                return "\(formattedEnglishName) \(chapterVerse)"
            }
            
            return reference
        }
    }
}

// Color扩展，使用十六进制颜色
extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// 经文数据服务 - 精简版，仅用于Widget
public class VerseDataService {
    // 单例模式
    public static let shared = VerseDataService()
    
    // App Group标识符
    private static let appGroupIdentifier = "group.com.daniel.DanielApp"
    
    // UserDefaults键 - 与主应用保持一致
    private struct Keys {
        static let selectedLanguage = "selectedLanguage"
        static let updateMode = "updateMode"
        static let currentVerseReference = "currentVerseReference"  // 永久引用（手动模式和固定模式用）
        static let tempSwitchedReference = "tempSwitchedReference"  // 临时切换引用（自动模式当天切换用）
        static let isVerseFixed = "isVerseFixed"
        static let cachedCurrentVerse = "cachedCurrentVerse" // 主应用缓存的当前经文数据
        static let lastDailyVerseRefreshDate = "lastDailyVerseRefreshDate"
    }
    
    private init() {
        print("Widget初始化VerseDataService")
        // 打印当前使用的App Group ID
        print("使用App Group: \(VerseDataService.appGroupIdentifier)")
        
        // 检查是否可以访问共享UserDefaults
        let defaults = getSharedDefaults()
        if let reference = defaults.string(forKey: Keys.currentVerseReference) {
            print("成功读取引用: \(reference)")
        } else {
            print("无法读取经文引用")
        }
        
        // 检查是否能读取缓存的经文数据
        if let verseData = defaults.data(forKey: Keys.cachedCurrentVerse) {
            print("找到缓存的经文数据，大小: \(verseData.count) 字节")
            
            do {
                let verse = try JSONDecoder().decode(MultiLanguageVerse.self, from: verseData)
                print("成功解析缓存的经文: \(verse.reference)")
            } catch {
                print("解析缓存经文失败: \(error)")
            }
        } else {
            print("未找到缓存经文数据")
        }
    }

    // 获取共享UserDefaults
    private func getSharedDefaults() -> UserDefaults {
        print("尝试获取共享UserDefaults，App Group: \(VerseDataService.appGroupIdentifier)")
        if let defaults = UserDefaults(suiteName: VerseDataService.appGroupIdentifier) {
            print("✅ 成功获取App Group UserDefaults")
            return defaults
        } else {
            print("⚠️ 无法获取App Group UserDefaults，使用标准UserDefaults")
            return UserDefaults.standard
        }
    }
    
    // 获取今天的经文
    public func getVerseForToday() -> MultiLanguageVerse? {
        // 直接从主应用缓存中获取当前经文
        return getCurrentVerseToDisplay()
    }
    
    // 根据引用查找经文
    public func findVerse(byReference reference: String) -> MultiLanguageVerse? {
        // 如果引用与当前缓存的经文相同，直接返回缓存的经文
        if let cachedVerse = getCurrentVerseFromCache(), cachedVerse.reference == reference {
            return cachedVerse
        }
        
        // 尝试将引用标准化为英文后再检查
        let currentLanguage = getPreferredLanguage()
        if currentLanguage != .english {
            let standardizedRef = CoreModels.VerseLanguage.standardizeReference(reference, from: currentLanguage)
            if standardizedRef != reference, 
               let cachedVerse = getCurrentVerseFromCache(), 
               cachedVerse.reference == standardizedRef {
                return cachedVerse
            }
        }
        
        // 否则返回默认经文
        return getDefaultVerseWithReference(reference)
    }
    
    // 获取当前要显示的经文（Widget专用，只读取主App缓存）
    func getCurrentVerseToDisplay() -> MultiLanguageVerse? {
        print("🔍 Widget开始获取当前经文...")
        
        let defaults = UserDefaults(suiteName: "group.com.daniel.DanielApp") ?? UserDefaults.standard
        defaults.synchronize()
        print("📱 Widget已强制同步UserDefaults")
        
        // 方法1: 尝试读取主App为Widget缓存的简化格式数据
        if let reference = defaults.string(forKey: "widget_current_reference"),
           let cnText = defaults.string(forKey: "widget_current_cn"),
           let enText = defaults.string(forKey: "widget_current_en"),
           let krText = defaults.string(forKey: "widget_current_kr") {
            
            print("✅ Widget成功读取主App缓存的简化格式经文")
            print("📖 引用: \(reference)")
            print("🇨🇳 中文: \(cnText.prefix(30))...")
            
            let verse = MultiLanguageVerse(reference: reference, cn: cnText, en: enText, kr: krText)
            
            // 检查缓存时间
            if let cacheTime = defaults.object(forKey: "widget_cache_time") as? Date {
                let age = Date().timeIntervalSince(cacheTime)
                print("⏰ 缓存年龄: \(String(format: "%.1f", age/60.0)) 分钟")
            } else {
                print("⚠️ 未找到缓存时间戳")
            }
            
            return verse
        }
        
        // 方法2: 尝试读取主App缓存的完整JSON格式数据
        if let cachedData = defaults.data(forKey: "cachedCurrentVerse") {
            print("📦 Widget尝试读取主App的JSON缓存数据 (\(cachedData.count) 字节)")
            
            do {
                let verse = try JSONDecoder().decode(MultiLanguageVerse.self, from: cachedData)
                print("✅ Widget成功解析JSON格式经文: \(verse.reference)")
                return verse
            } catch {
                print("❌ Widget解析JSON数据失败: \(error.localizedDescription)")
            }
        } else {
            print("❌ Widget未找到JSON缓存数据")
        }
        
        // 方法3: 如果没有缓存，尝试读取主App的当前状态构建经文
        print("🔄 Widget尝试根据主App状态构建经文...")
        
        let updateMode = defaults.string(forKey: "updateMode") ?? "automatic"
        let isFixed = defaults.bool(forKey: "isVerseFixed")
        let currentRef = defaults.string(forKey: "currentVerseReference")
        let tempRef = defaults.string(forKey: "tempSwitchedReference")
        
        print("📋 主App状态 - 模式:\(updateMode), 固定:\(isFixed), 当前引用:\(currentRef ?? "无"), 临时引用:\(tempRef ?? "无")")
        
        // 决定使用哪个引用
        var targetReference: String?
        
        if updateMode == "manual" || isFixed {
            targetReference = currentRef
            print("📌 Widget使用手动/固定模式引用: \(targetReference ?? "无")")
        } else if updateMode == "automatic" {
            // 自动模式：优先使用临时引用，否则获取今日经文
            if let temp = tempRef {
                targetReference = temp
                print("📌 Widget使用自动模式临时引用: \(targetReference!)")
            } else {
                print("📅 Widget将获取今日经文")
                // 构建今日经文
                let verse = getVerseForToday()
                print("📖 Widget获取到今日经文: \(verse?.reference ?? "无")")
                return verse
            }
        }
        
        // 根据引用构建经文
        if let reference = targetReference {
            print("🔍 Widget尝试根据引用构建经文: \(reference)")
            if let verse = findVerse(byReference: reference) {
                print("✅ Widget成功构建经文: \(verse.reference)")
                return verse
            } else {
                print("❌ Widget无法根据引用构建经文")
            }
        }
        
        // 最后的备用方案：返回默认经文
        print("🆘 Widget使用备用默认经文")
        return MultiLanguageVerse(
            reference: "John 3:16",
            cn: "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不致灭亡，反得永生。",
            en: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
            kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라."
        )
    }
    
    // 从主应用缓存中获取当前经文 - 仅用于兼容性，实际使用getCurrentVerseToDisplay
    private func getCurrentVerseFromCache() -> MultiLanguageVerse? {
        // 直接调用新的获取方法
        return getCurrentVerseToDisplay()
    }
    
    // 辅助函数：使用指定引用创建默认经文
    private func getDefaultVerseWithReference(_ reference: String) -> MultiLanguageVerse {
        return MultiLanguageVerse(
            reference: reference,
            cn: "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不致灭亡，反得永生。",
            en: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
            kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라."
        )
    }
    
    // 获取默认经文
    private func getDefaultVerse() -> MultiLanguageVerse {
        print("⚠️ 使用默认经文 (John 3:16)")
        return MultiLanguageVerse(
            reference: "[默认] John 3:16",
            cn: "[默认经文] 神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不致灭亡，反得永生。",
            en: "[DEFAULT] For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
            kr: "[기본값] 하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라."
        )
    }
    
    // 获取当前引用
    private func getCurrentVerseReference() -> String? {
        let defaults = getSharedDefaults()
        return defaults.string(forKey: Keys.currentVerseReference)
    }

    // 获取偏好语言
    public func getPreferredLanguage() -> CoreModels.VerseLanguage {
        let defaults = getSharedDefaults()
        let savedValue = defaults.string(forKey: Keys.selectedLanguage)
        
        if let savedValue = savedValue, let language = CoreModels.VerseLanguage(rawValue: savedValue) {
            return language
        }
        
        // 默认使用中文
        return .chinese
    }
} 