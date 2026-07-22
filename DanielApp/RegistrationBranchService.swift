import Foundation
import FirebaseFirestore

struct RegistrationBranch: Identifiable, Equatable {
    let id: String
    let orgId: String
    let regionId: String
    let nameZh: String
    let nameEn: String
    let nameKo: String
    let regionNameZh: String
    let regionNameEn: String
    let regionNameKo: String
    let country: String
    let isActive: Bool

    init(
        id: String,
        orgId: String = "daniel-branch-church",
        regionId: String,
        nameZh: String,
        nameEn: String? = nil,
        nameKo: String? = nil,
        regionNameZh: String,
        regionNameEn: String? = nil,
        regionNameKo: String? = nil,
        country: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.orgId = orgId
        self.regionId = regionId
        self.nameZh = nameZh
        self.nameEn = nameEn ?? nameZh
        self.nameKo = nameKo ?? nameZh
        self.regionNameZh = regionNameZh
        self.regionNameEn = regionNameEn ?? regionNameZh
        self.regionNameKo = regionNameKo ?? regionNameZh
        self.country = country
        self.isActive = isActive
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        let name = data["name"] as? [String: Any] ?? [:]
        let regionName = data["regionName"] as? [String: Any] ?? [:]

        self.id = (data["id"] as? String)?.nilIfEmpty ?? document.documentID
        self.orgId = (data["orgId"] as? String)?.nilIfEmpty ?? "daniel-branch-church"
        self.regionId = (data["regionId"] as? String)?.nilIfEmpty ?? ""
        self.nameZh = (name["zh"] as? String)?.nilIfEmpty ?? self.id
        self.nameEn = (name["en"] as? String)?.nilIfEmpty ?? self.nameZh
        self.nameKo = (name["ko"] as? String)?.nilIfEmpty ?? self.nameZh
        self.regionNameZh = (regionName["zh"] as? String)?.nilIfEmpty ?? self.regionId
        self.regionNameEn = (regionName["en"] as? String)?.nilIfEmpty ?? self.regionNameZh
        self.regionNameKo = (regionName["ko"] as? String)?.nilIfEmpty ?? self.regionNameZh
        self.country = (data["country"] as? String)?.nilIfEmpty ?? self.regionNameEn
        self.isActive = data["isActive"] as? Bool ?? true
    }

    func name(for language: CoreModels.VerseLanguage) -> String {
        switch language {
        case .chinese: return nameZh
        case .english: return nameEn
        case .korean: return nameKo
        }
    }

    func regionName(for language: CoreModels.VerseLanguage) -> String {
        switch language {
        case .chinese: return regionNameZh
        case .english: return regionNameEn
        case .korean: return regionNameKo
        }
    }
}

protocol RegistrationBranchRemoteStore {
    func fetchActiveBranches(completion: @escaping (Result<[RegistrationBranch], Error>) -> Void)
}

final class FirestoreRegistrationBranchRemoteStore: RegistrationBranchRemoteStore {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func fetchActiveBranches(completion: @escaping (Result<[RegistrationBranch], Error>) -> Void) {
        db.collection("branches")
            .whereField("isActive", isEqualTo: true)
            .order(by: "sortOrder")
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let branches = snapshot?.documents.compactMap(RegistrationBranch.init(document:)) ?? []
                completion(.success(branches.filter(\.isActive)))
            }
    }
}

final class RegistrationBranchViewModel: ObservableObject {
    @Published private(set) var branches: [RegistrationBranch] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let remoteStore: RegistrationBranchRemoteStore
    private var hasLoaded = false

    init(remoteStore: RegistrationBranchRemoteStore = FirestoreRegistrationBranchRemoteStore()) {
        self.remoteStore = remoteStore
    }

    func loadBranchesIfNeeded() {
        guard !hasLoaded, !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil

        remoteStore.fetchActiveBranches { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                self.hasLoaded = true

                switch result {
                case .success(let branches):
                    self.branches = branches
                    self.errorMessage = nil
                case .failure(let error):
                    self.branches = []
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
