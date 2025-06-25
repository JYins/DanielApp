import Foundation
import WidgetKit
import BackgroundTasks

/// Widget生命周期管理器
/// 负责处理Widget的自动更新、后台刷新等生命周期相关任务
public class WidgetLifecycleManager {
    
    // MARK: - 单例
    public static let shared = WidgetLifecycleManager()
    
    // MARK: - 属性
    private let backgroundTaskIdentifier = "com.daniel.DanielApp.widget.refresh"
    
    // MARK: - 初始化
    private init() {
        setupBackgroundRefresh()
    }
    
    // MARK: - 后台刷新设置
    
    /// 设置后台刷新任务
    private func setupBackgroundRefresh() {
        print("🔄 设置Widget后台刷新任务")
        
        // 注册后台任务（虽然Widget本身有限制，但可以尝试）
        if #available(iOS 13.0, *) {
            let identifier = backgroundTaskIdentifier
            print("📝 注册后台任务ID: \(identifier)")
        }
    }
    
    // MARK: - 自动更新管理
    
    /// 触发Widget立即更新
    public func triggerImmediateUpdate() {
        print("⚡ 触发Widget立即更新")
        WidgetCenter.shared.reloadAllTimelines()
        
        // 记录更新时间
        UserDefaults(suiteName: "group.com.daniel.DanielApp")?.set(Date(), forKey: "lastWidgetUpdate")
    }
    
    /// 检查是否需要更新Widget
    public func checkAndUpdateIfNeeded() {
        print("🔍 检查Widget是否需要更新")
        
        let now = Date()
        let calendar = Calendar.current
        
        // 获取上次更新时间
        let defaults = UserDefaults(suiteName: "group.com.daniel.DanielApp")
        let lastUpdate = defaults?.object(forKey: "lastWidgetUpdate") as? Date ?? Date.distantPast
        
        // 检查是否跨天了
        let isSameDay = calendar.isDate(now, inSameDayAs: lastUpdate)
        
        if !isSameDay {
            print("📅 检测到跨天，需要更新Widget")
            triggerImmediateUpdate()
            return
        }
        
        // 检查是否到了背景变化时间
        let hour = calendar.component(.hour, from: now)
        let lastHour = calendar.component(.hour, from: lastUpdate)
        
        let backgroundChangeHours = [5, 10, 18] // 5:00, 10:00, 18:00
        
        for changeHour in backgroundChangeHours {
            if hour >= changeHour && lastHour < changeHour {
                print("🎨 检测到背景变化时间点，需要更新Widget")
                triggerImmediateUpdate()
                return
            }
        }
        
        print("✅ Widget无需更新")
    }
    
    // MARK: - 时间线管理
    
    /// 计算下次更新时间
    public func calculateNextUpdateTime() -> Date {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        
        // 背景变化时间点：5:00, 10:00, 18:00
        let backgroundChangeHours = [5, 10, 18]
        
        // 找到下一个背景变化时间
        var nextBackgroundHour: Int?
        for changeHour in backgroundChangeHours {
            if hour < changeHour {
                nextBackgroundHour = changeHour
                break
            }
        }
        
        // 如果当天没有更多的背景变化时间，则设为明天5:00
        if nextBackgroundHour == nil {
            nextBackgroundHour = 5
        }
        
        // 计算下次背景变化时间
        var nextBackgroundDate: Date?
        if let changeHour = nextBackgroundHour {
            if changeHour > hour {
                // 今天的变化时间
                nextBackgroundDate = calendar.date(bySettingHour: changeHour, minute: 0, second: 0, of: now)
            } else {
                // 明天的变化时间
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
                nextBackgroundDate = calendar.date(bySettingHour: changeHour, minute: 0, second: 0, of: tomorrow)
            }
        }
        
        // 计算明天午夜0:00（经文更新时间）
        let tomorrowMidnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        
        // 返回最近的更新时间
        if let backgroundDate = nextBackgroundDate, backgroundDate < tomorrowMidnight {
            print("🎨 下次更新时间: \(backgroundDate) (背景变化)")
            return backgroundDate
        } else {
            print("🕛 下次更新时间: \(tomorrowMidnight) (午夜经文更新)")
            return tomorrowMidnight
        }
    }
    
    // MARK: - 数据同步
    
    /// 同步数据状态（确保Widget数据是最新的）
    public func syncDataState() {
        print("🔄 同步Widget数据状态")
        
        let dataManager = WidgetDataManager.shared
        if !dataManager.isDataReady() {
            print("⚠️ Widget数据未就绪，尝试重新加载")
            dataManager.reloadData()
        }
        
        // 检查数据是否过期（比如超过24小时没有更新）
        let defaults = UserDefaults(suiteName: "group.com.daniel.DanielApp")
        if let lastDataUpdate = defaults?.object(forKey: "lastDataUpdate") as? Date {
            let hoursSinceUpdate = Date().timeIntervalSince(lastDataUpdate) / 3600
            if hoursSinceUpdate > 24 {
                print("⚠️ 数据超过24小时未更新，建议刷新")
                // 这里可以添加数据刷新逻辑
            }
        }
    }
    
    // MARK: - 调试工具
    
    /// 获取Widget状态信息
    public func getWidgetStatus() -> String {
        let dataManager = WidgetDataManager.shared
        let now = Date()
        let nextUpdate = calculateNextUpdateTime()
        
        return """
        Widget生命周期状态:
        - 当前时间: \(now)
        - 下次更新: \(nextUpdate)
        - 数据状态: \(dataManager.isDataReady() ? "就绪" : "未就绪")
        - 经文数量: \(dataManager.getVersesCount())
        - 今日经文: \(dataManager.getTodaysVerse().reference)
        """
    }
    
    /// 强制刷新所有Widget数据
    public func forceRefreshAll() {
        print("🔥 强制刷新所有Widget数据")
        
        // 重新加载数据
        WidgetDataManager.shared.reloadData()
        
        // 立即更新Widget
        triggerImmediateUpdate()
        
        // 同步数据状态
        syncDataState()
        
        print("✅ 强制刷新完成")
    }
} 