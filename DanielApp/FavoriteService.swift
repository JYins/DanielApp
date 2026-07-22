import Foundation
import FirebaseFirestore

enum FavoriteTargetType: String, Codable, CaseIterable {
    case verse
    case resource
    case pdfPage
    case connectPost
    case newsletter
}

struct FavoriteRecord: Identifiable, Equatable {
    let id: String
    var targetType: FavoriteTargetType
    var targetId: String
    var reference: String?
    var resourceId: String?
    var pageNumber: Int?
    var title: LocalizedResourceText
    var snippet: LocalizedResourceText
    var dateKey: String
    var createdAt: Date
    var updatedAt: Date

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "targetType": targetType.rawValue,
            "targetId": targetId,
            "title": title.firestoreValue,
            "snippet": snippet.firestoreValue,
            "dateKey": dateKey,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]

        if let reference { data["reference"] = reference }
        if let resourceId { data["resourceId"] = resourceId }
        if let pageNumber { data["pageNumber"] = pageNumber }
        return data
    }

    init(
        id: String,
        targetType: FavoriteTargetType,
        targetId: String,
        reference: String? = nil,
        resourceId: String? = nil,
        pageNumber: Int? = nil,
        title: LocalizedResourceText,
        snippet: LocalizedResourceText,
        dateKey: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.targetType = targetType
        self.targetId = targetId
        self.reference = reference
        self.resourceId = resourceId
        self.pageNumber = pageNumber
        self.title = title
        self.snippet = snippet
        self.dateKey = dateKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let targetTypeValue = data["targetType"] as? String,
              let targetType = FavoriteTargetType(rawValue: targetTypeValue),
              let targetId = data["targetId"] as? String,
              let titleData = data["title"] as? [String: Any],
              let snippetData = data["snippet"] as? [String: Any],
              let dateKey = data["dateKey"] as? String else {
            return nil
        }

        id = document.documentID
        self.targetType = targetType
        self.targetId = targetId
        reference = data["reference"] as? String
        resourceId = data["resourceId"] as? String
        pageNumber = data["pageNumber"] as? Int
        title = LocalizedResourceText(dictionary: titleData)
        snippet = LocalizedResourceText(dictionary: snippetData)
        self.dateKey = dateKey
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
    }
}

struct NoteRecord: Identifiable, Equatable {
    let id: String
    var targetType: FavoriteTargetType
    var targetId: String
    var reference: String?
    var body: String
    var language: String
    var isPrivate: Bool
    var createdAt: Date
    var updatedAt: Date

    var firestoreData: [String: Any] {
        var data: [String: Any] = [
            "targetType": targetType.rawValue,
            "targetId": targetId,
            "body": body,
            "language": language,
            "isPrivate": isPrivate,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
        if let reference { data["reference"] = reference }
        return data
    }

    init(
        id: String,
        targetType: FavoriteTargetType,
        targetId: String,
        reference: String? = nil,
        body: String,
        language: String,
        isPrivate: Bool = true,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.targetType = targetType
        self.targetId = targetId
        self.reference = reference
        self.body = body
        self.language = language
        self.isPrivate = isPrivate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let targetTypeValue = data["targetType"] as? String,
              let targetType = FavoriteTargetType(rawValue: targetTypeValue),
              let targetId = data["targetId"] as? String,
              let body = data["body"] as? String,
              let language = data["language"] as? String else {
            return nil
        }

        id = document.documentID
        self.targetType = targetType
        self.targetId = targetId
        reference = data["reference"] as? String
        self.body = body
        self.language = language
        isPrivate = data["isPrivate"] as? Bool ?? true
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
    }
}

protocol FavoriteRemoteStore {
    func fetchFavorites(userID: String, completion: @escaping (Result<[FavoriteRecord], Error>) -> Void)
    func saveFavorite(userID: String, favorite: FavoriteRecord, completion: @escaping (Error?) -> Void)
    func deleteFavorite(userID: String, favoriteID: String, completion: @escaping (Error?) -> Void)
}

protocol NoteRemoteStore {
    func fetchNotes(userID: String, completion: @escaping (Result<[NoteRecord], Error>) -> Void)
    func saveNote(userID: String, note: NoteRecord, completion: @escaping (Error?) -> Void)
}

final class FirestoreFavoriteRemoteStore: FavoriteRemoteStore, NoteRemoteStore {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func fetchFavorites(userID: String, completion: @escaping (Result<[FavoriteRecord], Error>) -> Void) {
        db.collection("users")
            .document(userID)
            .collection("favorites")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                completion(.success(snapshot?.documents.compactMap(FavoriteRecord.init(document:)) ?? []))
            }
    }

