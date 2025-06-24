import Foundation
import WidgetKit
import UserNotifications
import UIKit

// 背景时间段管理器 - 专门处理Widget背景变化
class BackgroundTimePeriodManager {
    static let shared = BackgroundTimePeriodManager()
    
    private let updateHours = [5, 10, 18] // 5:00, 10:00, 18:00
    private var timers: [Timer] = []
    
    private init() {
        setupBackgroundUpdateTimers()
    }
    
    deinit {
        stopAllTimers()
    }
    
    /// 设置背景变化定时器
    private func setupBackgroundUpdateTimers() {
        print("🎨 设置背景变化定时器...")
        
        // 停止现有定时器
        stopAllTimers()
        
        for hour in updateHours {
            setupTimerForHour(hour)
        }
        
        print("✅ 背景变化定时器已设置，将在5:00、10:00、18:00自动更新")
    }
    
    private func setupTimerForHour(_ hour: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        // 计算下一个指定小时的时间
        var nextUpdate = calendar.dateInterval(of: .day, for: now)?.start ?? now
        nextUpdate = calendar.date(byAdding: .hour, value: hour, to: nextUpdate) ?? now
        
        // 如果今天的时间已经过了，设置为明天的同一时间
        if nextUpdate <= now {
            nextUpdate = calendar.date(byAdding: .day, value: 1, to: nextUpdate) ?? now
        }
        
        let timeInterval = nextUpdate.timeIntervalSince(now)
        
        let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.updateWidgetBackground(hour: hour)
            // 重新设置下一天的定时器
            self?.setupTimerForHour(hour)
        }
        
        timers.append(timer)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("🕐 设置背景更新定时器 - \(hour):00，下次更新时间: \(formatter.string(from: nextUpdate))")
    }
    
    /// 停止所有背景定时器
    private func stopAllTimers() {
        print("🛑 停止所有背景定时器")
        for timer in timers {
            timer.invalidate()
        }
        timers.removeAll()
    }
    
    /// 更新Widget背景
    private func updateWidgetBackground(hour: Int? = nil) {
        let currentHour = Calendar.current.component(.hour, from: Date())
        print("🎨 \(hour != nil ? "定时" : "手动")触发Widget背景更新... 当前时间:\(currentHour):xx")
        
        // 获取当前时间段
        let currentTimePeriod = getCurrentTimePeriod()
        print("⏰ 当前时间段: \(currentTimePeriod), 应显示背景: \(getBackgroundImageName(for: currentTimePeriod))")
        
        // 强制刷新Widget，让它重新获取当前时间段
        WidgetCenter.shared.reloadAllTimelines()
        print("📢 已通知Widget重载时间线")
        
        // 延迟再次刷新确保更新成功
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            WidgetCenter.shared.reloadAllTimelines()
            print("📢 第二次Widget刷新通知")
        }
        
        // 最终确认刷新
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            WidgetCenter.shared.reloadAllTimelines()
            let finalTimePeriod = self.getCurrentTimePeriod()
            print("✅ Widget背景更新完成 - 最终时间段: \(finalTimePeriod)")
        }
    }
    
    // 辅助方法：获取当前时间段
    private func getCurrentTimePeriod() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5..<10:
            return "morning"
        case 10..<18:
            return "daytime"
        default:
            return "nighttime"
        }
    }
    
    // 辅助方法：获取背景图片名称
    private func getBackgroundImageName(for timePeriod: String) -> String {
        switch timePeriod {
        case "morning":
            return "widget_background 1"
        case "daytime":
            return "widget_background"
        case "nighttime":
            return "widget_background 2"
        default:
            return "widget_background"
        }
    }
    
    /// 手动触发背景更新（用于测试）
    func forceBackgroundUpdate() {
        print("🔄 手动触发背景更新...")
        updateWidgetBackground()
    }
    
    /// 检查并报告定时器状态
    func reportTimerStatus() {
        print("📊 背景更新定时器状态报告:")
        print("   活跃定时器数量: \(timers.count)")
        
        for (index, timer) in timers.enumerated() {
            print("   定时器\(index + 1): \(timer.isValid ? "有效" : "无效")")
        }
    }
}

