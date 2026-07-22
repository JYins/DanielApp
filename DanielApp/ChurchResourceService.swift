import Foundation
import FirebaseFirestore

struct LocalizedResourceText: Equatable {
    let chinese: String
    let english: String
    let korean: String

    init(chinese: String, english: String, korean: String) {
        self.chinese = chinese
        self.english = english
        self.korean = korean
    }

    init(dictionary: [String: Any]) {
        let zh = dictionary["zh"] as? String
        let en = dictionary["en"] as? String
        let ko = dictionary["ko"] as? String
        chinese = zh ?? en ?? ko ?? ""
        english = en ?? zh ?? ko ?? ""
        korean = ko ?? zh ?? en ?? ""
    }

    func text(for language: CoreModels.VerseLanguage) -> String {
        switch language {
        case .chinese: return chinese
        case .english: return english
        case .korean: return korean
        }
    }

    var firestoreValue: [String: String] {
        [
            "zh": chinese,
            "en": english,
            "ko": korean
        ]
    }
}

enum ChurchResourceCategory: String, CaseIterable, Identifiable {
    case all
    case hymnbook
    case documents
    case links
    case bibleStudy
    case seminar
    case questions

    var id: String { rawValue }

    static let libraryCategories: [ChurchResourceCategory] = [.hymnbook, .seminar, .bibleStudy, .questions, .links]

    init(resourceType: String) {
        switch resourceType {
        case "hymnbook":
            self = .hymnbook
        case "church_documents", "documents":
            self = .documents
        case "useful_links", "links":
            self = .links
        case "bible_study":
            self = .bibleStudy
        case "bible_seminar", "seminar":
            self = .seminar
        case "q_and_a", "questions", "qa":
            self = .questions
        default:
            self = .documents
        }
    }

    func title(for language: CoreModels.VerseLanguage) -> String {
        switch self {
        case .all:
            return LocalizedText.Resources.categoryAll.text(for: language)
        case .hymnbook:
            return LocalizedText.Resources.categoryHymnbook.text(for: language)
        case .documents:
            return LocalizedText.Resources.categoryDocuments.text(for: language)
        case .links:
            return LocalizedText.Resources.categoryLinks.text(for: language)
        case .bibleStudy:
            return LocalizedText.Resources.categoryBibleStudy.text(for: language)
        case .seminar:
            return LocalizedText.Resources.categorySeminar.text(for: language)
        case .questions:
            return LocalizedText.Resources.categoryQuestions.text(for: language)
        }
    }
}

struct ChurchResource: Identifiable {
    let id: String
    let type: String
    let category: ChurchResourceCategory
    let categoryKey: String
    let title: LocalizedResourceText
    let subtitle: LocalizedResourceText
    let description: LocalizedResourceText
    let actionTitle: LocalizedResourceText
    let url: URL?
    let content: String?
    var storagePath: String? = nil
    var fileName: String? = nil
    var fileSize: Int = 0
    var fileType: String? = nil
    var downloadURL: URL? = nil
    var audioURL: URL? = nil
    let icon: String
    let isPublished: Bool
    let accessLevel: String
    let sortOrder: Int
    let updatedAt: Date
    let createdAt: Date

    var searchableTextKeys: [LocalizedResourceText] {
        [title, subtitle, description, actionTitle]
    }

    var primaryURL: URL? {
        downloadURL ?? url
    }

    var pdfURL: URL? {
        guard isPDFResource else { return nil }
        return downloadURL ?? url
    }

    var hasHymnMedia: Bool {
        category == .hymnbook && (pdfURL != nil || audioURL != nil)
    }

    var isPDFResource: Bool {
        fileType == "application/pdf" ||
        storagePath?.lowercased().hasSuffix(".pdf") == true ||
        fileName?.lowercased().hasSuffix(".pdf") == true ||
        primaryURL?.absoluteString.lowercased().contains(".pdf") == true
    }
}

