import SwiftUI
import Foundation
import WidgetKit
// 导入共享模型
import Foundation

// 为View中使用的辅助方法创建命名空间
enum VerseViewHelper {
    // 从JSON加载经文数据的工具函数
    static func loadVersesFromJson() -> [MultiLanguageVerse]? {
        // 直接使用 VerseDataService 方法
        return VerseDataService.shared.loadVersesFromJson()
    }
    
    // 从JSON加载经文索引列表
    static func loadVerseIndexList() -> [String]? {
        // 通过 VerseDataService 获取索引列表
        return VerseDataService.shared.getAllVerseReferences()
    }
    
    // 根据日期选择经文
    static func selectVerseForDate(from verses: [MultiLanguageVerse], date: Date) -> MultiLanguageVerse? {
        // 直接使用 VerseDataService 方法
        return VerseDataService.shared.getVerseForDate(date)
    }
}

struct VerseOfTheDayView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = VerseViewModel()
    @StateObject private var authManager = AuthManager.shared
    
    // 动态的问候语（包含用户名和性别称呼）
    private var greetingText: String {
        if case .signedIn(let profile) = authManager.authState {
            let genderTitle = profile.gender.localizedName(for: appState.selectedLanguage)
            
            switch appState.selectedLanguage {
            case .chinese:
                return "平安，\(profile.name) \(genderTitle)"
            case .english:
                return "Peace, \(genderTitle) \(profile.name)"
            case .korean:
                return "평안, \(profile.name) \(genderTitle)"
            }
        } else {
            // 默认文本（未登录）
            switch appState.selectedLanguage {
            case .chinese:
                return "平安，姊妹/弟兄"
            case .english:
                return "Peace, Sister/Brother"
            case .korean:
                return "평안, 자매/형제"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // 背景色
            DesignSystem.Colors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.sectionSpacing) {
                    // 顶部问候区域
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Text(greetingText)
                                .font(DesignSystem.Typography.smart(DesignSystem.Typography.callout, weight: .medium, language: appState.selectedLanguage))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            
                            Spacer()
                            
                            // 用户头像按钮
                            VerseUserButtonView()
                        }
                        .greetingBar()
                    }
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.horizontal, DesignSystem.Spacing.contentMargin)
                    
                    // 主要内容区域
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // 经文卡片
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent))
                                .scaleEffect(1.2)
                                .frame(height: 200)
                        } else if let verse = viewModel.currentVerse {
                            ModernVerseCard(
                                verse: verse,
                                language: appState.selectedLanguage,
                                viewModel: viewModel
                            )
                        } else {
                            Text("无法加载经文")
                                .font(DesignSystem.Typography.body(DesignSystem.Typography.body, language: appState.selectedLanguage))
                                .foregroundColor(DesignSystem.Colors.mutedText)
                                .frame(height: 200)
                        }
                    
                        // 按钮区域
                        VStack(spacing: DesignSystem.Spacing.md) {
                            if viewModel.updateMode == "automatic" {
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    Button(LocalizedText.VerseView.switchVerse.text(for: appState.selectedLanguage)) {
                                        viewModel.loadRandomVerse()
                                    }
                                    .buttonStyle(ModernButtonStyle(language: appState.selectedLanguage))
                                    
                                    // 根据是否已固定显示不同的按钮
                                    if viewModel.isVerseFixed {
                                        Button(LocalizedText.VerseView.unfixVerse.text(for: appState.selectedLanguage)) {
                                            viewModel.unfixVerse()
                                        }
                                        .buttonStyle(ModernButtonStyle(language: appState.selectedLanguage))
                                    } else {
                                        Button(LocalizedText.VerseView.setAsFixed.text(for: appState.selectedLanguage)) {
                                            viewModel.setFixedVerse()
                                        }
                                        .buttonStyle(ModernButtonStyle(language: appState.selectedLanguage))
                                    }
                                }
                            } else {
                                // 手动模式下，显示修改按钮
                                Button(LocalizedText.VerseView.modifyInSettings.text(for: appState.selectedLanguage)) {
                                    // 显示设置页面叠加层
                                    appState.needsShowSettings = true
                                }
                                .buttonStyle(ModernButtonStyle(language: appState.selectedLanguage))
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.contentMargin)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.contentMargin)
                }
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
        .watermark("@但以理和他的朋友们")
            .onAppear {
                print("🔄 VerseOfTheDayView显示...")
                
                // 设置AppState引用
                viewModel.updateAppStateReference(appState)
                
                // 检查是否有保存的经文引用
                if let reference = appState.selectedVerseReference {
                    print("📘 发现已保存的经文引用: \(reference)")
                    viewModel.loadVerseByReference(reference)
                } else {
                    // 如果没有保存的引用，才加载当前/今日经文
                    print("📗 无已保存引用，加载当前经文")
                    viewModel.loadCurrentVerse()
                }
                
                // 设置语言
                viewModel.selectedLanguage = appState.selectedLanguage
            }
            .onChange(of: appState.selectedVerseReference) { _, newValue in
                if let reference = newValue {
                    viewModel.loadVerseByReference(reference)
                } else {
                    viewModel.loadCurrentVerse()
                }
            }
            .onChange(of: appState.selectedLanguage) { _, newValue in
                // 当语言改变时更新ViewModel的语言设置
                viewModel.updateLanguage(newValue)
            }
            .onChange(of: appState.needsRefreshVerseStatus) { _, newValue in
                // 当需要刷新状态时，更新ViewModel状态
                if newValue {
                    viewModel.refreshStatus()
                    appState.needsRefreshVerseStatus = false
                }
            }
        }
    }

