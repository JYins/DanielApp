import Foundation
import WidgetKit

// 此文件保留以供向后兼容
// 所有模型和功能已移至SharedModels.swift 

// 核心数据服务 - 为主应用和Widget提供数据服务
public class VerseDataService {
    // 单例模式
    public static let shared = VerseDataService()
    
    // App Group标识符
    private let appGroupIdentifier = "group.com.daniel.DanielApp"
    
    // UserDefaults键
    public struct Keys {
        static let selectedLanguage = "selectedLanguage"
        static let updateMode = "updateMode"
        static let currentVerseReference = "currentVerseReference"  // 永久引用（手动模式和固定模式用）
        static let tempSwitchedReference = "tempSwitchedReference"  // 临时切换引用（自动模式当天切换用）
        static let isVerseFixed = "isVerseFixed"
        static let cachedCurrentVerse = "cachedCurrentVerse"
        static let lastDailyVerseRefreshDate = "lastDailyVerseRefreshDate"
    }
    
    // 缓存所有经文
    private var allVerses: [MultiLanguageVerse]?
    private var verseIndexList: [String]?
    
    private init() {
        let defaults = getSharedDefaults()
        
        // 设置默认值
        if defaults.string(forKey: Keys.updateMode) == nil {
            defaults.set("automatic", forKey: Keys.updateMode)
        }
        if defaults.object(forKey: Keys.isVerseFixed) == nil {
            defaults.set(false, forKey: Keys.isVerseFixed)
        }
        
        defaults.synchronize()
        
        // 预加载数据
        print("开始加载经文数据...")
        self.loadVersesIfNeeded()
        self.loadVerseIndexListIfNeeded()
        
        // 验证数据加载
        if let verses = allVerses {
            print("成功加载经文数据，共 \(verses.count) 条经文")
        } else {
            print("警告：经文数据加载失败")
        }
        
        if let indices = verseIndexList {
            print("成功加载经文索引，共 \(indices.count) 条索引")
        } else {
            print("警告：经文索引加载失败")
        }
    }
    
    // MARK: - 数据加载函数
    
    // 加载全部经文数据
    public func loadVersesIfNeeded() {
        if allVerses == nil {
            allVerses = loadVersesFromJson()
        }
    }
    
    // 加载经文索引列表
    public func loadVerseIndexListIfNeeded() {
        if verseIndexList == nil {
            verseIndexList = loadVerseIndexList()
        }
    }
    
    // 从JSON加载经文数据
    public func loadVersesFromJson() -> [MultiLanguageVerse]? {
        print("🔍 尝试从 Bundle 加载 verses_merged.json...")
        
        // 主要方法：从 Bundle 加载
        if let url = Bundle.main.url(forResource: "verses_merged", withExtension: "json") {
            print("✅ Bundle 中找到 verses_merged.json: \(url.path)")
            do {
                let data = try Data(contentsOf: url)
                print("✅ 成功读取JSON文件，大小: \(data.count) bytes")
                
                // 解析JSON数据
                let verses = try JSONDecoder().decode([MultiLanguageVerse].self, from: data)
                print("✅ 成功解析JSON数据，经文数量: \(verses.count)")
                
                // 打印前两条经文作为示例
                if verses.count >= 2 {
                    print("📖 示例经文1: \(verses[0].reference)")
                    print("  中文: \(verses[0].cn.prefix(30))...")
                    print("📖 示例经文2: \(verses[1].reference)")
                    print("  中文: \(verses[1].cn.prefix(30))...")
                }
                
                return verses
            } catch {
                print("❌ 解析JSON失败: \(error)")
                return nil // Add return nil here
            }
        } else {
            print("❌ Bundle 中找不到 verses_merged.json")
            // 列出 Bundle 中的 JSON 文件以帮助调试
            listBundleJsonFiles()
            
            // 使用备用方法 - 硬编码经文
            print("⚠️ Bundle 加载失败，使用硬编码经文")
            return getHardcodedVerses()
        }
    }
    