    func saveFavorite(userID: String, favorite: FavoriteRecord, completion: @escaping (Error?) -> Void) {
        db.collection("users")
            .document(userID)
            .collection("favorites")
            .document(favorite.id)
            .setData(favorite.firestoreData, merge: true, completion: completion)
    }

    func deleteFavorite(userID: String, favoriteID: String, completion: @escaping (Error?) -> Void) {
        db.collection("users")
            .document(userID)
            .collection("favorites")
            .document(favoriteID)
            .delete(completion: completion)
    }

    func fetchNotes(userID: String, completion: @escaping (Result<[NoteRecord], Error>) -> Void) {
        db.collection("users")
            .document(userID)
            .collection("notes")
            .order(by: "updatedAt", descending: true)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                completion(.success(snapshot?.documents.compactMap(NoteRecord.init(document:)) ?? []))
            }
    }

    func saveNote(userID: String, note: NoteRecord, completion: @escaping (Error?) -> Void) {
        db.collection("users")
            .document(userID)
            .collection("notes")
            .document(note.id)
            .setData(note.firestoreData, merge: true, completion: completion)
    }
}

@MainActor
final class FavoriteService: ObservableObject {
    static let shared = FavoriteService()

    @Published private(set) var favorites: [FavoriteRecord] = []
    @Published private(set) var notes: [NoteRecord] = []
    @Published private(set) var lastSyncError: String?

    private let favoriteRemoteStore: FavoriteRemoteStore
    private let noteRemoteStore: NoteRemoteStore
    private let currentUserIDProvider: () -> String?
    private let defaults: UserDefaults
    private let favoritesStorageKey = "daniel.unifiedFavorites"
    private let notesStorageKey = "daniel.unifiedNotes"
    private var isSyncing = false

    init(
        favoriteRemoteStore: FavoriteRemoteStore = FirestoreFavoriteRemoteStore(),
        noteRemoteStore: NoteRemoteStore = FirestoreFavoriteRemoteStore(),
        currentUserIDProvider: @escaping () -> String? = { AuthManager.shared.currentAuthenticatedUserID },
        defaults: UserDefaults = VerseDataService.shared.getSharedDefaults()
    ) {
        self.favoriteRemoteStore = favoriteRemoteStore
        self.noteRemoteStore = noteRemoteStore
        self.currentUserIDProvider = currentUserIDProvider
        self.defaults = defaults
        loadLocal()
    }

    func loadLocal() {
        favorites = loadStoredFavorites()
        notes = loadStoredNotes()
    }

    func favoriteID(targetType: FavoriteTargetType, targetId: String) -> String {
        "\(targetType.rawValue)_\(targetId)"
            .replacingOccurrences(of: "/", with: "／")
            .replacingOccurrences(of: " ", with: "_")
    }

    func isFavorite(targetType: FavoriteTargetType, targetId: String) -> Bool {
        favorites.contains { $0.targetType == targetType && $0.targetId == targetId }
    }

    func favorite(for targetType: FavoriteTargetType, targetId: String) -> FavoriteRecord? {
        favorites.first { $0.targetType == targetType && $0.targetId == targetId }
    }

    func note(for targetType: FavoriteTargetType, targetId: String) -> NoteRecord? {
        notes.first { $0.targetType == targetType && $0.targetId == targetId }
    }

    func toggleFavorite(_ favorite: FavoriteRecord) {
        if let existing = self.favorite(for: favorite.targetType, targetId: favorite.targetId) {
            favorites.removeAll { $0.id == existing.id }
            saveLocalFavorites()
            if let userID = currentUserIDProvider() {
                favoriteRemoteStore.deleteFavorite(userID: userID, favoriteID: existing.id) { [weak self] error in
                    if let error {
                        Task { @MainActor in self?.lastSyncError = error.localizedDescription }
                    }
                }
            }
        } else {
            favorites.insert(favorite, at: 0)
            sortFavorites()
            saveLocalFavorites()
            pushFavoriteIfSignedIn(favorite)
        }
    }

