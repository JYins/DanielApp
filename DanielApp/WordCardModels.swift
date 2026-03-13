import SwiftUI
import FirebaseFirestore
import Combine

// 卡片文案的多语言支持
struct CardCaption: Codable {
    let chinese: String
    let english: String
    let korean: String
    
    func text(for language: CoreModels.VerseLanguage) -> String {
        switch language {
        case .chinese: return chinese
        case .english: return english
        case .korean: return korean
        }
    }
}

// 卡片分类数据模型
struct WordCardCategory: Identifiable {
    let id: String
    let name: String // 中文名
    let koreanName: String // 韩文名
    var cards: [WordCard] = []
}

// 卡片数据模型
struct WordCard: Identifiable, Codable {
    @DocumentID var id: String?
    let title: String
    let category: String
    let caption_cn: String
    let caption_en: String
    let caption_kr: String
    let image_urls: [String]
    let published: Bool
    let order: Int
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
    
    // Compatibility helpers for the old UI
    var folderName: String { id ?? "unknown" }
    var caption: CardCaption {
        CardCaption(chinese: caption_cn, english: caption_en, korean: caption_kr)
    }
    
    var categoryKey: LocalizedText.WordCardGallery {
        switch category.lowercased() {
        case "grace": return .categoryGrace
        case "encouragement": return .categoryEncouragement
        case "wisdom": return .categoryWisdom
        default: return .categoryAll
        }
    }
}

// WordCardViewModel用于加载和管理卡片数据
class WordCardViewModel: ObservableObject {
    @Published var categories: [WordCardCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    func loadCards() {
        isLoading = true
        errorMessage = nil
        
        listenerRegistration?.remove()
        
        listenerRegistration = db.collection("wordCards")
            .whereField("published", isEqualTo: true)
            .order(by: "order", descending: false)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let self = self else { return }
                
                print("Snapshot listener fired with error: \(String(describing: error))")
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("Error loading word cards: \(error.localizedDescription)")
                        self.errorMessage = "加载话语卡片失败: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        print("No documents found")
                        return
                    }
                    
                    print("Found \(documents.count) published word cards")
                    
                    var allCards: [WordCard] = []
                    var categoryMap: [String: WordCardCategory] = [
                        "grace": WordCardCategory(id: "grace", name: "恩典", koreanName: "은혜", cards: []),
                        "encouragement": WordCardCategory(id: "encouragement", name: "鼓励", koreanName: "격려", cards: []),
                        "wisdom": WordCardCategory(id: "wisdom", name: "智慧", koreanName: "지혜", cards: [])
                    ]
                    
                    for document in documents {
                        do {
                            let card = try document.data(as: WordCard.self)
                            allCards.append(card)
                            
                            let catKey = card.category.lowercased()
                            if categoryMap[catKey] != nil {
                                categoryMap[catKey]?.cards.append(card)
                            } else {
                                // Default back to a generic folder if category is unknown
                                categoryMap[catKey] = WordCardCategory(
                                    id: catKey,
                                    name: card.category,
                                    koreanName: card.category,
                                    cards: [card]
                                )
                            }
                        } catch {
                            print("Error decoding word card: \(document.documentID) - \(error)")
                        }
                    }
                    
                    var loadedCategories: [WordCardCategory] = []
                    
                    // Add "All" category at the beginning if there are cards
                    if !allCards.isEmpty {
                        let allCategory = WordCardCategory(
                            id: "all",
                            name: "全部",
                            koreanName: "전체",
                            cards: allCards
                        )
                        loadedCategories.append(allCategory)
                    }
                    
                    // Add standard categories 
                    if let grace = categoryMap["grace"], !grace.cards.isEmpty { loadedCategories.append(grace) }
                    if let encouragement = categoryMap["encouragement"], !encouragement.cards.isEmpty { loadedCategories.append(encouragement) }
                    if let wisdom = categoryMap["wisdom"], !wisdom.cards.isEmpty { loadedCategories.append(wisdom) }
                    
                    // Add any other dynamic categories
                    let standardKeys = Set(["grace", "encouragement", "wisdom"])
                    for (key, cat) in categoryMap {
                        if !standardKeys.contains(key) && !cat.cards.isEmpty {
                            loadedCategories.append(cat)
                        }
                    }
                    
                    self.categories = loadedCategories
                    print("Finished mapping cards to \(loadedCategories.count) categories")
                }
            }
    }
    
    // Optional: Refresh method if we want to force manual reload
    func refresh() {
        loadCards()
    }
    
    deinit {
        listenerRegistration?.remove()
    }
}
