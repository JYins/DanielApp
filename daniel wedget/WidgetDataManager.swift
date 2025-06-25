import Foundation
import GameplayKit

/// Widget独立数据管理器
/// 优先从主App共享缓存读取数据，确保与主App同步
public class WidgetDataManager {
    
    // MARK: - 单例
    public static let shared = WidgetDataManager()
    
    // MARK: - 属性
    private var allVerses: [MultiLanguageVerse] = []
    private var isDataLoaded = false
    private let appGroupIdentifier = "group.com.daniel.DanielApp"
    
    // MARK: - 初始化
    private init() {
        loadWidgetData()
    }
    
    // MARK: - 数据加载
    
    /// 加载Widget经文数据 - 优先从主App共享缓存读取
    private func loadWidgetData() {
        print("🔄 Widget开始加载数据...")
        
        // 优先尝试从主App共享缓存读取当前经文
        if let sharedVerse = loadVerseFromMainAppCache() {
            print("✅ Widget成功从主App缓存读取经文: \(sharedVerse.reference)")
            // 为了保持Widget功能完整，仍需要加载完整数据集
            loadCompleteDataSet()
            return
        }
        
        // 如果无法从主App读取，则加载Widget独立数据
        loadCompleteDataSet()
    }
    
    /// 从主App缓存读取当前经文
    private func loadVerseFromMainAppCache() -> MultiLanguageVerse? {
        guard let groupDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ Widget无法获取App Group UserDefaults")
            return nil
        }
        
        // 强制同步获取最新数据
        groupDefaults.synchronize()
        
        // 方法1: 尝试读取主App缓存的简化格式数据
        if let reference = groupDefaults.string(forKey: "widget_verse_reference"),
           let cnText = groupDefaults.string(forKey: "widget_verse_cn"),
           let enText = groupDefaults.string(forKey: "widget_verse_en"),
           let krText = groupDefaults.string(forKey: "widget_verse_kr") {
            
            print("✅ Widget读取到主App缓存的简化格式经文")
            return MultiLanguageVerse(reference: reference, cn: cnText, en: enText, kr: krText)
        }
        
        // 方法2: 尝试读取主App缓存的JSON格式数据
        if let verseData = groupDefaults.data(forKey: "cachedCurrentVerse") {
            do {
                let verse = try JSONDecoder().decode(MultiLanguageVerse.self, from: verseData)
                print("✅ Widget读取到主App缓存的JSON格式经文")
                return verse
            } catch {
                print("❌ Widget解析主App缓存的JSON数据失败: \(error)")
            }
        }
        
