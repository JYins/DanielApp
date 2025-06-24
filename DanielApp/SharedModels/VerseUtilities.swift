import Foundation
import SwiftUI

// 共享工具类，用于存放Widget和主应用共用的函数
public struct VerseUtilities {
    // 从JSON加载经文数据的工具函数
    public static func loadVersesFromJson() -> [MultiLanguageVerse]? {
        print("VerseUtilities: Attempting to load verses_merged.json from Bundle.main")
        guard let url = Bundle.main.url(forResource: "verses_merged", withExtension: "json") else {
            print("VerseUtilities: ERROR - Could not find verses_merged.json in Bundle.main. Resource path: \(Bundle.main.resourcePath ?? "nil")")
            // Let's list JSON files in the bundle for debugging
            listBundleJsonFiles(bundle: Bundle.main)
            return nil
        }
        
        print("VerseUtilities: Found URL for verses_merged.json: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
            print("VerseUtilities: Successfully read data from verses_merged.json (\(data.count) bytes)")
            let verses = try JSONDecoder().decode([MultiLanguageVerse].self, from: data)
            print("VerseUtilities: Successfully parsed \(verses.count) verses from verses_merged.json")
            return verses
        } catch let DecodingError.dataCorrupted(context) {
            print("VerseUtilities: ERROR - JSON Data Corrupted while parsing verses_merged.json: \(context)")
            return nil
        } catch let DecodingError.keyNotFound(key, context) {
            print("VerseUtilities: ERROR - JSON Key Not Found while parsing verses_merged.json: Key '\(key)' not found: \(context.debugDescription)")
            print("codingPath: \(context.codingPath)")
            return nil
        } catch let DecodingError.valueNotFound(value, context) {
            print("VerseUtilities: ERROR - JSON Value Not Found while parsing verses_merged.json: Value '\(value)' not found: \(context.debugDescription)")
            print("codingPath: \(context.codingPath)")
            return nil
        } catch let DecodingError.typeMismatch(type, context)  {
            print("VerseUtilities: ERROR - JSON Type Mismatch while parsing verses_merged.json: Type '\(type)' mismatch: \(context.debugDescription)")
            print("codingPath: \(context.codingPath)")
            return nil
        } catch {
            print("VerseUtilities: ERROR - Generic error parsing verses_merged.json: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 从JSON加载经文索引列表
    public static func loadVerseIndexList() -> [String]? {
        print("VerseUtilities: Attempting to load verses_index.json from Bundle.main")
        guard let url = Bundle.main.url(forResource: "verses_index", withExtension: "json") else {
            print("VerseUtilities: ERROR - Could not find verses_index.json in Bundle.main. Resource path: \(Bundle.main.resourcePath ?? "nil")")
             // Let's list JSON files in the bundle for debugging
            listBundleJsonFiles(bundle: Bundle.main)
            return nil
        }
        
        print("VerseUtilities: Found URL for verses_index.json: \(url.path)")
        
        do {
            let data = try Data(contentsOf: url)
             print("VerseUtilities: Successfully read data from verses_index.json (\(data.count) bytes)")
            let indices = try JSONDecoder().decode([String].self, from: data)
            print("VerseUtilities: Successfully parsed \(indices.count) indices from verses_index.json")
            return indices
        } catch let DecodingError.dataCorrupted(context) {
            print("VerseUtilities: ERROR - JSON Data Corrupted while parsing verses_index.json: \(context)")
            return nil
        } catch let DecodingError.keyNotFound(key, context) {
            print("VerseUtilities: ERROR - JSON Key Not Found while parsing verses_index.json: Key '\(key)' not found: \(context.debugDescription)")
            print("codingPath: \(context.codingPath)")
            return nil
        } catch let DecodingError.valueNotFound(value, context) {
            print("VerseUtilities: ERROR - JSON Value Not Found while parsing verses_index.json: Value '\(value)' not found: \(context.debugDescription)")
            print("codingPath: \(context.codingPath)")
            return nil
        } catch let DecodingError.typeMismatch(type, context)  {
            print("VerseUtilities: ERROR - JSON Type Mismatch while parsing verses_index.json: Type '\(type)' mismatch: \(context.debugDescription)")
            print("codingPath: \(context.codingPath)")
            return nil
        } catch {
            print("VerseUtilities: ERROR - Generic error parsing verses_index.json: \(error.localizedDescription)")
            return nil
        }
    }

    // 辅助函数：列出 Bundle 中的 JSON 文件
    private static func listBundleJsonFiles(bundle: Bundle) {
        let fileManager = FileManager.default
        print("VerseUtilities: Listing JSON files in bundle: \(bundle.bundlePath)")
        guard let resourcePath = bundle.resourcePath else {
            print("VerseUtilities: Could not get resource path for bundle.")
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(atPath: resourcePath)
            let jsonFiles = contents.filter { $0.hasSuffix(".json") }
            if jsonFiles.isEmpty {
                print("VerseUtilities: No JSON files found in bundle resource path.")
            } else {
                print("VerseUtilities: Found JSON files:")
                for file in jsonFiles {
                    print("  - \(file)")
                }
            }
        } catch {
            print("VerseUtilities: ERROR - Could not list directory contents for resource path \(resourcePath): \(error)")
        }
    }
    
    // 计算当年中的第几天（1-366）
    public static func getDayOfYear(from date: Date) -> Int {
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return day
    }
    
    // 根据日期选择经文
    public static func selectVerseForDate(from verses: [MultiLanguageVerse], date: Date) -> MultiLanguageVerse? {
        guard !verses.isEmpty else {
            return nil
        }
        
        // 先尝试从索引列表获取
        if let indices = loadVerseIndexList(), !indices.isEmpty {
            // 计算当年中的第几天（1-366）
            let dayOfYear = getDayOfYear(from: date)
            
            // 使用当年日期作为索引，确保每天不同的经文
            let indexForToday = (dayOfYear - 1) % indices.count
            let referenceForToday = indices[indexForToday]
            
            // 查找对应的经文
            if let verse = verses.first(where: { $0.reference == referenceForToday }) {
                return verse
            } else {
                print("无法找到引用为 \(referenceForToday) 的经文")
            }
        }
        
        // 如果索引列表不可用或找不到对应经文，直接从所有经文中选择
        let dayOfYear = getDayOfYear(from: date)
        let index = (dayOfYear - 1) % verses.count
        return verses[index]
    }
    
    // 获取今天的完整经文
    public static func getVerseForToday() -> MultiLanguageVerse {
        if let verses = loadVersesFromJson(), !verses.isEmpty,
           let todayVerse = selectVerseForDate(from: verses, date: Date()) {
            return todayVerse
        } else {
            // 如果找不到，返回默认经文
            return MultiLanguageVerse(
                reference: "John 3:16",
                cn: "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不致灭亡，反得永生。",
                en: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
                kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라."
            )
        }
    }
    
    // 获取随机经文
    public static func getRandomVerse() -> MultiLanguageVerse {
        if let verses = loadVersesFromJson(), !verses.isEmpty {
            let randomIndex = Int.random(in: 0..<verses.count)
            return verses[randomIndex]
        } else {
            // 如果找不到，返回默认经文
            return MultiLanguageVerse(
                reference: "John 3:16",
                cn: "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不致灭亡，反得永生。",
                en: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
                kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라."
            )
        }
    }
    
    // 根据参考获取经文
    public static func getVerseByReference(_ reference: String) -> MultiLanguageVerse? {
        if let allVerses = loadVersesFromJson() {
            return allVerses.first { $0.reference == reference }
        }
        return nil
    }
}
