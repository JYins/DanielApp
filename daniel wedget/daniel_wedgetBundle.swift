//
//  daniel_wedgetBundle.swift
//  daniel wedget
//
//  Created by 殷实 on 2025-03-30.
//

import WidgetKit
import SwiftUI
import CoreText
import UIKit

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
        print("🔍 Widget开始注册字体...")
        print("📍 Widget Bundle路径: \(Bundle.main.bundlePath)")
        
        // 测试字体是否可用
        func testFont(_ fontName: String) -> Bool {
            let testFont = UIFont(name: fontName, size: 16)
            let isAvailable = testFont != nil
            print("🧪 测试字体 '\(fontName)': \(isAvailable ? "可用" : "不可用")")
            if let font = testFont {
                print("   实际字体名称: \(font.fontName)")
            }
            return isAvailable
        }
        
        // 中文字体注册
        print("📝 尝试注册中文字体...")
        if let fontURL = Bundle.main.url(forResource: "爱点风雅黑长体(商用免费)", withExtension: "ttf") {
            print("   找到字体文件: \(fontURL.path)")
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
            if success {
                print("✅ Widget成功注册中文字体")
            } else {
                let errorMessage = error?.takeRetainedValue().localizedDescription ?? "未知错误"
                print("❌ Widget注册中文字体失败: \(errorMessage)")
            }
            _ = testFont("AidianFengYaHeiChangTi")
        } else {
            print("   从Widget Bundle未找到字体，尝试从主应用加载...")
            let mainBundlePath = Bundle.main.bundlePath.components(separatedBy: "/").dropLast().joined(separator: "/")
            print("   主应用路径: \(mainBundlePath)")
            if let appBundle = Bundle(path: "\(mainBundlePath)/DanielApp.app"),
               let fontURL = appBundle.url(forResource: "爱点风雅黑长体(商用免费)", withExtension: "ttf") {
                print("   找到主应用字体文件: \(fontURL.path)")
                var error: Unmanaged<CFError>?
                let success = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
                if success {
                    print("✅ Widget从主应用成功注册中文字体")
                } else {
                    let errorMessage = error?.takeRetainedValue().localizedDescription ?? "未知错误"
                    print("❌ Widget从主应用注册中文字体失败: \(errorMessage)")
                }
                _ = testFont("AidianFengYaHeiChangTi")
            } else {
                print("❌ Widget未找到中文字体文件")
            }
        }
        
        // 韩文字体注册
        print("📝 尝试注册韩文字体...")
        if let fontURL = Bundle.main.url(forResource: "GowunDodum-Regular", withExtension: "ttf") {
            print("   找到字体文件: \(fontURL.path)")
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
            if success {
                print("✅ Widget成功注册韩文字体")
            } else {
                let errorMessage = error?.takeRetainedValue().localizedDescription ?? "未知错误"
                print("❌ Widget注册韩文字体失败: \(errorMessage)")
            }
            _ = testFont("GowunDodum-Regular")
        } else {
            print("   从Widget Bundle未找到字体，尝试从主应用加载...")
            let mainBundlePath = Bundle.main.bundlePath.components(separatedBy: "/").dropLast().joined(separator: "/")
            if let appBundle = Bundle(path: "\(mainBundlePath)/DanielApp.app"),
               let fontURL = appBundle.url(forResource: "GowunDodum-Regular", withExtension: "ttf") {
                print("   找到主应用字体文件: \(fontURL.path)")
                var error: Unmanaged<CFError>?
                let success = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
                if success {
                    print("✅ Widget从主应用成功注册韩文字体")
                } else {
                    let errorMessage = error?.takeRetainedValue().localizedDescription ?? "未知错误"
                    print("❌ Widget从主应用注册韩文字体失败: \(errorMessage)")
                }
                _ = testFont("GowunDodum-Regular")
            } else {
                print("❌ Widget未找到韩文字体文件")
            }
        }
        
        print("🏁 Widget字体注册完成")
    }
}
