import Firebase
import FirebaseStorage
import SwiftUI

// Firebase Storage服务类 - 处理与Firebase Storage的交互
class FirebaseStorageService {
    static let shared = FirebaseStorageService()
    private let storage = Storage.storage()
    
    // 用于缓存已下载的图片
    private var imageCache = NSCache<NSString, UIImage>()
    
    // 初始化
    private init() {
        // 可以在这里设置缓存大小
        imageCache.countLimit = 100
    }
    
    // 获取所有文件夹
    func getFolders(completion: @escaping ([String], Error?) -> Void) {
        let storageRef = storage.reference()
        
        storageRef.listAll { (result, error) in
            if let error = error {
                print("获取文件夹失败: \(error.localizedDescription)")
                completion([], error)
                return
            }
            
            // 添加解包处理
            guard let result = result else {
                print("获取文件夹失败: 结果为空")
                completion([], NSError(domain: "FirebaseStorageService", code: 4, userInfo: [NSLocalizedDescriptionKey: "结果为空"]))
                return
            }
            
            // 获取顶级文件夹（前缀）
            let folders = result.prefixes.map { $0.name }
            print("找到\(folders.count)个文件夹: \(folders)")
            completion(folders, nil)
        }
    }
    
    // 获取指定文件夹中的所有文件
    func getFilesInFolder(folderName: String, completion: @escaping ([StorageReference], Error?) -> Void) {
        let folderRef = storage.reference().child(folderName)
        
        folderRef.listAll { (result, error) in
            if let error = error {
                print("获取\(folderName)中的文件失败: \(error.localizedDescription)")
                completion([], error)
                return
            }
            
            // 添加解包处理
            guard let result = result else {
                print("获取\(folderName)中的文件失败: 结果为空")
                completion([], NSError(domain: "FirebaseStorageService", code: 5, userInfo: [NSLocalizedDescriptionKey: "结果为空"]))
                return
            }
            
            print("在\(folderName)中找到\(result.items.count)个文件")
            completion(result.items, nil)
        }
    }
    
    // 下载图片
    func downloadImage(from reference: StorageReference, completion: @escaping (UIImage?, Error?) -> Void) {
        // 检查缓存
        if let cachedImage = imageCache.object(forKey: reference.fullPath as NSString) {
            print("使用缓存的图片: \(reference.name)")
            completion(cachedImage, nil)
            return
        }
        
        // 设置最大下载大小（例如10MB）
        reference.getData(maxSize: 10 * 1024 * 1024) { data, error in
            if let error = error {
                print("下载图片失败: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                let error = NSError(domain: "FirebaseStorageService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法转换数据为图片"])
                print(error.localizedDescription)
                completion(nil, error)
                return
            }
            
            // 缓存图片
            self.imageCache.setObject(image, forKey: reference.fullPath as NSString)
            print("下载并缓存图片: \(reference.name)")
            completion(image, nil)
        }
    }
    
    // 获取文本文件内容
    func getTextFile(reference: StorageReference, completion: @escaping (String?, Error?) -> Void) {
        reference.getData(maxSize: 1 * 1024 * 1024) { data, error in
            if let error = error {
                print("下载文本文件失败: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "FirebaseStorageService", code: 2, userInfo: [NSLocalizedDescriptionKey: "未收到数据"])
                print(error.localizedDescription)
                completion(nil, error)
                return
            }
            
            // 尝试不同的编码
            if let text = String(data: data, encoding: .utf8) {
                print("成功读取文本文件(UTF-8): \(reference.name)")
                completion(text, nil)
            } else if let text = String(data: data, encoding: .ascii) {
                print("成功读取文本文件(ASCII): \(reference.name)")
                completion(text, nil)
            } else if let text = String(data: data, encoding: .utf16) {
                print("成功读取文本文件(UTF-16): \(reference.name)")
                completion(text, nil)
            } else if let text = String(data: data, encoding: .isoLatin1) {
                print("成功读取文本文件(ISO Latin 1): \(reference.name)")
                completion(text, nil)
            } else {
                let error = NSError(domain: "FirebaseStorageService", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法转换数据为文本，尝试了多种编码"])
                print(error.localizedDescription)
                completion(nil, error)
            }
        }
    }
    
    // 读取JSON文件内容
    func getJSONFile<T: Decodable>(reference: StorageReference, type: T.Type, completion: @escaping (T?, Error?) -> Void) {
        reference.getData(maxSize: 1 * 1024 * 1024) { data, error in
            if let error = error {
                print("下载JSON文件失败: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "FirebaseStorageService", code: 3, userInfo: [NSLocalizedDescriptionKey: "未收到数据"])
                print(error.localizedDescription)
                completion(nil, error)
                return
            }
            
            // 尝试打印JSON数据进行调试
            if let jsonString = String(data: data, encoding: .utf8) {
                print("JSON文件内容: \(jsonString)")
            }
            
            // 创建更宽容的JSON解码器
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let decodedObject = try decoder.decode(T.self, from: data)
                print("成功解析JSON文件: \(reference.name)")
                completion(decodedObject, nil)
            } catch {
                print("解析JSON失败: \(error.localizedDescription)")
                print("具体错误: \(error)")
                
                // 尝试清理JSON数据并重新解析
                if var jsonString = String(data: data, encoding: .utf8) {
                    // 移除可能的BOM标记
                    if jsonString.hasPrefix("\u{FEFF}") {
                        jsonString = String(jsonString.dropFirst())
                        print("移除了BOM标记")
                    }
                    
                    // 尝试修复常见的JSON错误并重新解析
                    jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // 确保是有效的JSON对象
                    if !jsonString.hasPrefix("{") {
                        jsonString = "{\(jsonString)"
                    }
                    if !jsonString.hasSuffix("}") {
                        jsonString = "\(jsonString)}"
                    }
                    
                    if let cleanData = jsonString.data(using: .utf8) {
                        do {
                            // 这里需要重新创建decoder，因为外部的decoder可能已经超出作用域
                            let cleanDecoder = JSONDecoder()
                            cleanDecoder.keyDecodingStrategy = .convertFromSnakeCase
                            
                            let decodedObject = try cleanDecoder.decode(T.self, from: cleanData)
                            print("成功解析清理后的JSON文件: \(reference.name)")
                            completion(decodedObject, nil)
                            return
                        } catch {
                            print("清理后仍然解析失败: \(error)")
                        }
                    }
                }
                
                completion(nil, error)
            }
        }
    }
} 