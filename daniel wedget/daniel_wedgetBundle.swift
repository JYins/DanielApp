//
//  daniel_wedgetBundle.swift
//  daniel wedget
//
//  Created by 殷实 on 2025-03-30.
//

import WidgetKit
import SwiftUI
import CoreText

@main
struct daniel_wedgetBundle: WidgetBundle {
    init() {
        print("⭐️ Widget Bundle初始化")
        print("📱 App Group: group.com.daniel.DanielApp")
        
        // 注册自定义字体
        registerFonts()
        
        // 初始化Widget独立系统
        initializeWidgetSystems()
        
        print("💠 加载MainVerseWidget...")
        print("🔒 加载LockScreenVerseWidget...")
    }
    
    var body: some Widget {
        // 主桌面中号Widget
        MainVerseWidget()
        // 锁屏矩形Widget
        LockScreenVerseWidget()
    }
    
    // 初始化Widget独立系统
    private func initializeWidgetSystems() {
        print("🚀 初始化Widget独立系统")
        
        // 尝试从主应用迁移设置（仅在首次运行时）
        VerseWidgetSettingsManager.migrateFromMainAppIfNeeded()
        
        // 初始化数据管理器
        let dataManager = WidgetDataManager.shared
        print("📊 数据管理器初始化: \(dataManager.isDataReady() ? "成功" : "等待中")")
        
        // 初始化生命周期管理器
        let lifecycleManager = WidgetLifecycleManager.shared
        print("🔄 生命周期管理器初始化完成")
        
        // 检查并执行必要的更新
        lifecycleManager.checkAndUpdateIfNeeded()
        
        // 同步数据状态
        lifecycleManager.syncDataState()
        
        print("✅ Widget独立系统初始化完成")
    }
    
    // 注册自定义字体函数
    private func registerFonts() {
        // 尝试从Bundle中直接加载字体
        if let fontURL = Bundle.main.url(forResource: "SimSun Font", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            print("✅ Widget成功注册宋体字体")
        } else {
            // 如果直接加载失败，尝试从主应用共享的资源包加载
            let mainBundlePath = Bundle.main.bundlePath.components(separatedBy: "/").dropLast().joined(separator: "/")
            if let appBundle = Bundle(path: "\(mainBundlePath)/DanielApp.app"),
               let fontURL = appBundle.url(forResource: "SimSun Font", withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
                print("✅ Widget从主应用成功注册宋体字体")
            } else {
                print("❌ Widget未找到宋体字体文件")
            }
        }
        
        // 韩文字体
        if let fontURL = Bundle.main.url(forResource: "NanumMyeongjo-Regular", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            print("✅ Widget成功注册韩文字体")
        } else {
            // 如果直接加载失败，尝试从主应用共享的资源包加载
            let mainBundlePath = Bundle.main.bundlePath.components(separatedBy: "/").dropLast().joined(separator: "/")
            if let appBundle = Bundle(path: "\(mainBundlePath)/DanielApp.app"),
               let fontURL = appBundle.url(forResource: "NanumMyeongjo-Regular", withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
                print("✅ Widget从主应用成功注册韩文字体")
            } else {
                print("❌ Widget未找到韩文字体文件")
            }
        }
    }
}
