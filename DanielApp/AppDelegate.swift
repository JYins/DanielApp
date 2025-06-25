import Foundation
import UIKit
import Firebase

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化Firebase
        FirebaseApp.configure()
        print("Firebase已初始化")
        
        return true
    }
} 