// 午夜更新管理器 - 负责定时更新和通知
class MidnightUpdateManager: NSObject {
    static let shared = MidnightUpdateManager()
    
    private var midnightTimer: Timer?
    private var preUpdateTimer: Timer?
    private var isUpdateScheduled = false
    
    private override init() {
        super.init()
        setupUpdateTimers()
        requestNotificationPermissions()
    }
    
    deinit {
        stopAllTimers()
    }
    
    // MARK: - 定时器管理
    
    /// 设置午夜更新定时器
    func setupUpdateTimers() {
        print("🕛 设置午夜更新定时器...")
        
        // 停止现有定时器
        stopAllTimers()
        
        let calendar = Calendar.current
        let now = Date()
        
        // 1. 设置保险刷新定时器 (每天23:50)
        setupPreUpdateTimer(at: now)
        
        // 2. 设置午夜刷新定时器 (每天0:00)
        setupMidnightTimer(at: now)
        
        print("✅ 午夜更新定时器已设置")
    }
    
    /// 设置保险刷新定时器 (23:50)
    private func setupPreUpdateTimer(at currentTime: Date) {
        let calendar = Calendar.current
        
        // 计算今天23:50的时间
        var components = calendar.dateComponents([.year, .month, .day], from: currentTime)
        components.hour = 23
        components.minute = 50
        components.second = 0
        
        var preUpdateTime = calendar.date(from: components)!
        
        // 如果今天23:50已经过了，设置为明天23:50
        if preUpdateTime <= currentTime {
            preUpdateTime = calendar.date(byAdding: .day, value: 1, to: preUpdateTime)!
        }
        
        let timeInterval = preUpdateTime.timeIntervalSince(currentTime)
        
        print("📅 保险刷新时间: \(formatTime(preUpdateTime))")
        print("⏳ 距离保险刷新: \(String(format: "%.1f", timeInterval/3600.0)) 小时")
        
        preUpdateTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            self.performPreMidnightUpdate()
            // 递归设置下一次保险刷新
            self.setupPreUpdateTimer(at: Date())
        }
    }
    
    /// 设置午夜刷新定时器 (0:00)
    private func setupMidnightTimer(at currentTime: Date) {
        let calendar = Calendar.current
        
        // 计算明天的午夜时间
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: currentTime))!
        let timeInterval = tomorrow.timeIntervalSince(currentTime)
        
        print("🌙 午夜刷新时间: \(formatTime(tomorrow))")
        print("⏳ 距离午夜刷新: \(String(format: "%.1f", timeInterval/3600.0)) 小时")
        
        midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            self.performMidnightUpdate()
            // 递归设置下一次午夜刷新
            self.setupMidnightTimer(at: Date())
        }
    }
    
    /// 停止所有定时器
    func stopAllTimers() {
        print("🛑 停止所有更新定时器")
        midnightTimer?.invalidate()
        midnightTimer = nil
        preUpdateTimer?.invalidate()
        preUpdateTimer = nil
        isUpdateScheduled = false
    }
    
    // MARK: - 更新执行
    
    /// 执行保险刷新 (23:50)
    @objc private func performPreMidnightUpdate() {
        print("🚨 执行保险刷新 (23:50)...")
        
        let updateMode = VerseDataService.shared.getUpdateMode()
        let isFixed = VerseDataService.shared.isVerseFixed()
        
        // 只有在自动模式且非固定状态下才进行保险刷新
        if updateMode == "automatic" && !isFixed {
            print("✅ 满足保险刷新条件，开始准备明日经文...")
            
            // 1. 预加载明日经文
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            if let tomorrowVerse = VerseDataService.shared.getVerseForDate(tomorrow) {
                print("📖 预加载明日经文: \(tomorrowVerse.reference)")
                
                // 暂存明日经文到特殊键，等午夜时正式启用
                let defaults = VerseDataService.shared.getSharedDefaults()
                if let encoded = try? JSONEncoder().encode(tomorrowVerse) {
                    defaults.set(encoded, forKey: "tomorrowVersePreloaded")
                    defaults.synchronize()
                    print("💾 已预缓存明日经文")
                }
            }
            
            // 2. 清理临时数据，准备状态重置
            print("🧹 准备清理临时状态...")
            
            // 3. 确保Widget数据同步
            WidgetCenter.shared.reloadAllTimelines()
            print("📢 已刷新Widget，为午夜更新做准备")
            
        } else {
            print("⏸️ 当前模式不需要保险刷新 - 模式:\(updateMode), 固定:\(isFixed)")
        }
        
        print("✅ 保险刷新完成")
    }
    
    /// 执行午夜更新 (0:00)
    @objc private func performMidnightUpdate() {
        print("🌙 执行午夜更新 (0:00)...")
        
        let updateMode = VerseDataService.shared.getUpdateMode()
        let isFixed = VerseDataService.shared.isVerseFixed()
        
        // 只有在自动模式且非固定状态下才进行午夜刷新
        if updateMode == "automatic" && !isFixed {
            print("✅ 满足午夜刷新条件，开始执行完整更新...")
            
            // 1. 清除昨日状态
            let defaults = VerseDataService.shared.getSharedDefaults()
            
            // 清除临时切换引用
            let tempRef = defaults.string(forKey: "tempSwitchedReference")
            if tempRef != nil {
                defaults.removeObject(forKey: "tempSwitchedReference")
                print("🧹 已清除昨日临时切换引用: \(tempRef!)")
            }
            
            // 清除用户选择的永久引用（仅自动模式）
            let currentRef = defaults.string(forKey: "currentVerseReference")
            if currentRef != nil {
                defaults.removeObject(forKey: "currentVerseReference")
                print("🧹 已清除昨日永久引用: \(currentRef!)")
            }
            
            // 2. 尝试使用预加载的明日经文
            var newVerse: MultiLanguageVerse?
            
            if let preloadedData = defaults.data(forKey: "tomorrowVersePreloaded"),
               let preloadedVerse = try? JSONDecoder().decode(MultiLanguageVerse.self, from: preloadedData) {
                print("✅ 使用预加载的明日经文: \(preloadedVerse.reference)")
                newVerse = preloadedVerse
                
                // 清除预加载数据
                defaults.removeObject(forKey: "tomorrowVersePreloaded")
            } else {
                // 实时获取今日经文
                print("📆 实时获取今日经文...")
                newVerse = VerseDataService.shared.getVerseForToday()
            }
            
            // 3. 缓存新经文并更新状态
            if let verse = newVerse {
                print("✅ 获取新的每日经文: \(verse.reference)")
                
                // 缓存经文
                VerseDataService.shared.cacheCurrentVerse(verse)
                
                // 更新刷新日期
                let today = Calendar.current.startOfDay(for: Date())
                defaults.set(today, forKey: "lastDailyVerseRefreshDate")
                defaults.synchronize()
                
                print("💾 已缓存新经文并更新刷新日期")
                
                // 4. 发送每日经文通知
                scheduleVerseNotification(verse: verse)
                
                // 5. 通知Widget更新
                WidgetCenter.shared.reloadAllTimelines()
                print("📢 已通知Widget更新")
                
                // 延迟再次通知，确保更新成功
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    WidgetCenter.shared.reloadAllTimelines()
                    print("📢 第二次Widget更新通知")
                }
                
                // 额外延迟刷新，确保背景时间段也正确更新
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    WidgetCenter.shared.reloadAllTimelines()
                    print("🎨 第三次Widget更新通知 - 确保背景正确")
                }
                
            } else {
                print("❌ 无法获取新的每日经文")
            }
            
        } else {
            print("⏸️ 当前模式不需要午夜刷新 - 模式:\(updateMode), 固定:\(isFixed)")
        }
        
        print("✅ 午夜更新完成")
    }
    
    // MARK: - 通知管理
    
    /// 请求通知权限
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 通知权限已获取")
                } else {
                    print("❌ 通知权限被拒绝: \(error?.localizedDescription ?? "未知错误")")
                }
            }
        }
    }
    
    /// 发送每日经文通知
    private func scheduleVerseNotification(verse: MultiLanguageVerse) {
        print("📮 准备发送每日经文通知...")
        
        let language = VerseDataService.shared.getSelectedLanguage()
        let verseText = getVerseText(verse, language: language)
        let localizedReference = CoreModels.VerseLanguage.localizeReference(verse.reference, to: language)
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        
        // 根据语言设置标题
        switch language {
        case .chinese:
            content.title = "今日经文 📖"
            content.subtitle = localizedReference
        case .english:
            content.title = "Verse of the Day 📖"
            content.subtitle = localizedReference
        case .korean:
            content.title = "오늘의 말씀 📖"
            content.subtitle = localizedReference
        }
        
        content.body = verseText
        content.sound = .default
        content.badge = 1
        
        // 设置通知在1秒后触发（立即通知）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // 创建通知请求
        let request = UNNotificationRequest(
            identifier: "dailyVerse-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        // 发送通知
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ 通知发送失败: \(error.localizedDescription)")
                } else {
                    print("✅ 每日经文通知已发送")
                    print("   📖 标题: \(content.title)")
                    print("   📄 副标题: \(content.subtitle)")
                    print("   📝 内容: \(verseText.prefix(50))...")
                }
            }
        }
    }
    
    /// 手动触发立即更新（用于测试）
    func forceUpdate() {
        print("🔄 手动触发午夜更新...")
        performMidnightUpdate()
    }
    
    /// 手动触发保险更新（用于测试）
    func forcePreUpdate() {
        print("🔄 手动触发保险更新...")
        performPreMidnightUpdate()
    }
    
    // MARK: - 工具函数
    
    /// 格式化时间
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    /// 根据语言获取经文文本
    private func getVerseText(_ verse: MultiLanguageVerse, language: CoreModels.VerseLanguage) -> String {
        switch language {
        case .chinese: return verse.cn
        case .english: return verse.en
        case .korean: return verse.kr
        }
    }
    
    /// 检查更新状态
    func checkUpdateStatus() {
        print("🔍 检查更新状态...")
        print("   📅 午夜定时器: \(midnightTimer != nil ? "运行中" : "已停止")")
        print("   📅 保险定时器: \(preUpdateTimer != nil ? "运行中" : "已停止")")
        print("   📅 更新已调度: \(isUpdateScheduled ? "是" : "否")")
        
        if let timer = midnightTimer, timer.isValid {
            let fireDate = timer.fireDate
            let interval = fireDate.timeIntervalSince(Date())
            print("   ⏰ 下次午夜更新: \(formatTime(fireDate)) (还有 \(String(format: "%.1f", interval/3600.0)) 小时)")
        }
        
        if let timer = preUpdateTimer, timer.isValid {
            let fireDate = timer.fireDate
            let interval = fireDate.timeIntervalSince(Date())
            print("   ⏰ 下次保险更新: \(formatTime(fireDate)) (还有 \(String(format: "%.1f", interval/3600.0)) 小时)")
        }
    }
}