    func saveNote(targetType: FavoriteTargetType, targetId: String, reference: String?, body: String, language: CoreModels.VerseLanguage) -> Bool {
        guard let _ = currentUserIDProvider() else {
            return false
        }

        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        let note = NoteRecord(
            id: favoriteID(targetType: targetType, targetId: targetId),
            targetType: targetType,
            targetId: targetId,
            reference: reference,
            body: trimmed,
            language: language.rawValue,
            createdAt: note(for: targetType, targetId: targetId)?.createdAt ?? now,
            updatedAt: now
        )

        notes.removeAll { $0.id == note.id }
        if !trimmed.isEmpty {
            notes.insert(note, at: 0)
        }
        saveLocalNotes()

        if !trimmed.isEmpty {
            pushNoteIfSignedIn(note)
        }
        return true
    }

    func syncFromFirebaseIfSignedIn() {
        guard !isSyncing, let userID = currentUserIDProvider() else {
            return
        }

        isSyncing = true
        lastSyncError = nil
        let group = DispatchGroup()
        var remoteFavorites: [FavoriteRecord]?
        var remoteNotes: [NoteRecord]?
        var syncError: Error?

        group.enter()
        favoriteRemoteStore.fetchFavorites(userID: userID) { result in
            if case .success(let records) = result {
                remoteFavorites = records
            } else if case .failure(let error) = result {
                syncError = error
            }
            group.leave()
        }

        group.enter()
        noteRemoteStore.fetchNotes(userID: userID) { result in
            if case .success(let records) = result {
                remoteNotes = records
            } else if case .failure(let error) = result {
                syncError = error
            }
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isSyncing = false

            if let syncError {
                self.lastSyncError = syncError.localizedDescription
                return
            }

            if let remoteFavorites {
                self.mergeRemoteFavorites(remoteFavorites)
            }
            if let remoteNotes {
                self.notes = remoteNotes.sorted { $0.updatedAt > $1.updatedAt }
                self.saveLocalNotes()
            }
            self.pushLocalFavoritesToFirebaseIfSignedIn()
        }
    }

    func makeVerseFavorite(verse: MultiLanguageVerse) -> FavoriteRecord {
        let now = Date()
        return FavoriteRecord(
            id: favoriteID(targetType: .verse, targetId: verse.reference),
            targetType: .verse,
            targetId: verse.reference,
            reference: verse.reference,
            title: LocalizedResourceText(chinese: verse.reference, english: verse.reference, korean: verse.reference),
            snippet: LocalizedResourceText(chinese: verse.cn, english: verse.en, korean: verse.kr),
            dateKey: Self.dateKey(for: now),
            createdAt: now,
            updatedAt: now
        )
    }

    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func pushFavoriteIfSignedIn(_ favorite: FavoriteRecord) {
        guard let userID = currentUserIDProvider() else {
            return
        }

        favoriteRemoteStore.saveFavorite(userID: userID, favorite: favorite) { [weak self] error in
            if let error {
                Task { @MainActor in self?.lastSyncError = error.localizedDescription }
            }
        }
    }

    private func pushNoteIfSignedIn(_ note: NoteRecord) {
        guard let userID = currentUserIDProvider() else {
            return
        }

        noteRemoteStore.saveNote(userID: userID, note: note) { [weak self] error in
            if let error {
                Task { @MainActor in self?.lastSyncError = error.localizedDescription }
            }
        }
    }

    private func pushLocalFavoritesToFirebaseIfSignedIn() {
        guard currentUserIDProvider() != nil else {
            return
        }
        favorites.forEach(pushFavoriteIfSignedIn)
    }

    private func mergeRemoteFavorites(_ remoteFavorites: [FavoriteRecord]) {
        var merged = Dictionary(uniqueKeysWithValues: favorites.map { ($0.id, $0) })
        for remote in remoteFavorites {
            if let local = merged[remote.id] {
                merged[remote.id] = remote.updatedAt > local.updatedAt ? remote : local
            } else {
                merged[remote.id] = remote
            }
        }
        favorites = Array(merged.values)
        sortFavorites()
        saveLocalFavorites()
    }

