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
        let now = Date()
        print("⚡ 触发Widget立即更新 - 时间: \(now)")
        
        // 记录更新时间和详细信息
        let defaults = UserDefaults(suiteName: "group.com.daniel.DanielApp")
        defaults?.set(now, forKey: "lastWidgetUpdate")
        defaults?.set(now.timeIntervalSince1970, forKey: "lastWidgetUpdateTimestamp")
        
        // 记录更新计数
        let updateCount = defaults?.integer(forKey: "widgetUpdateCount") ?? 0
        defaults?.set(updateCount + 1, forKey: "widgetUpdateCount")
        
        // 强制同步UserDefaults
        defaults?.synchronize()
        
        print("📊 更新记录: 第\(updateCount + 1)次更新，时间戳: \(now.timeIntervalSince1970)")
        
        // 触发Widget时间线重新加载
        WidgetCenter.shared.reloadAllTimelines()
        
        print("✅ Widget时间线重新加载完成")
    }
    
    /// 检查是否需要更新Widget
    public func checkAndUpdateIfNeeded() {
        print("🔍 检查Widget是否需要更新")
        
        let now = Date()
        let calendar = Calendar.current
        
        // 获取上次更新时间
        let defaults = UserDefaults(suiteName: "group.com.daniel.DanielApp")
        let lastUpdate = defaults?.object(forKey: "lastWidgetUpdate") as? Date ?? Date.distantPast
        
        print("⏰ 当前时间: \(now)")
        print("⏰ 上次更新: \(lastUpdate)")
        
        // 检查是否跨天了 - 使用多重检测机制确保可靠性
        let isSameDay = calendar.isDate(now, inSameDayAs: lastUpdate)
        let currentDay = calendar.component(.day, from: now)
        let lastUpdateDay = calendar.component(.day, from: lastUpdate)
        let daysDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastUpdate), to: calendar.startOfDay(for: now)).day ?? 0
        
        print("📅 日期检测: 同一天=\(isSameDay), 当前日=\(currentDay), 上次日=\(lastUpdateDay), 天数差=\(daysDifference)")
        
        // 如果检测到跨天（使用多重条件确保准确性）
        if !isSameDay || daysDifference > 0 || currentDay != lastUpdateDay {
            print("📅 检测到跨天，需要更新Widget")
            print("🔄 触发原因: 同一天=\(isSameDay), 天数差=\(daysDifference), 日期变化=\(currentDay != lastUpdateDay)")
            
            // 记录跨天更新事件
            defaults?.set("midnight_update", forKey: "lastUpdateReason")
            defaults?.set(now, forKey: "lastMidnightUpdate")
            
            triggerImmediateUpdate()
            return
        }
        
        // 检查是否到了背景变化时间
        let hour = calendar.component(.hour, from: now)
        let lastHour = calendar.component(.hour, from: lastUpdate)
        
        let backgroundChangeHours = [5, 10, 18] // 5:00, 10:00, 18:00
        
        print("🕐 时间检测: 当前小时=\(hour), 上次小时=\(lastHour)")
        
        for changeHour in backgroundChangeHours {
            if hour >= changeHour && lastHour < changeHour {
                print("🎨 检测到背景变化时间点(\(changeHour):00)，需要更新Widget")
                
                // 记录背景变化更新事件
                defaults?.set("background_change", forKey: "lastUpdateReason")
                
                triggerImmediateUpdate()
                return
            }
        }
        
        // 额外检查：如果上次更新超过25小时，强制更新（防止意外情况）
        let hoursSinceLastUpdate = now.timeIntervalSince(lastUpdate) / 3600
        if hoursSinceLastUpdate > 25 {
            print("⚠️ 上次更新超过25小时(\(String(format: "%.1f", hoursSinceLastUpdate))小时)，强制更新")
            
            // 记录强制更新事件
            defaults?.set("force_update", forKey: "lastUpdateReason")
            
            triggerImmediateUpdate()
            return
        }
        
        print("✅ Widget无需更新 (距上次更新\(String(format: "%.1f", hoursSinceLastUpdate))小时)")
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
} 