// 使用VerseViewModel管理状态
class VerseViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var currentVerse: MultiLanguageVerse?
    @Published var selectedLanguage: CoreModels.VerseLanguage = .chinese
    @Published var updateMode: String = "automatic"
    @Published var isVerseFixed = false
    @Published var statusMessage = "当前状态：自动每日更新"
    @Published var showDebugInfo = false
    @Published var debugInfo = ""
    
    // 添加AppState引用变量
    private var appStateReference: AppState?
    
    init(appState: AppState? = nil) {
        self.appStateReference = appState
        
        // 从共享设置加载当前配置
        self.selectedLanguage = VerseDataService.shared.getSelectedLanguage()
        self.updateMode = VerseDataService.shared.getUpdateMode()
        self.isVerseFixed = VerseDataService.shared.isVerseFixed()
        
        // 更新状态信息
        updateStatusMessage()
    }
    
    // 更新AppState引用
    func updateAppStateReference(_ appState: AppState) {
        self.appStateReference = appState
    }
    
    // 处理语言更新
    func updateLanguage(_ language: CoreModels.VerseLanguage) {
        self.selectedLanguage = language
        // 不需要更新VerseDataService，因为语言变化已经在AppState.updateLanguage()中处理
        
        // 更新状态信息以反映新语言
        updateStatusMessage()
    }
    
    // 根据选定的语言获取当前状态文本
    func getStatusMessage(for language: CoreModels.VerseLanguage) -> String {
        let statusPrefix = LocalizedText.VerseView.currentStatus.text(for: language)
        
        if updateMode == "automatic" {
            if isVerseFixed {
                return statusPrefix + LocalizedText.VerseView.fixedVerseStatus.text(for: language)
            } else {
                return statusPrefix + LocalizedText.VerseView.autoUpdateStatus.text(for: language)
            }
        } else {
            return statusPrefix + LocalizedText.VerseView.manualSelectStatus.text(for: language)
        }
    }
    
    // 载入当前经文（应用启动时调用）
    func loadCurrentVerse() {
        print("🏠 主App开始载入当前经文...")
        
        // 设置加载状态
        isLoading = true
        
        // 异步执行数据加载，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. 强制重新获取当前语言设置，避免依赖潜在的旧缓存
            let currentLanguage = VerseDataService.shared.getSelectedLanguage()
            print("🌐 当前语言设置: \(currentLanguage.rawValue)")
            
            // 2. 主App重新计算应该显示的经文，不依赖Widget可能写入的数据
            let verse: MultiLanguageVerse
            if let loadedVerse = VerseDataService.shared.getCurrentVerseToDisplay() {
                print("✅ 主App获取到要显示的经文: \(loadedVerse.reference)")
                verse = loadedVerse
            } else {
                print("❌ 主App无法获取要显示的经文，使用默认经文")
                verse = VerseDataService.shared.getDefaultVerse()
            }
            
            // 3. 在主线程更新UI
            DispatchQueue.main.async {
                self.currentVerse = verse
                self.isLoading = false // 关键：设置加载完成状态
                
                // 4. 更新状态信息
                self.updateStatusMessage()
                
                print("✅ 主App经文载入完成，最终显示: \(verse.reference)")
                
                // 5. 异步缓存数据，不阻塞UI更新
                DispatchQueue.global(qos: .utility).async {
                    // 立即将主App确定的经文缓存给Widget使用
                    VerseDataService.shared.cacheCurrentVerse(verse)
                    print("💾 主App已为Widget缓存当前经文: \(verse.reference)")
                    
                    // 确保Widget能读取到主App的最新状态
                    DispatchQueue.main.async {
                        WidgetCenter.shared.reloadAllTimelines()
                        print("📢 主App已通知Widget更新显示")
                    }
                }
            }
        }
    }
    
    // 加载今天的经文
    func loadVerseForToday() {
        isLoading = true
        print("尝试加载今日经文...")
        
        // 先检查经文数据是否已成功加载
        let dataService = VerseDataService.shared
        let verses = dataService.loadVersesFromJson()
        
        if verses == nil || verses?.isEmpty == true {
            print("警告：无法加载经文数据文件")
            isLoading = false
            
            // 使用默认经文，但添加提示信息
            self.currentVerse = MultiLanguageVerse(
                reference: "约翰福音 3:16 (默认经文 - 数据加载失败)",
                cn: "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不致灭亡，反得永生。\n\n[提示：未能加载经文数据库。请确保verses_merged.json文件已添加到项目中。]",
                en: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.\n\n[NOTE: Failed to load verse database. Please make sure verses_merged.json file is added to the project.]",
                kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라.\n\n[알림: 구절 데이터베이스를 로드하지 못했습니다. verses_merged.json 파일이 프로젝트에 추가되었는지 확인하십시오.]"
            )
            
            // 更新状态信息
            self.statusMessage = "警告：经文数据库加载失败"
            return
        }
        
        // 从 VerseDataService 获取今天的经文
        if let verse = dataService.getCurrentVerseToDisplay() {
            self.currentVerse = verse
            print("成功加载今日经文: \(verse.reference)")
        } else {
            print("警告：无法获取今日经文，使用默认经文")
            // 使用默认经文
            self.currentVerse = MultiLanguageVerse(
                reference: "约翰福音 3:16 (默认经文)",
                cn: "神爱世人，甚至将他的独生子赐给他们，叫一切信他的，不致灭亡，反得永生。",
                en: "For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.",
                kr: "하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 멸망하지 않고 영생을 얻게 하려 하심이라."
            )
        }
        
        isLoading = false
        
        // 更新状态信息
        updateStatusMessage()
    }
    
    // 加载随机经文
    func loadRandomVerse() {
        isLoading = true
        print("🔄 尝试加载随机经文...")
        
        var newVerse: MultiLanguageVerse? = nil
        
        // 获取不同于当前的随机经文
        if let currentRef = currentVerse?.reference,
           let randomRef = VerseDataService.shared.getRandomVerseReference(different: currentRef),
           let randomVerse = VerseDataService.shared.findVerse(byReference: randomRef) {
            newVerse = randomVerse
            print("✅ 成功加载随机经文: \(randomVerse.reference)")
        } else if let randomRef = VerseDataService.shared.getRandomVerseReference(),
                  let randomVerse = VerseDataService.shared.findVerse(byReference: randomRef) {
            newVerse = randomVerse
            print("✅ 成功加载随机经文: \(randomVerse.reference)")
        } else {
            print("❌ 无法加载随机经文")
            // 如果无法加载随机经文，保持当前经文不变
        }
        
        // 如果成功获取了新经文，保存并显示它
        if let verse = newVerse {
            self.currentVerse = verse
            
            // 强制同步到UserDefaults - 确保Widget可以获取
            VerseDataService.shared.cacheCurrentVerse(verse)
            
            // 保存引用到appState，这样切换页面后也能记住
            if let appState = self.appStateReference {
                appState.selectedVerseReference = verse.reference
                print("📝 已保存经文引用到appState: \(verse.reference)")
            } else {
                print("⚠️ 无法保存到appState: appState引用为nil")
            }
            
            // 根据当前模式保存经文引用
            if isVerseFixed {
                // 固定模式：保存为永久固定经文引用
                VerseDataService.shared.setCurrentVerseReference(verse.reference)
                print("📌 已保存固定经文引用: \(verse.reference)")
            } else if updateMode == "manual" {
                // 手动模式：保存为永久手动选择的引用
                VerseDataService.shared.setCurrentVerseReference(verse.reference)
                print("📌 已保存手动模式下的经文引用: \(verse.reference)")
            } else if updateMode == "automatic" {
                // 自动模式：保存为临时切换引用（明天会被重置为每日一句）
                VerseDataService.shared.setTempSwitchedReference(verse.reference)
                print("📌 已保存自动模式下的临时切换引用: \(verse.reference)，次日0点将重置为每日一句")
                
                // 更新今天的刷新日期，表示今天已经有活动
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let defaults = VerseDataService.shared.getSharedDefaults()
                defaults.set(today, forKey: "lastDailyVerseRefreshDate")
                defaults.synchronize()
                print("📝 已标记今天为活跃日期，明天将重置为每日一句")
            }
            
            // 强制通知Widget更新
            WidgetCenter.shared.reloadAllTimelines()
            print("📢 已通知Widget更新，显示新经文: \(verse.reference)")
        }
        
        isLoading = false
        
        // 更新状态信息
        updateStatusMessage()
    }
    
    // 根据引用加载特定经文
    func loadVerseByReference(_ reference: String) {
        isLoading = true
        print("🔍 尝试加载经文: \(reference)")
        
        if let verse = VerseDataService.shared.findVerse(byReference: reference) {
            self.currentVerse = verse
            print("✅ 成功加载经文: \(verse.reference)")
            
            // 保存引用到appState，这样切换页面后也能记住
            if let appState = self.appStateReference {
                appState.selectedVerseReference = reference
                print("📝 已保存经文引用到appState: \(reference)")
            } else {
                print("⚠️ 无法保存到appState: appState引用为nil")
            }
            
            // 确保缓存最新数据
            VerseDataService.shared.cacheCurrentVerse(verse)
            
            // 根据当前模式保存经文引用
            if isVerseFixed {
                // 固定模式：保存为永久固定经文引用
                VerseDataService.shared.setCurrentVerseReference(reference)
                print("📌 已保存固定经文引用: \(reference)")
            } else if updateMode == "manual" {
                // 手动模式：保存为永久手动选择的引用
                VerseDataService.shared.setCurrentVerseReference(reference)
                print("📌 已保存手动模式下的经文引用: \(reference)")
            } else if updateMode == "automatic" {
                // 自动模式：保存为临时切换引用（明天会被重置为每日一句）
                VerseDataService.shared.setTempSwitchedReference(reference)
                print("📌 已保存自动模式下的临时切换引用: \(reference)，次日0点将重置为每日一句")
                
                // 更新今天的刷新日期，表示今天已经有活动
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let defaults = VerseDataService.shared.getSharedDefaults()
                defaults.set(today, forKey: "lastDailyVerseRefreshDate")
                defaults.synchronize()
                print("📝 已标记今天为活跃日期，明天将重置为每日一句")
            }
            
            // 强制通知Widget更新
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            print("❌ 未找到经文: \(reference)")
        }
        
        isLoading = false
        
        // 更新状态信息
        updateStatusMessage()
    }
    
    // 设置固定经文
    func setFixedVerse() {
        guard let verse = currentVerse else { return }
        
        // 设置固定经文
        VerseDataService.shared.setVerseFixed(true)
        VerseDataService.shared.setCurrentVerseReference(verse.reference)
        isVerseFixed = true
        
        // 保存引用到appState，这样切换页面后也能记住
        if let appState = self.appStateReference {
            appState.selectedVerseReference = verse.reference
            print("📝 已保存固定经文引用到appState: \(verse.reference)")
        } else {
            print("⚠️ 无法保存到appState: appState引用为nil")
        }
        
        // 更新状态信息
        updateStatusMessage()
        
        // 刷新Widget
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 取消固定经文
    func unfixVerse() {
        print("🔓 取消固定经文...")
        
        // 保存当前经文（仅用于显示）
        let currentVerseToKeep = self.currentVerse
        
        // 修改状态
        VerseDataService.shared.setVerseFixed(false)
        isVerseFixed = false
        
        // 在自动模式下，保留当前经文引用直到下一天自动刷新
        if updateMode == "automatic" {
            // 不再清除当前经文引用，保留当前经文直到下次自动刷新
            print("自动模式：已取消固定，但保留当前经文直到下一天自动刷新")
        } else {
            // 手动模式下保持当前经文
            if let verse = currentVerseToKeep {
                VerseDataService.shared.setCurrentVerseReference(verse.reference)
                print("手动模式：保持当前经文: \(verse.reference)")
            }
        }
        
        // 保持当前经文显示不变
        if let verse = currentVerseToKeep {
            // 缓存当前经文用于显示
            VerseDataService.shared.cacheCurrentVerse(verse)
            
            // 保存引用到appState，这样切换页面后也能记住
            if let appState = self.appStateReference {
                appState.selectedVerseReference = verse.reference
                print("📝 已保存经文引用到appState用于当前显示: \(verse.reference)")
            }
        }
        
        // 更新状态信息
        updateStatusMessage()
        
        // 通知Widget更新
        print("正在通知Widget更新...")
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // 根据当前语言获取经文内容
    func getVerseTextInSelectedLanguage(_ verse: MultiLanguageVerse) -> String {
        switch selectedLanguage {
        case .chinese:
            return verse.cn
        case .english:
            return verse.en
        case .korean:
            return verse.kr
        }
    }
    
    // 更新状态信息
    func updateStatusMessage() {
        updateMode = VerseDataService.shared.getUpdateMode()
        isVerseFixed = VerseDataService.shared.isVerseFixed()
        
        // 使用当前选择的语言更新状态信息
        statusMessage = getStatusMessage(for: selectedLanguage)
        
        print("📊 状态更新: mode=\(updateMode), fixed=\(isVerseFixed), status=\(statusMessage)")
    }
    
    // 强制刷新状态（供外部调用）
    func refreshStatus() {
        updateStatusMessage()
    }
    
    // 收集调试信息
    func collectDebugInfo() {
        var info = "======= 调试信息 =======\n"
        
        // 基本设置
        info += "📱 应用配置:\n"
        info += "当前模式: \(updateMode)\n"
        info += "固定经文: \(isVerseFixed ? "是" : "否")\n"
        info += "选中语言: \(selectedLanguage.rawValue)\n\n"
        
        // 当前显示的经文
        if let verse = currentVerse {
            info += "📗 当前经文:\n"
            info += "引用: \(verse.reference)\n"
            info += "中文文本: \(verse.cn.prefix(50))...\n"
            info += "是默认经文? \(verse.reference.contains("约翰福音 3:16") ? "是" : "否")\n\n"
        } else {
            info += "❌ 当前无经文显示\n\n"
        }
        
        // Bundle信息
        info += "📦 Bundle信息:\n"
        info += "路径: \(Bundle.main.bundlePath)\n"
        if let resourcePath = Bundle.main.resourceURL?.path {
            info += "资源路径: \(resourcePath)\n\n"
        } else {
            info += "资源路径: nil\n\n"
        }
        
        // 文档目录
        if let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            info += "📁 文档目录:\n"
            info += "\(docPath)\n\n"
        }
        
        // 检查文件存在情况
        info += "🔍 JSON文件检查:\n"
        let fileManager = FileManager.default
        var possiblePaths = [
            "\(Bundle.main.bundlePath)/verses_merged.json",
            Bundle.main.resourceURL?.appendingPathComponent("verses_merged.json").path ?? "nil",
            "/Users/yinshi/Documents/DanielApp/DanielApp/verses_merged.json",
        ]
        
        if let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
            possiblePaths.append("\(docPath)/verses_merged.json")
        }
        
        for path in possiblePaths {
            let exists = fileManager.fileExists(atPath: path)
            info += "\(path): \(exists ? "✅ 存在" : "❌ 不存在")\n"
        }
        
        self.debugInfo = info
    }
}