    private func sortFavorites() {
        favorites.sort {
            if $0.createdAt == $1.createdAt {
                return $0.title.chinese < $1.title.chinese
            }
            return $0.createdAt > $1.createdAt
        }
    }

    private func saveLocalFavorites() {
        let stored = favorites.map(StoredFavoriteRecord.init(record:))
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: favoritesStorageKey)
        }
        defaults.synchronize()
    }

    private func saveLocalNotes() {
        let stored = notes.map(StoredNoteRecord.init(record:))
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: notesStorageKey)
        }
        defaults.synchronize()
    }

    private func loadStoredFavorites() -> [FavoriteRecord] {
        guard let data = defaults.data(forKey: favoritesStorageKey),
              let stored = try? JSONDecoder().decode([StoredFavoriteRecord].self, from: data) else {
            return []
        }
        return stored.map(FavoriteRecord.init(stored:)).sorted { $0.createdAt > $1.createdAt }
    }

    private func loadStoredNotes() -> [NoteRecord] {
        guard let data = defaults.data(forKey: notesStorageKey),
              let stored = try? JSONDecoder().decode([StoredNoteRecord].self, from: data) else {
            return []
        }
        return stored.map(NoteRecord.init(stored:)).sorted { $0.updatedAt > $1.updatedAt }
    }
}

private struct StoredFavoriteRecord: Codable {
    let id: String
    let targetType: FavoriteTargetType
    let targetId: String
    let reference: String?
    let resourceId: String?
    let pageNumber: Int?
    let title: StoredLocalizedResourceText
    let snippet: StoredLocalizedResourceText
    let dateKey: String
    let createdAt: TimeInterval
    let updatedAt: TimeInterval

    init(record: FavoriteRecord) {
        id = record.id
        targetType = record.targetType
        targetId = record.targetId
        reference = record.reference
        resourceId = record.resourceId
        pageNumber = record.pageNumber
        title = StoredLocalizedResourceText(text: record.title)
        snippet = StoredLocalizedResourceText(text: record.snippet)
        dateKey = record.dateKey
        createdAt = record.createdAt.timeIntervalSince1970
        updatedAt = record.updatedAt.timeIntervalSince1970
    }
}

private struct StoredNoteRecord: Codable {
    let id: String
    let targetType: FavoriteTargetType
    let targetId: String
    let reference: String?
    let body: String
    let language: String
    let isPrivate: Bool
    let createdAt: TimeInterval
    let updatedAt: TimeInterval

    init(record: NoteRecord) {
        id = record.id
        targetType = record.targetType
        targetId = record.targetId
        reference = record.reference
        body = record.body
        language = record.language
        isPrivate = record.isPrivate
        createdAt = record.createdAt.timeIntervalSince1970
        updatedAt = record.updatedAt.timeIntervalSince1970
    }
}

private struct StoredLocalizedResourceText: Codable {
    let chinese: String
    let english: String
    let korean: String

    init(text: LocalizedResourceText) {
        chinese = text.chinese
        english = text.english
        korean = text.korean
    }
}

private extension FavoriteRecord {
    init(stored: StoredFavoriteRecord) {
        self.init(
            id: stored.id,
            targetType: stored.targetType,
            targetId: stored.targetId,
            reference: stored.reference,
            resourceId: stored.resourceId,
            pageNumber: stored.pageNumber,
            title: LocalizedResourceText(chinese: stored.title.chinese, english: stored.title.english, korean: stored.title.korean),
            snippet: LocalizedResourceText(chinese: stored.snippet.chinese, english: stored.snippet.english, korean: stored.snippet.korean),
            dateKey: stored.dateKey,
            createdAt: Date(timeIntervalSince1970: stored.createdAt),
            updatedAt: Date(timeIntervalSince1970: stored.updatedAt)
        )
    }
}

private extension NoteRecord {
    init(stored: StoredNoteRecord) {
        self.init(
            id: stored.id,
            targetType: stored.targetType,
            targetId: stored.targetId,
            reference: stored.reference,
            body: stored.body,
            language: stored.language,
            isPrivate: stored.isPrivate,
            createdAt: Date(timeIntervalSince1970: stored.createdAt),
            updatedAt: Date(timeIntervalSince1970: stored.updatedAt)
        )
    }
}
