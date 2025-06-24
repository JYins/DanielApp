import SwiftUI
import Foundation

// 经文数据模型 - 多语言支持
public struct MultiLanguageVerse: Codable, Hashable, Identifiable {
    public let reference: String
    public let cn: String
    public let en: String
    public let kr: String
    
    // Identifiable 协议要求
    public var id: String { reference }
    
    public init(reference: String, cn: String, en: String, kr: String) {
        self.reference = reference
        self.cn = cn
        self.en = en
        self.kr = kr
    }
}

// 核心命名空间，用于共享基础模型和工具
public enum CoreModels {
    // 支持的经文语言
    public enum VerseLanguage: String, CaseIterable, Codable {
        case chinese = "cn"
        case english = "en"
        case korean = "kr"
        
        public var description: String {
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

    // Widget数据模型
    public struct VerseEntry {
        public let date: Date
        public let verse: MultiLanguageVerse
        public let preferredLanguage: VerseLanguage
        
        public static var placeholder: VerseEntry {
            VerseEntry(
                date: Date(),
                verse: MultiLanguageVerse(
                    reference: "John 3:16",
                    cn: "神爱世人，甚至将他的独生子赐给他们…",
                    en: "For God so loved the world, that he gave his only Son...",
                    kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니…"
                ),
                preferredLanguage: .english
            )
        }
        
        public init(date: Date, verse: MultiLanguageVerse, preferredLanguage: VerseLanguage) {
            self.date = date
            self.verse = verse
            self.preferredLanguage = preferredLanguage
        }
    }
}

// 工具命名空间，用于共享通用工具
public enum UITools {
    // 十六进制颜色支持
    static public func colorFromHex(_ hex: String) -> Color {
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
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Color扩展，使用工具函数
extension Color {
    public init(hex: String) {
        self = UITools.colorFromHex(hex)
    }
}

// 应用样式常量
public enum AppStyles {
    public static let goldColor = Color(hex: "D4AF37")
    public static let lightGoldColor = Color(hex: "F4E3A0")
}