// MARK: - 应用生命周期扩展

extension MidnightUpdateManager {
    
    /// 应用进入后台时调用
    func applicationDidEnterBackground() {
        print("📱 应用进入后台，保持定时器运行")
        // 定时器会继续在后台运行，直到系统终止应用
    }
    
    /// 应用回到前台时调用
    func applicationWillEnterForeground() {
        print("📱 应用回到前台，检查定时器状态")
        
        // 检查定时器是否仍在运行
        if midnightTimer == nil || !midnightTimer!.isValid {
            print("⚠️ 午夜定时器已失效，重新设置")
            setupUpdateTimers()
        }
        
        // 检查是否错过了更新时间
        checkMissedUpdates()
    }
    
    /// 检查是否错过了更新
    private func checkMissedUpdates() {
        print("🔍 检查是否错过了更新...")
        
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // 检查今天是否已经更新过
        let defaults = VerseDataService.shared.getSharedDefaults()
        let lastRefreshDate: Date?
        if let savedDate = defaults.object(forKey: "lastDailyVerseRefreshDate") as? Date {
            lastRefreshDate = calendar.startOfDay(for: savedDate)
        } else {
            lastRefreshDate = nil
        }
        
        let shouldUpdate = lastRefreshDate == nil || lastRefreshDate! < today
        
        if shouldUpdate {
            print("⚠️ 检测到遗漏的更新，立即执行...")
            performMidnightUpdate()
        } else {
            print("✅ 今天已经更新过，无需补充更新")
        }
    }
} 