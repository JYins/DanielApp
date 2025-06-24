import SwiftUI
import FirebaseStorage
import Combine

// 卡片文案的多语言支持
struct CardCaption {
    let chinese: String
    let english: String
    let korean: String
    
    func text(for language: CoreModels.VerseLanguage) -> String {
        switch language {
        case .chinese:
            return chinese
        case .english:
            return english
        case .korean:
            return korean
        }
    }
}

// 卡片数据模型
struct WordCard: Identifiable {
    let id = UUID()
    let folderName: String
    let images: [StorageReference]
    let caption: CardCaption
    let categoryKey: LocalizedText.WordCardGallery
    
    // 从JSON解析的卡片配置
    struct CardConfig: Codable {
        let category: String
        let captions: CaptionData
        
        struct CaptionData: Codable {
            let chinese: String
            let english: String
            let korean: String
        }
    }
}

// WordCardViewModel用于加载和管理卡片数据
class WordCardViewModel: ObservableObject {
    @Published var cards: [WordCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let storageService = FirebaseStorageService.shared
    
    func loadCards() {
        isLoading = true
        errorMessage = nil
        
        storageService.getFolders { [weak self] folders, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "加载文件夹失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var newCards: [WordCard] = []
            
            // 过滤掉可能不是实际内容文件夹的项目
            let contentFolders = folders.filter { 
                !$0.hasPrefix(".") && !$0.hasPrefix("_") 
            }
            
            print("正在处理 \(contentFolders.count) 个内容文件夹")
            
            if contentFolders.isEmpty {
                DispatchQueue.main.async {
                    self.errorMessage = "未找到有效内容文件夹"
                    self.isLoading = false
                }
                return
            }
            
            for folder in contentFolders {
                dispatchGroup.enter()
                self.loadCardFromFolder(folder) { card in
                    if let card = card {
                        newCards.append(card)
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.cards = newCards
                self.isLoading = false
                print("已成功加载\(newCards.count)张卡片")
            }
        }
    }
    
    private func loadCardFromFolder(_ folderName: String, completion: @escaping (WordCard?) -> Void) {
        print("正在加载文件夹: \(folderName)")
        
        // 首先获取文件夹中的所有文件
        storageService.getFilesInFolder(folderName: folderName) { [weak self] files, error in
            guard let self = self else { return }
            
            if let error = error {
                print("获取\(folderName)中的文件失败: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            // 打印所有文件名进行调试
            print("文件夹 \(folderName) 中的文件:")
            for file in files {
                print("  - \(file.name) (路径: \(file.fullPath))")
            }
            
            // 分离图片文件和配置文件
            let imageFiles = files.filter { 
                $0.name.lowercased().hasSuffix(".jpg") || 
                $0.name.lowercased().hasSuffix(".jpeg") ||
                $0.name.lowercased().hasSuffix(".png") 
            }
            
            // 尝试多种可能的配置文件名
            var configFile = files.first { $0.name.lowercased() == "config.json" }
            if configFile == nil {
                configFile = files.first { $0.name.lowercased() == "config" }
            }
            if configFile == nil {
                configFile = files.first { $0.name.lowercased().contains("config") }
            }
            if configFile == nil {
                configFile = files.first { $0.name.lowercased().contains("json") }
            }
            
            print("找到的图片文件数量: \(imageFiles.count)")
            print("配置文件: \(configFile?.name ?? "未找到")")
            
            // 如果找到配置文件，解析它获取卡片分类和文案
            if let configFile = configFile {
                print("正在解析配置文件: \(configFile.name)")
                
                self.storageService.getJSONFile(reference: configFile, type: WordCard.CardConfig.self) { config, error in
                    if let error = error {
                        print("解析配置文件失败: \(error.localizedDescription)")
                        // 尝试读取为文本，看看内容是什么
                        self.storageService.getTextFile(reference: configFile) { text, _ in
                            if let text = text {
                                print("配置文件内容: \(text)")
                            }
                            // 如果没有配置文件或解析失败，使用默认值
                            self.createDefaultCard(folderName: folderName, imageFiles: imageFiles, completion: completion)
                        }
                        return
                    }
                    
                    if let config = config {
                        print("成功解析配置: category=\(config.category), captions=\(config.captions)")
                        
                        // 解析分类
                        let categoryKey: LocalizedText.WordCardGallery
                        switch config.category.lowercased() {
                        case "grace":
                            categoryKey = .categoryGrace
                        case "encouragement":
                            categoryKey = .categoryEncouragement
                        case "wisdom":
                            categoryKey = .categoryWisdom
                        default:
                            print("未知分类: \(config.category)，使用默认分类")
                            categoryKey = .categoryAll
                        }
                        
                        // 创建文案
                        let caption = CardCaption(
                            chinese: config.captions.chinese,
                            english: config.captions.english,
                            korean: config.captions.korean
                        )
                        
                        let card = WordCard(
                            folderName: folderName,
                            images: imageFiles,
                            caption: caption,
                            categoryKey: categoryKey
                        )
                        
                        print("成功从配置文件创建卡片，分类: \(categoryKey)")
                        completion(card)
                    } else {
                        print("配置解析结果为nil")
                        self.createDefaultCard(folderName: folderName, imageFiles: imageFiles, completion: completion)
                    }
                }
            } else {
                print("未找到配置文件，使用默认设置")
                self.createDefaultCard(folderName: folderName, imageFiles: imageFiles, completion: completion)
            }
        }
    }
    
    // 当没有配置文件或解析失败时，创建一个默认卡片
    private func createDefaultCard(folderName: String, imageFiles: [StorageReference], completion: @escaping (WordCard?) -> Void) {
        print("为\(folderName)创建默认卡片")
        // 如果没有配置文件，使用默认值
        let defaultCaption = CardCaption(
            chinese: folderName,  // 使用文件夹名称作为默认文案
            english: folderName,
            korean: folderName
        )
        
        let card = WordCard(
            folderName: folderName,
            images: imageFiles,
            caption: defaultCaption,
            categoryKey: .categoryAll
        )
        
        completion(card)
    }
} 