import SwiftUI
import FirebaseFirestore

// 赞美（诗歌/乐谱）数据模型
struct Praise: Codable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var fileUrls: [String] // 乐谱图片或PDF的URL
    var uploadedAt: Timestamp
    
    // 初始化方法
    init(id: String? = nil, title: String, fileUrls: [String], uploadedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.fileUrls = fileUrls
        self.uploadedAt = Timestamp(date: uploadedAt)
    }
}

// 赞美视图模型
class PraiseViewModel: ObservableObject {
    @Published var praises: [Praise] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    func loadPraises() {
        isLoading = true
        errorMessage = nil
        
        listenerRegistration?.remove()
        
        listenerRegistration = db.collection("praises")
            .order(by: "uploadedAt", descending: true)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("Error loading praises: \(error.localizedDescription)")
                        self.errorMessage = "加载赞美诗歌失败: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        print("No praises found")
                        return
                    }
                    
                    var fetchedPraises: [Praise] = []
                    
                    for document in documents {
                        do {
                            let praise = try document.data(as: Praise.self)
                            fetchedPraises.append(praise)
                        } catch {
                            print("Error decoding praise: \(document.documentID) - \(error)")
                        }
                    }
                    
                    self.praises = fetchedPraises
                    print("Found \(self.praises.count) praises")
                }
            }
    }
    
    deinit {
        listenerRegistration?.remove()
    }
}
