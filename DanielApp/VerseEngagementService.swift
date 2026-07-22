import Foundation
import Combine
import FirebaseFirestore

protocol VerseEngagementRemoteStore {
    func fetchVerseEngagement(userID: String, completion: @escaping (Result<[VerseEngagementRecord], Error>) -> Void)
    func saveVerseEngagement(userID: String, records: [VerseEngagementRecord], completion: @escaping (Error?) -> Void)
}

final class FirestoreVerseEngagementRemoteStore: VerseEngagementRemoteStore {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func fetchVerseEngagement(userID: String, completion: @escaping (Result<[VerseEngagementRecord], Error>) -> Void) {
        db.collection("users")
            .document(userID)
            .collection("verseEngagement")
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                let records = snapshot?.documents.compactMap { VerseEngagementRecord(document: $0) } ?? []
                completion(.success(records))
            }
    }

    func saveVerseEngagement(userID: String, records: [VerseEngagementRecord], completion: @escaping (Error?) -> Void) {
        guard !records.isEmpty else {
            completion(nil)
            return
        }

        let batch = db.batch()
        let collection = db.collection("users")
            .document(userID)
            .collection("verseEngagement")

        for record in records {
            batch.setData(record.firestoreData, forDocument: collection.document(Self.documentID(for: record.reference)), merge: true)
        }

        batch.commit(completion: completion)
    }

    private static func documentID(for reference: String) -> String {
        reference.replacingOccurrences(of: "/", with: "／")
    }
}

@MainActor
final class VerseEngagementService: ObservableObject {
    static let shared = VerseEngagementService()

    @Published private(set) var readReferences: Set<String> = []
    @Published private(set) var favoriteReferences: Set<String> = []
    @Published private(set) var likedReferences: Set<String> = []

    private let remoteStore: VerseEngagementRemoteStore
    private let currentUserIDProvider: () -> String?
    private let defaults: UserDefaults
    private let readStorageKey = "daniel.readVerseReferences"
    private let favoriteStorageKey = "daniel.favoriteVerseReferences"
    private let likedStorageKey = "daniel.likedVerseReferences"
    private let metadataStorageKey = "daniel.verseEngagementMetadata"
    private var records: [String: VerseEngagementRecord] = [:]
    private var isSyncing = false

    init(
        remoteStore: VerseEngagementRemoteStore = FirestoreVerseEngagementRemoteStore(),
        currentUserIDProvider: @escaping () -> String? = { AuthManager.shared.currentAuthenticatedUserID },
        defaults: UserDefaults = VerseDataService.shared.getSharedDefaults()
    ) {
        self.remoteStore = remoteStore
        self.currentUserIDProvider = currentUserIDProvider
        self.defaults = defaults
        loadLocalEngagement()
    }

    func loadLocalEngagement() {
        let storedRead = Set(defaults.stringArray(forKey: readStorageKey) ?? [])
        let storedFavorites = Set(defaults.stringArray(forKey: favoriteStorageKey) ?? [])
        let storedLikes = Set(defaults.stringArray(forKey: likedStorageKey) ?? [])
        var storedRecords = loadStoredRecords(from: defaults)
        let now = Date()
        var didBackfillLegacyRecords = false

        for reference in storedRead.union(storedFavorites).union(storedLikes) {
            if storedRecords[reference] == nil {
                storedRecords[reference] = VerseEngagementRecord(
                    reference: reference,
                    isRead: storedRead.contains(reference),
                    isFavorite: storedFavorites.contains(reference),
                    isLiked: storedLikes.contains(reference),
                    createdAt: now,
                    updatedAt: now
                )
                didBackfillLegacyRecords = true
            } else {
                storedRecords[reference]?.isRead = storedRead.contains(reference)
                storedRecords[reference]?.isFavorite = storedFavorites.contains(reference)
                storedRecords[reference]?.isLiked = storedLikes.contains(reference)
            }
        }

        records = storedRecords
        updatePublishedReferences()

        if didBackfillLegacyRecords {
            saveLocalEngagement()
        }
    }

    func saveLocalEngagement() {
        defaults.set(Array(readReferences).sorted(), forKey: readStorageKey)
        defaults.set(Array(favoriteReferences).sorted(), forKey: favoriteStorageKey)
        defaults.set(Array(likedReferences).sorted(), forKey: likedStorageKey)

        if let data = try? JSONEncoder().encode(records.mapValues(StoredVerseEngagementRecord.init(record:))) {
            defaults.set(data, forKey: metadataStorageKey)
        }

        defaults.synchronize()
    }

    func toggleRead(reference: String) {
        updateLocalRecord(reference: reference) { record in
            record.isRead.toggle()
        }
    }

    func toggleFavorite(reference: String) {
        updateLocalRecord(reference: reference) { record in
            record.isFavorite.toggle()
        }
    }

    func toggleLike(reference: String) {
        updateLocalRecord(reference: reference) { record in
            record.isLiked.toggle()
        }
    }

