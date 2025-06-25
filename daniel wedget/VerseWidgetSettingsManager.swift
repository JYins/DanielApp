//
//  VerseWidgetSettingsManager.swift
//  daniel wedgetExtension
//
//  Widget独立设置管理器
//  完全独立于主应用的UserDefaults
//

import Foundation
import WidgetKit

class VerseWidgetSettingsManager {
    
    // MARK: - 初始化
    private init() {
        VerseWidgetSettingsManager.initializeDefaultSettings()
    }
    
    /// Widget独立的UserDefaults
    private static var widgetDefaults: UserDefaults {
        return UserDefaults.standard
    }
    
    // MARK: - 默认设置初始化
    static func initializeDefaultSettings() {
        let defaults = widgetDefaults
        
        // 设置默认语言
        if defaults.string(forKey: Keys.widgetLanguage) == nil {
            defaults.set("zh-CN", forKey: Keys.widgetLanguage)
            print("🔧 设置默认Widget语言: zh-CN")
        }
        
        // 设置默认更新模式
        if defaults.string(forKey: Keys.widgetUpdateMode) == nil {
            defaults.set("daily", forKey: Keys.widgetUpdateMode)
            print("🔧 设置默认Widget更新模式: daily")
        }
    }
    
    // MARK: - 语言设置
    static func getPreferredLanguage() -> String {
        initializeDefaultSettings()
        return widgetDefaults.string(forKey: Keys.widgetLanguage) ?? "zh-CN"
    }
    
    static func setPreferredLanguage(_ language: String) {
        widgetDefaults.set(language, forKey: Keys.widgetLanguage)
        print("🔧 Widget语言设置已更新为: \(language)")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - 更新模式设置
    static func getUpdateMode() -> String {
        initializeDefaultSettings()
        return widgetDefaults.string(forKey: Keys.widgetUpdateMode) ?? "daily"
    }
    
    static func setUpdateMode(_ mode: String) {
        widgetDefaults.set(mode, forKey: Keys.widgetUpdateMode)
        print("🔧 Widget更新模式已设置为: \(mode)")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - 最后更新时间
    static func getLastUpdateTime() -> Date? {
        return widgetDefaults.object(forKey: Keys.widgetLastUpdate) as? Date
    }
    
    static func setLastUpdateTime(_ date: Date) {
        widgetDefaults.set(date, forKey: Keys.widgetLastUpdate)
        print("🔧 Widget最后更新时间已记录: \(date)")
    }
    
    // MARK: - 数据版本管理
    static func getDataVersion() -> String {
        return widgetDefaults.string(forKey: Keys.widgetDataVersion) ?? "1.0.0"
    }
    
    static func setDataVersion(_ version: String) {
        widgetDefaults.set(version, forKey: Keys.widgetDataVersion)
        print("🔧 Widget数据版本已更新为: \(version)")
    }
    
    // MARK: - 重置所有设置
    static func resetAllSettings() {
        let defaults = widgetDefaults
        defaults.removeObject(forKey: Keys.widgetLanguage)
        defaults.removeObject(forKey: Keys.widgetUpdateMode)
        defaults.removeObject(forKey: Keys.widgetLastUpdate)
        defaults.removeObject(forKey: Keys.widgetDataVersion)
        defaults.removeObject(forKey: Keys.migrationCompleted)
        
        print("🔧 所有Widget设置已重置")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - 设置迁移
    static func migrateFromMainAppIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Keys.migrationCompleted) else {
            print("🔧 Widget 设置迁移已完成，跳过")
            return
        }
        
        print("🔧 开始从主应用迁移 Widget 设置...")
        
        // 尝试从主应用的 UserDefaults 获取设置
        let appGroupDefaults = UserDefaults(suiteName: "group.yinshi.DanielApp")
        
        // 迁移语言设置
        if let mainAppLanguage = appGroupDefaults?.string(forKey: "preferredLanguage") {
            setPreferredLanguage(mainAppLanguage)
            print("🔧 已迁移语言设置: \(mainAppLanguage)")
        }
        
        // 迁移更新模式设置
        if let mainAppUpdateMode = appGroupDefaults?.string(forKey: "updateMode") {
            setUpdateMode(mainAppUpdateMode)
            print("🔧 已迁移更新模式设置: \(mainAppUpdateMode)")
        }
        
        // 标记迁移完成
        UserDefaults.standard.set(true, forKey: Keys.migrationCompleted)
        print("🔧 Widget 设置迁移完成")
    }
    
    // MARK: - 调试信息
    static func getDebugInfo() -> String {
        let language = getPreferredLanguage()
        let updateMode = getUpdateMode()
        let lastUpdate = getLastUpdateTime()
        let dataVersion = getDataVersion()
        
        return """
        语言: \(language)
        更新模式: \(updateMode)
        最后更新: \(lastUpdate?.description ?? "无")
        数据版本: \(dataVersion)
        """
    }
    
    // MARK: - 私有键定义
    private struct Keys {
        static let widgetLanguage = "widget_language"
        static let widgetUpdateMode = "widget_update_mode"
        static let widgetLastUpdate = "widget_last_update"
        static let widgetDataVersion = "widget_data_version"
        static let migrationCompleted = "widget_migration_completed"
    }
    
    // MARK: - 兼容性方法（已弃用）
    @available(*, deprecated, message: "使用新的Widget独立设置方法")
    static func setCurrentVerse(_ verse: [String: Any]) {
        // 为了向后兼容而保留，但不实现功能
        print("⚠️ setCurrentVerse方法已弃用，请使用新的Widget独立数据管理")
    }
} 