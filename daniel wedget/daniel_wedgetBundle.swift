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
        
        print("💠 加载MainVerseWidget...")
        print("🔒 加载LockScreenVerseWidget...")
    }
    
    var body: some Widget {
        // 主桌面中号Widget
        MainVerseWidget()
        // 锁屏矩形Widget
        LockScreenVerseWidget()
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