    func syncFromFirebaseIfSignedIn() {
        guard !isSyncing, let userID = currentUserIDProvider() else {
            return
        }

        isSyncing = true
        loadLocalEngagement()

        remoteStore.fetchVerseEngagement(userID: userID) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isSyncing = false

                switch result {
                case .failure(let error):
                    print("⚠️ Verse engagement sync pull failed: \(error.localizedDescription)")
                case .success(let remoteRecords):
                    self.mergeRemoteRecords(remoteRecords)
                }
            }
        }
    }

    func pushLocalToFirebaseIfSignedIn() {
        guard let userID = currentUserIDProvider(), !records.isEmpty else {
            return
        }

        remoteStore.saveVerseEngagement(userID: userID, records: Array(records.values)) { error in
            if let error {
                print("⚠️ Verse engagement sync push failed: \(error.localizedDescription)")
            }
        }
    }

    func record(for reference: String) -> VerseEngagementRecord? {
        records[reference]
    }

    private func updateLocalRecord(reference: String, mutate: (inout VerseEngagementRecord) -> Void) {
        let now = Date()
        var record = records[reference] ?? VerseEngagementRecord(
            reference: reference,
            isRead: false,
            isFavorite: false,
            isLiked: false,
            createdAt: now,
            updatedAt: now
        )
        mutate(&record)
        record.updatedAt = now
        records[reference] = record
        updatePublishedReferences()
        saveLocalEngagement()
        pushLocalToFirebaseIfSignedIn()
    }

    private func mergeRemoteRecords(_ remoteRecords: [VerseEngagementRecord]) {
        guard !remoteRecords.isEmpty else {
            pushLocalToFirebaseIfSignedIn()
            return
        }

        var mergedRecords = records
        var shouldPushLocal = false
        let remoteReferences = Set(remoteRecords.map(\.reference))

        for remoteRecord in remoteRecords {
            if let localRecord = mergedRecords[remoteRecord.reference] {
                if remoteRecord.updatedAt > localRecord.updatedAt {
                    mergedRecords[remoteRecord.reference] = remoteRecord
                } else if localRecord.updatedAt > remoteRecord.updatedAt {
                    shouldPushLocal = true
                }
            } else {
                mergedRecords[remoteRecord.reference] = remoteRecord
            }
        }

        if !Set(mergedRecords.keys).isSubset(of: remoteReferences) {
            shouldPushLocal = true
        }

        records = mergedRecords
        updatePublishedReferences()
        saveLocalEngagement()

        if shouldPushLocal {
            pushLocalToFirebaseIfSignedIn()
        }
    }

    private func loadStoredRecords(from defaults: UserDefaults) -> [String: VerseEngagementRecord] {
        guard let data = defaults.data(forKey: metadataStorageKey),
              let storedRecords = try? JSONDecoder().decode([String: StoredVerseEngagementRecord].self, from: data) else {
            return [:]
        }

        return storedRecords.mapValues(VerseEngagementRecord.init(storedRecord:))
    }

    private func updatePublishedReferences() {
        readReferences = Set(records.values.filter(\.isRead).map(\.reference))
        favoriteReferences = Set(records.values.filter(\.isFavorite).map(\.reference))
        likedReferences = Set(records.values.filter(\.isLiked).map(\.reference))
    }
}

struct VerseEngagementRecord: Equatable {
    var reference: String
    var isRead: Bool
    var isFavorite: Bool
    var isLiked: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        reference: String,
        isRead: Bool,
        isFavorite: Bool,
        isLiked: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.reference = reference
        self.isRead = isRead
        self.isFavorite = isFavorite
        self.isLiked = isLiked
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    fileprivate init(storedRecord: StoredVerseEngagementRecord) {
        reference = storedRecord.reference
        isRead = storedRecord.isRead
        isFavorite = storedRecord.isFavorite
        isLiked = storedRecord.isLiked
        createdAt = Date(timeIntervalSince1970: storedRecord.createdAt)
        updatedAt = Date(timeIntervalSince1970: storedRecord.updatedAt)
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let reference = data["reference"] as? String else {
            return nil
        }

        self.reference = reference
        isRead = data["isRead"] as? Bool ?? false
        isFavorite = data["isFavorite"] as? Bool ?? false
        isLiked = data["isLiked"] as? Bool ?? false
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date.distantPast
        updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
    }

    var firestoreData: [String: Any] {
        [
            "reference": reference,
            "isRead": isRead,
            "isFavorite": isFavorite,
            "isLiked": isLiked,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt)
        ]
    }
}

private struct StoredVerseEngagementRecord: Codable {
    var reference: String
    var isRead: Bool
    var isFavorite: Bool
    var isLiked: Bool
    var createdAt: TimeInterval
    var updatedAt: TimeInterval

    init(record: VerseEngagementRecord) {
        reference = record.reference
        isRead = record.isRead
        isFavorite = record.isFavorite
        isLiked = record.isLiked
        createdAt = record.createdAt.timeIntervalSince1970
        updatedAt = record.updatedAt.timeIntervalSince1970
    }
}
