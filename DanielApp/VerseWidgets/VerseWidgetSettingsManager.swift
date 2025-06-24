import Foundation
import WidgetKit

// Widget设置管理器
public struct VerseWidgetSettingsManager {
    // 静态实例
    public static let shared = VerseWidgetSettingsManager()
    
    // App Group标识符 - 必须与主应用相同
    private let appGroupIdentifier = "group.com.daniel.DanielApp"
    
    // UserDefaults键 - 与VerseData.swift中定义的保持一致
    private struct Keys {
        static let selectedLanguage = "selectedLanguage"
        static let updateMode = "updateMode"
        static let currentVerseReference = "currentVerseReference"
        static let isVerseFixed = "isVerseFixed"
    }
    
    // 获取共享UserDefaults
    private func getSharedDefaults() -> UserDefaults {
        if let suiteName = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String {
            return UserDefaults(suiteName: suiteName) ?? UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
        }
        return UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
    }
    
    // 获取偏好语言设置
    public static func getPreferredLanguage() -> CoreModels.VerseLanguage {
        let defaults = shared.getSharedDefaults()
        let savedValue = defaults.string(forKey: Keys.selectedLanguage)
        
        if let savedValue = savedValue, let language = CoreModels.VerseLanguage(rawValue: savedValue) {
            return language
        }
        
        // 默认使用中文
        return .chinese
    }
    
    // 设置偏好语言
    public static func setPreferredLanguage(_ language: CoreModels.VerseLanguage) {
        let defaults = shared.getSharedDefaults()
        defaults.set(language.rawValue, forKey: Keys.selectedLanguage)
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 获取更新模式
    public static func getUpdateMode() -> String {
        let defaults = shared.getSharedDefaults()
        return defaults.string(forKey: Keys.updateMode) ?? "automatic"
    }
    
    // 设置更新模式
    public static func setUpdateMode(_ mode: String) {
        let defaults = shared.getSharedDefaults()
        defaults.set(mode, forKey: Keys.updateMode)
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 获取当前选择的经文引用
    public static func getCurrentVerseReference() -> String? {
        let defaults = shared.getSharedDefaults()
        return defaults.string(forKey: Keys.currentVerseReference)
    }
    
    // 设置当前选择的经文引用
    public static func setCurrentVerseReference(_ reference: String?) {
        let defaults = shared.getSharedDefaults()
        
        if let reference = reference {
            defaults.set(reference, forKey: Keys.currentVerseReference)
        } else {
            defaults.removeObject(forKey: Keys.currentVerseReference)
        }
        
        defaults.synchronize()
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 获取经文是否被固定
    public static func isVerseFixed() -> Bool {
        let defaults = shared.getSharedDefaults()
        return defaults.bool(forKey: Keys.isVerseFixed)
    }
    
    // 设置经文是否被固定
    public static func setVerseFixed(_ fixed: Bool) {
        let defaults = shared.getSharedDefaults()
        defaults.set(fixed, forKey: Keys.isVerseFixed)
        defaults.synchronize()
        
        // 如果取消固定且处于自动模式，不要立即清除引用
        // 而是保留当前经文直到下一天自动刷新
        if !fixed && getUpdateMode() == "automatic" {
            print("已取消固定经文，但保留当前经文引用直到下一天自动刷新")
        }
        
        // 重新加载所有Widget时间线
        WidgetCenter.shared.reloadAllTimelines()
    }
}