extension ChurchResource {
    init?(id documentID: String, data: [String: Any]) {
        let id = (data["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = (data["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let categoryKey = (data["category"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? type

        guard !type.isEmpty else {
            return nil
        }

        self.id = id?.isEmpty == false ? id! : documentID
        self.type = type
        self.categoryKey = categoryKey
        category = ChurchResourceCategory(resourceType: type)
        title = LocalizedResourceText(dictionary: data["title"] as? [String: Any] ?? [:])
        subtitle = LocalizedResourceText(dictionary: data["subtitle"] as? [String: Any] ?? [:])
        description = LocalizedResourceText(dictionary: data["description"] as? [String: Any] ?? [:])
        actionTitle = LocalizedResourceText(dictionary: data["actionTitle"] as? [String: Any] ?? [:])

        url = Self.safeRemoteURL(from: data["url"] as? String)

        content = data["content"] as? String
        storagePath = data["storagePath"] as? String
        fileName = data["fileName"] as? String
        fileSize = data["fileSize"] as? Int ?? 0
        fileType = data["fileType"] as? String
        downloadURL = Self.safeRemoteURL(from: data["downloadURL"] as? String)
        audioURL = Self.safeRemoteURL(from: data["audioDownloadURL"] as? String)
            ?? Self.safeRemoteURL(from: data["audioURL"] as? String)
        icon = data["icon"] as? String ?? "doc.text"
        isPublished = data["isPublished"] as? Bool ?? false
        accessLevel = data["accessLevel"] as? String ?? "public"
        sortOrder = data["sortOrder"] as? Int ?? 999
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
    }

    private static func safeRemoteURL(from value: String?) -> URL? {
        guard let value,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            return nil
        }
        return url
    }
}

enum ChurchResourceSource: Equatable {
    case localSeed
    case firebase
    case localFallback(reason: String)
}

protocol ChurchResourceRemoteStore {
    func fetchPublishedResources(completion: @escaping (Result<[ChurchResource], Error>) -> Void)
}

final class FirestoreChurchResourceRemoteStore: ChurchResourceRemoteStore {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func fetchPublishedResources(completion: @escaping (Result<[ChurchResource], Error>) -> Void) {
        db.collection("resources")
            .whereField("isPublished", isEqualTo: true)
            .order(by: "sortOrder", descending: false)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let resources = snapshot?.documents.compactMap { document in
                    ChurchResource(id: document.documentID, data: document.data())
                } ?? []
                completion(.success(resources))
            }
    }
}

final class ChurchResourceService: ObservableObject {
    @Published private(set) var resources: [ChurchResource] = LocalChurchResourceSeed.resources
    @Published private(set) var isLoading = false
    @Published private(set) var source: ChurchResourceSource = .localSeed
    @Published private(set) var errorMessage: String?

    private let remoteStore: ChurchResourceRemoteStore
    private let localSeed: [ChurchResource]

    init(
        remoteStore: ChurchResourceRemoteStore = FirestoreChurchResourceRemoteStore(),
        localSeed: [ChurchResource] = LocalChurchResourceSeed.resources
    ) {
        self.remoteStore = remoteStore
        self.localSeed = localSeed
        self.resources = localSeed
    }

    func loadResources() {
        isLoading = true
        errorMessage = nil

        remoteStore.fetchPublishedResources { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false

                switch result {
                case .failure(let error):
                    self.useLocalFallback(reason: error.localizedDescription)
                case .success(let fetchedResources):
                    guard !fetchedResources.isEmpty else {
                        self.useLocalFallback(reason: "Firebase resources collection is empty or unavailable.")
                        return
                    }

                    self.resources = Self.sortedResources(fetchedResources)
                    self.source = .firebase
                    self.errorMessage = nil
                }
            }
        }
    }

    func filteredResources(
        searchText: String,
        selectedCategory: ChurchResourceCategory,
        language: CoreModels.VerseLanguage
    ) -> [ChurchResource] {
        resources.filter { resource in
            let matchesCategory = selectedCategory == .all || resource.category == selectedCategory
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matchesSearch = query.isEmpty || resource.searchableTextKeys.contains {
                $0.text(for: language).lowercased().contains(query)
            } || resource.category.title(for: language).lowercased().contains(query) || resource.categoryKey.lowercased().contains(query)

            return matchesCategory && matchesSearch
        }
    }

    private func useLocalFallback(reason: String) {
        resources = localSeed
        source = .localFallback(reason: reason)
        errorMessage = reason
    }

    private static func sortedResources(_ resources: [ChurchResource]) -> [ChurchResource] {
        resources.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.title.chinese < $1.title.chinese
            }
            return $0.sortOrder < $1.sortOrder
        }
    }
}