    // 辅助函数：列出 Bundle 中的 JSON 文件
    private func listBundleJsonFiles() {
        let fileManager = FileManager.default
        print("🔍 正在检查 Bundle 中的 JSON 文件...")
        if let bundleURL = Bundle.main.resourceURL {
            do {
                let contents = try fileManager.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)
                let jsonFiles = contents.filter { $0.pathExtension == "json" }
                if jsonFiles.isEmpty {
                    print("📦 Bundle 中未找到任何 JSON 文件。")
                } else {
                    print("📦 Bundle 中的 JSON 文件:")
                    for file in jsonFiles {
                        print("  - \(file.lastPathComponent)")
                    }
                }
            } catch {
                print("❌ 无法列出 Bundle 内容: \(error)")
            }
        } else {
             print("❌ 无法获取 Bundle 资源路径。")
        }
    }
    
    // 从JSON加载经文索引列表
    public func loadVerseIndexList() -> [String]? {
        print("🔍 尝试从 Bundle 加载 verses_index.json...")
        
        // 主要方法：从 Bundle 加载
        if let url = Bundle.main.url(forResource: "verses_index", withExtension: "json") {
            print("✅ Bundle 中找到 verses_index.json: \(url.path)")
            do {
                let data = try Data(contentsOf: url)
                print("✅ 成功读取索引文件，大小: \(data.count) bytes")
                
                // 解析JSON数据
                let references = try JSONDecoder().decode([String].self, from: data)
                print("✅ 成功解析索引数据，引用数量: \(references.count)")
                
                // 打印前两个索引作为示例
                if references.count >= 2 {
                    print("📖 示例索引1: \(references[0])")
                    print("📖 示例索引2: \(references[1])")
                }
                
                return references
            } catch {
                print("❌ 解析索引JSON失败: \(error)")
                return nil // Add return nil here
            }
        } else {
            print("❌ Bundle 中找不到 verses_index.json")
            // 列出 Bundle 中的 JSON 文件以帮助调试
            listBundleJsonFiles()
            
            // 最后，使用硬编码的引用列表
            print("⚠️ Bundle 加载失败，使用硬编码经文索引")
            return getVerseReferences()
        }
    }
    
    // 注意：loadIndexFromDocumentDirectory 函数已被移除
    
    // 获取硬编码的示例经文 - 确保即使JSON加载失败也有内容显示
    private func getHardcodedVerses() -> [MultiLanguageVerse] {
        let verses: [MultiLanguageVerse] = [
            MultiLanguageVerse(
                reference: "John 3:16",
                cn: "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不致灭亡，反得永生。",
                en: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
                kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라."
            ),
            MultiLanguageVerse(
                reference: "Psalms 23:1",
                cn: "耶和华是我的牧者，我必不致缺乏。",
                en: "The Lord is my shepherd; I shall not want.",
                kr: "여호와는 나의 목자시니 내게 부족함이 없으리로다."
            ),
            MultiLanguageVerse(
                reference: "Proverbs 3:5",
                cn: "你要专心仰赖耶和华，不可倚靠自己的聪明。",
                en: "Trust in the Lord with all your heart, and do not lean on your own understanding.",
                kr: "너는 마음을 다하여 여호와를 신뢰하고 네 명철을 의지하지 말라."
            ),
            MultiLanguageVerse(
                reference: "Isaiah 40:31",
                cn: "但那等候耶和华的，必重新得力。他们必如鹰展翅上腾，他们奔跑却不困倦，行走却不疲乏。",
                en: "But they who wait for the Lord shall renew their strength; they shall mount up with wings like eagles; they shall run and not be weary; they shall walk and not faint.",
                kr: "오직 여호와를 앙망하는 자는 새 힘을 얻으리니 독수리가 날개치며 올라감 같을 것이요 달음박질하여도 곤비하지 아니하겠고 걸어가도 피곤하지 아니하리로다."
            ),
            MultiLanguageVerse(
                reference: "Philippians 4:13",
                cn: "我靠着那加给我力量的，凡事都能做。",
                en: "I can do all things through him who strengthens me.",
                kr: "내게 능력 주시는 자 안에서 내가 모든 것을 할 수 있느니라."
            ),
            MultiLanguageVerse(
                reference: "Romans 8:28",
                cn: "我们晓得万事都互相效力，叫爱神的人得益处，就是按他旨意被召的人。",
                en: "And we know that for those who love God all things work together for good, for those who are called according to his purpose.",
                kr: "우리가 알거니와 하나님을 사랑하는 자 곧 그 뜻대로 부르심을 입은 자들에게는 모든 것이 합력하여 선을 이루느니라."
            ),
            MultiLanguageVerse(
                reference: "Jeremiah 29:11",
                cn: "耶和华说：我知道我向你们所怀的意念是赐平安的意念，不是降灾祸的意念，要叫你们末后有指望。",
                en: "For I know the plans I have for you, declares the Lord, plans for welfare and not for evil, to give you a future and a hope.",
                kr: "여호와의 말씀이니라 너희를 향한 나의 생각은 내가 아나니 평안이요 재앙이 아니니라 너희에게 미래와 희망을 주는 것이니라."
            )
        ]
        return verses
    }
    
    // 获取硬编码的经文引用列表
    private func getVerseReferences() -> [String] {
        return getHardcodedVerses().map { $0.reference }
    }
    
    // MARK: - 经文选择逻辑
    
    // 根据日期获取经文索引
    public func getVerseReferenceFor(date: Date) -> String? {
        loadVerseIndexListIfNeeded()
        
        guard let indices = verseIndexList, !indices.isEmpty else {
            return nil
        }
        
        // 计算当年中的第几天（1-366）
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        
        // 使用当年日期作为索引，确保每天不同的经文
        let indexForToday = (dayOfYear - 1) % indices.count
        
        return indices[indexForToday]
    }
    
    // 根据引用查找经文
    public func findVerse(byReference reference: String) -> MultiLanguageVerse? {
        loadVersesIfNeeded()
        
        if let verses = allVerses {
            // 首先尝试直接匹配
            if let verse = verses.first(where: { $0.reference == reference }) {
                return verse
            }
            
            // 如果直接匹配失败，尝试将引用标准化为英文后再匹配
            let currentLanguage = getSelectedLanguage()
            if currentLanguage != .english {
                let standardizedRef = CoreModels.VerseLanguage.standardizeReference(reference, from: currentLanguage)
                if standardizedRef != reference {
                    return verses.first(where: { $0.reference == standardizedRef })
                }
            }
        }
        
        print("⚠️ 警告：未找到引用 '\(reference)' 的经文")
        return nil
    }
    
    // 获取今天的经文
    public func getVerseForToday() -> MultiLanguageVerse? {
        let today = Date()
        print("正在获取今日经文...")
        
        // 首先尝试使用日期方法获取经文 - 确保一年内不重复
        print("🗓️ 使用日期方法获取经文...")
        if let reference = getVerseReferenceFor(date: today) {
            if let verse = findVerse(byReference: reference) {
                print("✅ 成功获取今日经文: \(verse.reference)")
                
                // 缓存这个日期对应的经文
                if !isVerseFixed() {
                    print("未处于固定模式，缓存今日经文")
                    cacheCurrentVerse(verse)
                }
                
                return verse
            } else {
                print("⚠️ 找到引用 \(reference) 但未找到对应经文，尝试备选方法")
            }
        } else {
            print("⚠️ 无法获取今日引用，尝试备选方法")
        }
        
        // 如果日期方法失败，尝试使用随机方法作为备选
        print("🎲 尝试随机方法作为备选...")
        if let randomRef = getRandomVerseReference() {
            if let verse = findVerse(byReference: randomRef) {
                print("✅ 成功获取随机经文: \(verse.reference)")
                // 将随机经文缓存
                if !isVerseFixed() {
                    cacheCurrentVerse(verse)
                }
                return verse
            }
        }
        
        // 如果所有方法都失败，返回默认经文
        print("⚠️ 所有方法都失败，返回默认经文")
        return getDefaultVerse()
    }
    
    // 获取随机经文引用 (不同于当前显示的)
    public func getRandomVerseReference(different from: String? = nil) -> String? {
        loadVerseIndexListIfNeeded()
        
        // 如果索引列表为空，尝试从所有经文中获取
        if verseIndexList == nil || verseIndexList?.isEmpty == true {
            loadVersesIfNeeded()
            guard let verses = allVerses, !verses.isEmpty else {
                print("无法加载经文数据")
                return nil
            }
            
            if let currentRef = from {
                // 尝试最多5次获取不同的引用
                for _ in 0..<5 {
                    let randomIndex = Int.random(in: 0..<verses.count)
                    let newRef = verses[randomIndex].reference
                    if newRef != currentRef {
                        return newRef
                    }
                }
            }
            
            // 如果没有找到不同的或不需要不同的，就返回随机一个
            let randomIndex = Int.random(in: 0..<verses.count)
            return verses[randomIndex].reference
        }
        
        // 使用索引列表
        if let currentRef = from {
            // 尝试最多5次获取不同的引用
            for _ in 0..<5 {
                let randomIndex = Int.random(in: 0..<verseIndexList!.count)
                let newRef = verseIndexList![randomIndex]
                if newRef != currentRef {
                    return newRef
                }
            }
        }
        
        // 如果没有找到不同的或不需要不同的，就返回随机一个
        let randomIndex = Int.random(in: 0..<verseIndexList!.count)
        return verseIndexList![randomIndex]
    }
    
    // MARK: - UserDefaults操作
    
    // 获取共享UserDefaults
    public func getSharedDefaults() -> UserDefaults {
        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            return defaults
        } else {
            print("⚠️ 无法获取App Group UserDefaults，使用标准UserDefaults")
            return UserDefaults.standard
        }
    }
    
    // 获取当前语言设置
    public func getSelectedLanguage() -> CoreModels.VerseLanguage {
        let defaults = getSharedDefaults()
        let savedValue = defaults.string(forKey: Keys.selectedLanguage)
        
        if let savedValue = savedValue, let language = CoreModels.VerseLanguage(rawValue: savedValue) {
            return language
        }
        
        // 默认值
        return .chinese
    }
    
    // 设置语言
    public func setSelectedLanguage(_ language: CoreModels.VerseLanguage) {
        let defaults = getSharedDefaults()
        defaults.set(language.rawValue, forKey: Keys.selectedLanguage)
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 获取更新模式
    public func getUpdateMode() -> String {
        let defaults = getSharedDefaults()
        return defaults.string(forKey: Keys.updateMode) ?? "automatic"
    }
    
    // 设置更新模式
    public func setUpdateMode(_ mode: String) {
        let defaults = getSharedDefaults()
        defaults.set(mode, forKey: Keys.updateMode)
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 获取当前选择的经文引用
    public func getCurrentVerseReference() -> String? {
        let defaults = getSharedDefaults()
        return defaults.string(forKey: Keys.currentVerseReference)
    }
    
    // 设置当前选择的经文引用
    public func setCurrentVerseReference(_ reference: String?) {
        let defaults = getSharedDefaults()
        if let reference = reference {
            defaults.set(reference, forKey: Keys.currentVerseReference)
        } else {
            defaults.removeObject(forKey: Keys.currentVerseReference)
        }
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 获取临时切换的经文引用（仅自动模式当天有效）
    public func getTempSwitchedReference() -> String? {
        let defaults = getSharedDefaults()
        return defaults.string(forKey: Keys.tempSwitchedReference)
    }
    
    // 设置临时切换的经文引用（仅自动模式当天有效）
    public func setTempSwitchedReference(_ reference: String?) {
        let defaults = getSharedDefaults()
        if let reference = reference {
            defaults.set(reference, forKey: Keys.tempSwitchedReference)
        } else {
            defaults.removeObject(forKey: Keys.tempSwitchedReference)
        }
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 获取经文是否被固定
    public func isVerseFixed() -> Bool {
        let defaults = getSharedDefaults()
        return defaults.bool(forKey: Keys.isVerseFixed)
    }
    
    // 设置经文是否被固定
    public func setVerseFixed(_ fixed: Bool) {
        let defaults = getSharedDefaults()
        defaults.set(fixed, forKey: Keys.isVerseFixed)
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 根据当前设置确定应该显示的经文
    public func getCurrentVerseToDisplay() -> MultiLanguageVerse? {
        let updateMode = getUpdateMode()
        let isFixed = isVerseFixed()
        let currentRef = getCurrentVerseReference()
        let tempRef = getTempSwitchedReference()
        
        print("=== 开始获取当前显示经文 ===")
        print("📋 更新模式: \(updateMode)")
        print("📌 是否固定: \(isFixed ? "是" : "否")")
        print("📄 永久引用: \(currentRef ?? "无")")
        print("🔄 临时引用: \(tempRef ?? "无")")
        
        var resultVerse: MultiLanguageVerse? = nil
        
        // === 模式1: 固定经文模式 ===
        if isFixed {
            print("🔒 进入固定经文模式")
            if let reference = currentRef {
                print("📖 尝试获取固定经文: \(reference)")
                if let verse = findVerse(byReference: reference) {
                    print("✅ 找到固定经文: \(verse.reference)")
                    resultVerse = verse
                } else {
                    print("❌ 无法找到固定经文，fallback到今日经文")
                    resultVerse = getVerseForToday()
                }
            } else {
                print("❌ 固定模式但无经文引用，fallback到今日经文")
                resultVerse = getVerseForToday()
            }
        }
        // === 模式2: 自动模式 ===
        else if updateMode == "automatic" {
            print("🔄 进入自动模式")
            
            // 检查是否是新的一天
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let defaults = getSharedDefaults()
            
            // 获取上次刷新日期
            let lastRefreshDate: Date?
            if let savedDate = defaults.object(forKey: Keys.lastDailyVerseRefreshDate) as? Date {
                lastRefreshDate = calendar.startOfDay(for: savedDate)
            } else {
                lastRefreshDate = nil
            }
            
            let isNewDay = lastRefreshDate == nil || lastRefreshDate! < today
            
            print("📅 今天: \(today)")
            print("📅 上次刷新: \(lastRefreshDate?.description ?? "从未")")
            print("🆕 是新的一天: \(isNewDay ? "是" : "否")")
            
            if isNewDay {
                // === 新的一天：显示每日一句，清除用户切换状态 ===
                print("🌅 新的一天，重置为每日一句")
                
                // 清除用户切换的临时引用（不影响永久引用）
                if tempRef != nil {
                    print("🧹 清除昨日用户切换的临时引用: \(tempRef!)")
                    setTempSwitchedReference(nil)
                }
                
                // 获取今日经文
                if let verse = getVerseForToday() {
                    print("✅ 获取今日经文: \(verse.reference)")
                    resultVerse = verse
                    
                    // 更新刷新日期
                    defaults.set(today, forKey: Keys.lastDailyVerseRefreshDate)
                    defaults.synchronize()
                    print("📝 已更新刷新日期为今天")
                } else {
                    print("❌ 无法获取今日经文，使用默认经文")
                    resultVerse = getDefaultVerse()
                }
            } else {
                // === 当天内：检查用户是否有切换 ===
                print("📆 仍是当天")
                
                if let reference = tempRef {
                    // 用户今天切换过经文，显示切换的经文
                    print("👤 用户今天切换过经文: \(reference)")
                    if let verse = findVerse(byReference: reference) {
                        print("✅ 找到用户切换的经文: \(verse.reference)")
                        resultVerse = verse
                    } else {
                        print("❌ 无法找到用户切换的经文，fallback到今日经文")
                        resultVerse = getVerseForToday()
                    }
                } else {
                    // 用户今天没有切换，显示今日经文
                    print("📅 用户今天未切换，显示今日经文")
                    if let verse = getVerseForToday() {
                        print("✅ 获取今日经文: \(verse.reference)")
                        resultVerse = verse
                    } else {
                        print("❌ 无法获取今日经文，使用默认经文")
                        resultVerse = getDefaultVerse()
                    }
                }
            }
        }
        // === 模式3: 手动模式 ===
        else {
            print("👐 进入手动模式")
            if let reference = currentRef {
                print("📖 显示手动设置的经文: \(reference)")
                if let verse = findVerse(byReference: reference) {
                    print("✅ 找到手动设置的经文: \(verse.reference)")
                    resultVerse = verse
                } else {
                    print("❌ 无法找到手动设置的经文，fallback到今日经文")
                    resultVerse = getVerseForToday()
                }
            } else {
                print("📅 手动模式但无设置，显示今日经文")
                resultVerse = getVerseForToday()
            }
        }
        
        // === 最终处理和缓存 ===
        if let verse = resultVerse {
            print("✅ 最终选定经文: \(verse.reference)")
            // 缓存当前经文供widget使用
            cacheCurrentVerse(verse)
            print("💾 已缓存经文供widget使用")
        } else {
            print("❌ 警告：无法获取任何经文")
        }
        
        print("=== 获取当前显示经文完成 ===\n")
        return resultVerse
    }
    
    // 缓存当前经文到UserDefaults
    public func cacheCurrentVerse(_ verse: MultiLanguageVerse) {
        let defaults = getSharedDefaults()
        
        print("=== 开始缓存经文到UserDefaults (主App专用) ===")
        print("App Group: \(appGroupIdentifier)")
        print("当前经文: \(verse.reference)")
        print("中文内容: \(verse.cn.prefix(30))...")
        
        // 方法1：缓存完整JSON数据 (用于复杂场景)
        do {
            let encoder = JSONEncoder()
            let verseData = try encoder.encode(verse)
            
            // 清除并写入JSON缓存
            defaults.removeObject(forKey: Keys.cachedCurrentVerse)
            defaults.set(verseData, forKey: Keys.cachedCurrentVerse)
            print("✅ 已缓存JSON格式经文数据")
        } catch {
            print("❌ JSON缓存失败: \(error)")
        }
        
        // 方法2：缓存简化键值对 (Widget专用，更可靠)
        defaults.set(verse.reference, forKey: "widget_verse_reference")
        defaults.set(verse.cn, forKey: "widget_verse_cn")
        defaults.set(verse.en, forKey: "widget_verse_en")
        defaults.set(verse.kr, forKey: "widget_verse_kr")
        defaults.set(Date().timeIntervalSince1970, forKey: "widget_verse_timestamp")
        print("✅ 已缓存Widget专用简化格式数据")
        
        // 立即同步到磁盘
        let syncResult = defaults.synchronize()
        print("同步结果: \(syncResult ? "成功" : "不确定")")
        
        // 验证数据写入成功
        if let verifyRef = defaults.string(forKey: "widget_verse_reference") {
            print("✅ 验证成功: Widget可读取经文 \(verifyRef)")
        } else {
            print("❌ 验证失败: Widget无法读取缓存数据")
        }
        
        // 通知Widget更新
        print("📢 通知Widget更新...")
        WidgetCenter.shared.reloadAllTimelines()
        
        // 延迟再次通知，提高成功率
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            WidgetCenter.shared.reloadAllTimelines()
            print("📢 发送第二次Widget更新通知")
        }
        
        print("=== 经文缓存完成 ===")
    }
    
    // 获取所有经文引用
    public func getAllVerseReferences() -> [String]? {
        // 先尝试获取索引列表
        if let indexList = verseIndexList {
            return indexList
        }
        
        // 如果索引列表不可用，从所有经文中提取引用
        if let verses = allVerses {
            return verses.map { $0.reference }
        }
        
        return nil
    }
    
    // 根据日期获取经文
    public func getVerseForDate(_ date: Date) -> MultiLanguageVerse? {
        loadVersesIfNeeded()
        loadVerseIndexListIfNeeded()
        
        guard let verses = allVerses, !verses.isEmpty else {
            print("无法获取经文数据")
            return nil
        }
        
        // 先尝试从索引列表获取
        if let indices = verseIndexList, !indices.isEmpty {
            let calendar = Calendar.current
            let day = calendar.component(.day, from: date)
            let indexForToday = day % indices.count
            let referenceForToday = indices[indexForToday]
            
            // 查找对应的经文
            if let verse = verses.first(where: { $0.reference == referenceForToday }) {
                return verse
            }
        }
        
        // 如果索引列表不可用或找不到对应经文，直接从所有经文中选择
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        let seed = day + month
        
        let index = seed % verses.count
        return verses[index]
    }
    
    // MARK: - 工具方法
    
    // 清除缓存，强制重新加载
    public func clearCache() {
        print("🧹 清除经文数据缓存...")
        allVerses = nil
        verseIndexList = nil
    }
    
    // 重置当日经文，用于强制刷新自动模式下的经文
    public func resetDailyVerse() {
        print("🔄 重置当日经文...")
        
        // 只有在自动模式且非固定经文时才重置
        if getUpdateMode() == "automatic" && !isVerseFixed() {
            print("🔍 满足自动重置条件，开始执行...")
            
            // 获取当前可能的临时切换引用
            let tempRef = getTempSwitchedReference()
            print("📋 当前临时切换引用: \(tempRef ?? "无")")
            
            let defaults = getSharedDefaults()
            
            // 清除临时切换引用（不清除永久引用）
            defaults.removeObject(forKey: Keys.tempSwitchedReference)
            setTempSwitchedReference(nil)
            print("✓ 已清除临时切换引用")
            
            // 标记当天已刷新
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            defaults.set(today, forKey: Keys.lastDailyVerseRefreshDate)
            
            // 强制同步到磁盘
            defaults.synchronize()
            print("✓ 已同步到磁盘")
            
            // 确认临时引用已被清除
            let checkTempRef = getTempSwitchedReference()
            print("✓ 确认: 临时引用为 \(checkTempRef == nil ? "nil (已成功清除)" : checkTempRef!)")
            
            // 获取今日经文并缓存
            print("📆 正在获取今日经文...")
            if let verse = getVerseForToday() {
                print("✓ 已获取今日经文: \(verse.reference)")
                
                // 缓存今日经文
                cacheCurrentVerse(verse)
                print("✓ 已缓存今日经文")
                
                // 强制通知Widget更新
                WidgetCenter.shared.reloadAllTimelines()
                print("📢 已通知Widget更新")
                
                // 延迟再次检查，确保数据一致性
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let currentVerse = self.getCurrentVerseToDisplay() {
                        print("🔍 最终确认: 当前显示经文 \(currentVerse.reference)")
                    }
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } else {
                print("❌ 无法获取今日经文，重置失败")
            }
        } else {
            print("⚠️ 当前模式不支持重置当日经文：" + 
                 (getUpdateMode() == "automatic" ? "自动模式但已固定经文" : "手动模式"))
        }
    }
    
    // 获取默认经文
    public func getDefaultVerse() -> MultiLanguageVerse {
        print("📚 返回默认经文 John 3:16")
        
        return MultiLanguageVerse(
            reference: "John 3:16",
            cn: "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不致灭亡，反得永生。",
            en: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
            kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라."
        )
    }
}
