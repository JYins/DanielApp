import Foundation
import UIKit
import Firebase

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化Firebase
        FirebaseApp.configure()
        print("Firebase已初始化")
        
        copyJSONFilesToBundle()
        return true
    }
    
    private func copyJSONFilesToBundle() {
        print("🚀 应用启动 - 尝试复制JSON文件到Bundle...")
        let fileManager = FileManager.default
        let bundlePath = Bundle.main.bundlePath
        
        // 检查源文件是否存在
        let sourcePaths = [
            "/Users/yinshi/Documents/DanielApp/DanielApp/verses_merged.json",
            "/Users/yinshi/Documents/DanielApp/DanielApp/verses_index.json"
        ]
        
        let destinationPaths = [
            "\(bundlePath)/verses_merged.json",
            "\(bundlePath)/verses_index.json"
        ]
        
        for (index, sourcePath) in sourcePaths.enumerated() {
            let destinationPath = destinationPaths[index]
            let fileName = URL(fileURLWithPath: sourcePath).lastPathComponent
            
            if fileManager.fileExists(atPath: sourcePath) {
                print("✅ 源文件存在: \(sourcePath)")
                
                do {
                    if fileManager.fileExists(atPath: destinationPath) {
                        try fileManager.removeItem(atPath: destinationPath)
                        print("🗑️ 移除已存在的目标文件: \(destinationPath)")
                    }
                    
                    try fileManager.copyItem(atPath: sourcePath, toPath: destinationPath)
                    print("📋 成功复制文件 \(fileName) 到 \(destinationPath)")
                } catch {
                    print("❌ 复制文件失败 \(fileName): \(error)")
                }
            } else {
                print("⚠️ 源文件不存在: \(sourcePath)")
            }
        }
    }
} 