// 复制JSON文件到文档目录的函数
func copyJsonFiles() {
    print("📋 开始复制JSON文件到文档目录...")
    let fileManager = FileManager.default
    
    // 获取文档目录
    let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsDirectory = paths.first else {
        print("❌ 无法获取文档目录")
        return
    }
    
    // 源文件路径
    let sourcePaths = [
        "/Users/yinshi/Documents/DanielApp/DanielApp/verses_merged.json",
        "/Users/yinshi/Documents/DanielApp/DanielApp/verses_index.json"
    ]
    
    // 目标文件路径
    let destinationPaths = [
        documentsDirectory.appendingPathComponent("verses_merged.json").path,
        documentsDirectory.appendingPathComponent("verses_index.json").path
    ]
    
    // 复制文件
    for (index, sourcePath) in sourcePaths.enumerated() {
        let destinationPath = destinationPaths[index]
        
        if fileManager.fileExists(atPath: sourcePath) {
            do {
                // 删除旧文件
                if fileManager.fileExists(atPath: destinationPath) {
                    try fileManager.removeItem(atPath: destinationPath)
                    print("🗑️ 删除已存在的目标文件: \(destinationPath)")
                }
                
                // 复制新文件
                try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
                print("✅ 成功复制文件到: \(destinationPath)")
            } catch {
                print("❌ 复制文件失败: \(error.localizedDescription)")
            }
        } else {
            print("❌ 源文件不存在: \(sourcePath)")
        }
    }
    
    print("📋 文件复制完成，尝试重新加载数据...")
    
    // 强制重新加载数据
    VerseDataService.shared.clearCache()
    VerseDataService.shared.loadVersesIfNeeded()
    VerseDataService.shared.loadVerseIndexListIfNeeded()
}

