import Foundation
import WidgetKit

// Widget设置管理器 - 用于在App和Widget之间共享设置
public struct VerseWidgetSettingsManager {
    // 静态实例
    public static let shared = VerseWidgetSettingsManager()
    
    // App Group标识符 - 必须与主应用相同
    private static let appGroupIdentifier = "group.com.daniel.DanielApp"
    
    // UserDefaults键 - 与VerseData.swift中定义的保持一致
    private struct Keys {
        static let selectedLanguage = "selectedLanguage"
        static let updateMode = "updateMode"
        static let currentVerseReference = "currentVerseReference"
        static let isVerseFixed = "isVerseFixed"
    }
    
    // 获取共享UserDefaults - 直接通过App Group标识符获取
    private static func getSharedDefaults() -> UserDefaults {
        print("Widget尝试获取共享UserDefaults，App Group: \(appGroupIdentifier)")
        if let defaults = UserDefaults(suiteName: appGroupIdentifier) {
            print("✅ 成功获取App Group UserDefaults")
            
            // 调试：输出所有已保存的键
            print("👀 UserDefaults中的键:")
            for key in defaults.dictionaryRepresentation().keys {
                print(" - \(key)")
            }
            
            return defaults
        } else {
            print("⚠️ 无法获取App Group UserDefaults")
            print("🔍 检查应用扩展Entitlements文件")
            print("🔍 App Group ID: \(appGroupIdentifier)")
            
            // 尝试检查entitlements文件
            if let bundleId = Bundle.main.bundleIdentifier {
                print("🔍 Bundle ID: \(bundleId)")
            }
            
            return UserDefaults.standard
        }
    }
    
    // 获取偏好语言设置
    public static func getPreferredLanguage() -> CoreModels.VerseLanguage {
        let defaults = getSharedDefaults()
        let savedValue = defaults.string(forKey: Keys.selectedLanguage)
        
        if let savedValue = savedValue, let language = CoreModels.VerseLanguage(rawValue: savedValue) {
            return language
        }
        
        // 默认使用中文
        return .chinese
    }
    
    // 设置偏好语言
    public static func setPreferredLanguage(_ language: CoreModels.VerseLanguage) {
        let defaults = getSharedDefaults()
        defaults.set(language.rawValue, forKey: Keys.selectedLanguage)
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 获取更新模式 (automatic/manual)
    public static func getUpdateMode() -> String {
        let defaults = getSharedDefaults()
        return defaults.string(forKey: Keys.updateMode) ?? "automatic"
    }
    
    // 设置更新模式
    public static func setUpdateMode(_ mode: String) {
        let defaults = getSharedDefaults()
        defaults.set(mode, forKey: Keys.updateMode)
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 获取当前选择的经文引用
    public static func getCurrentVerseReference() -> String? {
        let defaults = getSharedDefaults()
        return defaults.string(forKey: Keys.currentVerseReference)
    }
    
    // 设置当前选择的经文引用
    public static func setCurrentVerseReference(_ reference: String?) {
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
    public static func getTempSwitchedReference() -> String? {
        let defaults = getSharedDefaults()
        return defaults.string(forKey: "tempSwitchedReference")
    }
    
    // 设置临时切换的经文引用（仅自动模式当天有效）
    public static func setTempSwitchedReference(_ reference: String?) {
        let defaults = getSharedDefaults()
        
        if let reference = reference {
            defaults.set(reference, forKey: "tempSwitchedReference")
        } else {
            defaults.removeObject(forKey: "tempSwitchedReference")
        }
        
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 获取经文是否被固定
    public static func isVerseFixed() -> Bool {
        let defaults = getSharedDefaults()
        return defaults.bool(forKey: Keys.isVerseFixed)
    }
    
    // 设置经文是否被固定
    public static func setVerseFixed(_ fixed: Bool) {
        let defaults = getSharedDefaults()
        defaults.set(fixed, forKey: Keys.isVerseFixed)
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
} 