enum LocalChurchResourceSeed {
    static let resources: [ChurchResource] = [
        ChurchResource(
            id: "hymnbook",
            type: "hymnbook",
            category: .hymnbook,
            categoryKey: "worship",
            title: LocalizedResourceText(chinese: "诗歌本", english: "Hymnbook", korean: "찬송가"),
            subtitle: LocalizedResourceText(chinese: "赞美诗、谱面与敬拜资源", english: "Hymns, song sheets, and worship resources", korean: "찬양, 악보와 예배 자료"),
            description: LocalizedResourceText(
                chinese: "管理员可以为每首诗歌配置 PDF 乐谱和音频；播放音频时仍可继续阅读和翻页。",
                english: "Administrators can attach PDF sheet music and audio so you can keep listening while reading and turning pages.",
                korean: "관리자는 찬송가 PDF 악보와 오디오를 함께 등록할 수 있으며, 재생 중에도 계속 읽고 페이지를 넘길 수 있습니다."
            ),
            actionTitle: LocalizedResourceText(chinese: "打开诗歌本", english: "Open Hymnbook", korean: "찬송가 열기"),
            url: nil,
            content: nil,
            icon: "music.note.list",
            isPublished: true,
            accessLevel: "public",
            sortOrder: 10,
            updatedAt: Date(timeIntervalSince1970: 1_735_689_600),
            createdAt: Date(timeIntervalSince1970: 1_735_689_600)
        ),
        ChurchResource(
            id: "church-documents",
            type: "church_documents",
            category: .documents,
            categoryKey: "documents",
            title: LocalizedResourceText(chinese: "教会文件", english: "Church Documents", korean: "교회 문서"),
            subtitle: LocalizedResourceText(chinese: "共同阅读的文件、PDF 与说明", english: "Shared documents, PDFs, and guides", korean: "함께 읽는 문서, PDF와 안내"),
            description: LocalizedResourceText(
                chinese: "可用于放置信仰基础、聚会说明、服事守则和其他公开材料。第一阶段使用本地目录，后续再交给 admin 管理。",
                english: "Use this for faith foundations, meeting guides, serving guidelines, and other shared materials. This phase uses local seed data before admin management is added.",
                korean: "신앙 기초, 모임 안내, 섬김 지침과 공유 자료를 담을 수 있습니다. 첫 단계는 로컬 자료로 시작하고 이후 관리자 관리로 확장합니다."
            ),
            actionTitle: LocalizedResourceText(chinese: "查看文件", english: "View Documents", korean: "문서 보기"),
            url: nil,
            content: nil,
            icon: "doc.text",
            isPublished: true,
            accessLevel: "public",
            sortOrder: 20,
            updatedAt: Date(timeIntervalSince1970: 1_735_689_600),
            createdAt: Date(timeIntervalSince1970: 1_735_689_600)
        ),
        ChurchResource(
            id: "useful-links",
            type: "useful_links",
            category: .links,
            categoryKey: "links",
            title: LocalizedResourceText(chinese: "常用链接", english: "Useful Links", korean: "유용한 링크"),
            subtitle: LocalizedResourceText(chinese: "官方网站、视频、报名与外部资源", english: "Official sites, videos, signups, and external resources", korean: "공식 사이트, 영상, 신청과 외부 자료"),
            description: LocalizedResourceText(
                chinese: "这里可以集中整理教会官网、YouTube、Instagram、活动报名和长期资源链接。",
                english: "Collect church websites, YouTube, Instagram, event signups, and long-lived resource links here.",
                korean: "교회 웹사이트, YouTube, Instagram, 행사 신청과 장기 자료 링크를 모아둘 수 있습니다."
            ),
            actionTitle: LocalizedResourceText(chinese: "打开链接", english: "Open Links", korean: "링크 열기"),
            url: URL(string: "https://www.youtube.com/channel/UCv_vGKqXZGHjO6jRYQtufuA"),
            content: nil,
            icon: "link",
            isPublished: true,
            accessLevel: "public",
            sortOrder: 30,
            updatedAt: Date(timeIntervalSince1970: 1_735_689_600),
            createdAt: Date(timeIntervalSince1970: 1_735_689_600)
        ),
        ChurchResource(
            id: "bible-study",
            type: "bible_study",
            category: .bibleStudy,
            categoryKey: "study",
            title: LocalizedResourceText(chinese: "圣经学习", english: "Bible Study", korean: "성경 공부"),
            subtitle: LocalizedResourceText(chinese: "按主题或书卷整理的学习材料", english: "Study materials by topic or Bible book", korean: "주제나 성경 권별 학습 자료"),
            description: LocalizedResourceText(
                chinese: "对应 Figma 中按书卷、主题和问答展开的 Bible Study 方向。第一版先提供本地条目和详情页。",
                english: "This follows the Figma direction for Bible Study by book, topic, and Q&A. The first phase provides local entries and detail pages.",
                korean: "Figma의 성경 권별, 주제별, Q&A 성경 공부 방향을 따릅니다. 첫 단계는 로컬 항목과 상세 화면을 제공합니다."
            ),
            actionTitle: LocalizedResourceText(chinese: "开始学习", english: "Start Study", korean: "공부 시작"),
            url: nil,
            content: nil,
            icon: "book",
            isPublished: true,
            accessLevel: "public",
            sortOrder: 40,
            updatedAt: Date(timeIntervalSince1970: 1_735_689_600),
            createdAt: Date(timeIntervalSince1970: 1_735_689_600)
        ),
        ChurchResource(
            id: "bible-seminar",
            type: "bible_seminar",
            category: .seminar,
            categoryKey: "seminar",
            title: LocalizedResourceText(chinese: "圣经讲座", english: "Bible Seminar", korean: "성경 세미나"),
            subtitle: LocalizedResourceText(chinese: "讲座、课程与集体学习安排", english: "Seminars, courses, and group study plans", korean: "세미나, 과정과 공동 학습 일정"),
            description: LocalizedResourceText(
                chinese: "未来可接入活动报名、讲义 PDF 和讲座回放。当前先提供产品结构和可点击详情。",
                english: "This can later connect to event registration, handout PDFs, and seminar replays. For now it establishes the product structure and clickable detail.",
                korean: "추후 행사 신청, 강의안 PDF와 세미나 다시보기로 연결할 수 있습니다. 현재는 제품 구조와 상세 화면을 먼저 마련합니다."
            ),
            actionTitle: LocalizedResourceText(chinese: "查看讲座", english: "View Seminars", korean: "세미나 보기"),
            url: nil,
            content: nil,
            icon: "person.2.wave.2",
            isPublished: true,
            accessLevel: "public",
            sortOrder: 50,
            updatedAt: Date(timeIntervalSince1970: 1_735_689_600),
            createdAt: Date(timeIntervalSince1970: 1_735_689_600)
        ),
        ChurchResource(
            id: "questions-and-answers",
            type: "q_and_a",
            category: .questions,
            categoryKey: "questions",
            title: LocalizedResourceText(chinese: "信仰问答", english: "Q & A", korean: "신앙 문답"),
            subtitle: LocalizedResourceText(chinese: "常见问题与圣经依据", english: "Common questions and biblical guidance", korean: "자주 묻는 질문과 성경적 안내"),
            description: LocalizedResourceText(
                chinese: "按主题整理常见信仰问题、经文依据和进一步学习资料。管理员可以持续发布经过审核的公开内容。",
                english: "Explore common faith questions, biblical references, and reviewed follow-up resources published by administrators.",
                korean: "자주 묻는 신앙 질문, 성경 근거와 관리자가 검토해 게시한 추가 자료를 주제별로 살펴보세요."
            ),
            actionTitle: LocalizedResourceText(chinese: "查看问答", english: "Browse Q & A", korean: "문답 보기"),
            url: nil,
            content: nil,
            icon: "questionmark.bubble",
            isPublished: true,
            accessLevel: "public",
            sortOrder: 45,
            updatedAt: Date(timeIntervalSince1970: 1_735_689_600),
            createdAt: Date(timeIntervalSince1970: 1_735_689_600)
        )
    ]
}