// MARK: - 现代化经文卡片组件
struct ModernVerseCard: View {
    let verse: MultiLanguageVerse
    let language: CoreModels.VerseLanguage
    @ObservedObject var viewModel: VerseViewModel
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // 每日经文标题
            HStack {
                Text(LocalizedText.VerseView.dailyVerse.text(for: language))
                    .font(DesignSystem.Typography.title(DesignSystem.Typography.title2, weight: .semibold, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                // 经文引用
                Text(CoreModels.VerseLanguage.localizeReference(verse.reference, to: language))
                    .font(DesignSystem.Typography.smart(DesignSystem.Typography.callout, weight: .medium, language: language))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
            .padding(.top, DesignSystem.Spacing.cardPadding)
            
            // 经文内容
            VStack(spacing: DesignSystem.Spacing.md) {
                Text(viewModel.getVerseTextInSelectedLanguage(verse))
                    .font(DesignSystem.Typography.body(DesignSystem.Typography.body, weight: .regular, language: language))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(4)
                    .padding(.horizontal, DesignSystem.Spacing.md)
            }
            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
            .padding(.bottom, DesignSystem.Spacing.cardPadding)
            
            // 状态信息
            HStack(spacing: DesignSystem.Spacing.xs) {
                                  Image(systemName: "info.circle")
                     .font(.system(size: 12))
                      .foregroundColor(DesignSystem.Colors.secondaryText)
                
                Text(viewModel.getStatusMessage(for: language))
                    .font(DesignSystem.Typography.smart(DesignSystem.Typography.footnote, language: language))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.cardPadding)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
        .modernCard()
        .padding(.horizontal, DesignSystem.Spacing.contentMargin)
    }
}

// MARK: - 每日经文页面的用户按钮组件
struct VerseUserButtonView: View {
    @StateObject private var authManager = AuthManager.shared
    @EnvironmentObject var appState: AppState
    @State private var showingUserMenu = false
    @State private var showingLogin = false
    
    var body: some View {
        Button(action: {
            if authManager.hasContentAccess() {
                // 已登录，显示用户菜单
                showingUserMenu = true
            } else {
                // 未登录，显示登录页面
                showingLogin = true
            }
        }) {
            Circle()
                .fill(DesignSystem.Colors.accent.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: authManager.hasContentAccess() ? "person.fill" : "person")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.accent)
                )
        }
        .actionSheet(isPresented: $showingUserMenu) {
            ActionSheet(
                title: Text(getUserMenuTitle()),
                message: getUserInfo(),
                buttons: [
                    .destructive(Text(getLogoutText())) {
                        authManager.signOut()
                    },
                    .cancel(Text(getCancelText()))
                ]
            )
        }
        .sheet(isPresented: $showingLogin) {
            LoginView()
                .environmentObject(appState)
        }
    }
    
    private func getUserMenuTitle() -> String {
        switch appState.selectedLanguage {
        case .chinese:
            return "用户菜单"
        case .english:
            return "User Menu"
        case .korean:
            return "사용자 메뉴"
        }
    }
    
    private func getUserInfo() -> Text {
        if case .signedIn(let profile) = authManager.authState {
            let userText: String
            let emailText: String
            
            switch appState.selectedLanguage {
            case .chinese:
                userText = "用户"
                emailText = "邮箱"
            case .english:
                userText = "User"
                emailText = "Email"
            case .korean:
                userText = "사용자"
                emailText = "이메일"
            }
            
            return Text("\(userText)：\(profile.name)\n\(emailText)：\(profile.email)")
        } else {
            return Text("")
        }
    }
    
    private func getLogoutText() -> String {
        switch appState.selectedLanguage {
        case .chinese:
            return "登出"
        case .english:
            return "Logout"
        case .korean:
            return "로그아웃"
        }
    }
    
    private func getCancelText() -> String {
        switch appState.selectedLanguage {
        case .chinese:
            return "取消"
        case .english:
            return "Cancel"
        case .korean:
            return "취소"
        }
    }
}