        print("⚠️ Widget无法从主App缓存读取经文")
        return nil
    }
    
    /// 加载完整数据集（用于随机经文等功能）
    private func loadCompleteDataSet() {
        // 首先尝试从主Bundle加载完整数据
        if let url = Bundle.main.url(forResource: "widget_verses", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let verses = try JSONDecoder().decode([MultiLanguageVerse].self, from: data)
                self.allVerses = verses
                self.isDataLoaded = true
                print("✅ Widget: 成功加载完整数据集 \(verses.count) 条经文")
                return
            } catch {
                print("❌ Widget: 解析完整数据集失败 - \(error)")
            }
        }
        
        // 如果无法加载完整数据，使用备用数据
        loadFallbackData()
    }

    /// 加载备用数据（当主数据文件不可用时）
    private func loadFallbackData() {
        // 提供一些备用经文，确保Widget始终有内容显示
        allVerses = [
            MultiLanguageVerse(
                reference: "John 3:16",
                cn: "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不至灭亡，反得永生。",
                en: "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
                kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라"
            ),
            MultiLanguageVerse(
                reference: "Psalms 23:1",
                cn: "耶和华是我的牧者，我必不致缺乏。",
                en: "The Lord is my shepherd, I lack nothing.",
                kr: "여호와는 나의 목자시니 내게 부족함이 없으리로다"
            ),
            MultiLanguageVerse(
                reference: "Isaiah 40:31",
                cn: "但那等候耶和华的必从新得力。他们必如鹰展翅上腾；他们奔跑却不困倦，行走却不疲乏。",
                en: "But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.",
                kr: "오직 여호와를 앙망하는 자는 새 힘을 얻으리니 독수리가 날개 치며 올라감 같을 것이요 달음박질하여도 곤비하지 아니하겠고 걸어가도 피곤하지 아니하리로다"
            )
        ]
        isDataLoaded = true
        print("⚠️ Widget: 使用备用经文数据")
    }
    
    // MARK: - 经文选择算法
    
    /// 获取今日经文 - 优先从主App缓存读取
    /// - Returns: 今日的经文
    public func getTodaysVerse() -> MultiLanguageVerse {
        // 首先尝试从主App缓存读取最新经文
        if let cachedVerse = loadVerseFromMainAppCache() {
            return cachedVerse
        }
        
        // 如果无法从缓存读取，使用日期算法
        return getVerseForDate(Date())
    }
    
    /// 获取指定日期的经文
    /// - Parameter date: 目标日期
    /// - Returns: 对应日期的经文
    public func getVerseForDate(_ date: Date) -> MultiLanguageVerse {
        guard isDataLoaded && !allVerses.isEmpty else {
            // 如果数据未加载或为空，返回默认经文
            return getDefaultVerse()
        }
        
        // 使用日期种子算法确保同一天始终返回相同经文
        let seed = calculateDateSeed(for: date)
        let index = seed % allVerses.count
        
        return allVerses[index]
    }
    
    /// 计算日期种子
    /// - Parameter date: 目标日期
    /// - Returns: 种子值
    private func calculateDateSeed(for date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        let year = components.year ?? 2024
        let month = components.month ?? 1
        let day = components.day ?? 1
        
        // 使用年份、月份和日期创建唯一种子
        // 这确保了每一天都有固定的经文，但跨年也有所变化
        return (year * 10000) + (month * 100) + day
    }
    
    /// 获取默认经文（当数据加载失败时使用）
    private func getDefaultVerse() -> MultiLanguageVerse {
        return MultiLanguageVerse(
            reference: "Psalms 118:24",
            cn: "这是耶和华所定的日子，我们在其中要高兴欢喜！",
            en: "This is the day the Lord has made; let us rejoice and be glad in it.",
            kr: "이 날은 여호와께서 정하신 것이라 이 날에 우리가 즐거워하고 기뻐하리로다"
        )
    }
    
    // MARK: - 公共接口
    
    /// 获取随机经文
    /// - Returns: 随机选择的经文
    public func getRandomVerse() -> MultiLanguageVerse {
        guard isDataLoaded && !allVerses.isEmpty else {
            return getDefaultVerse()
        }
        
        return allVerses.randomElement() ?? getDefaultVerse()
    }
    
    /// 根据引用获取经文
    /// - Parameter reference: 经文引用
    /// - Returns: 匹配的经文，如果找不到则返回nil
    public func getVerse(by reference: String) -> MultiLanguageVerse? {
        guard isDataLoaded else { return nil }
        return allVerses.first { $0.reference == reference }
    }
    
    /// 获取所有可用经文数量
    /// - Returns: 经文总数
    public func getVersesCount() -> Int {
        return allVerses.count
    }
    
    /// 检查数据是否已加载
    /// - Returns: 数据加载状态
    public func isDataReady() -> Bool {
        return isDataLoaded
    }
    
    /// 强制重新加载数据
    public func reloadData() {
        print("🔄 Widget强制重新加载数据...")
        isDataLoaded = false
        allVerses.removeAll()
        loadWidgetData()
    }
    
    /// 强制从主App同步最新数据
    public func syncWithMainApp() {
        print("🔄 Widget强制从主App同步数据...")
        loadWidgetData()
    }
}

// MARK: - 调试扩展
extension WidgetDataManager {
    /// 获取调试信息
    public func getDebugInfo() -> String {
        let cachedVerse = loadVerseFromMainAppCache()
        return """
        Widget数据管理器状态:
        - 数据已加载: \(isDataLoaded)
        - 经文数量: \(allVerses.count)
        - 主App缓存经文: \(cachedVerse?.reference ?? "无")
        - 今日经文: \(getTodaysVerse().reference)
        """
    }
}