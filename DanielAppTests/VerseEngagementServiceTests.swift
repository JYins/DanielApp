import XCTest
@testable import DanielApp

@MainActor
final class VerseEngagementServiceTests: XCTestCase {
    func testGuestToggleWritesLocalOnly() async {
        let remoteStore = FakeVerseEngagementRemoteStore()
        let service = VerseEngagementService(
            remoteStore: remoteStore,
            currentUserIDProvider: { nil },
            defaults: makeDefaults()
        )

        service.toggleRead(reference: "John 3:16")
        service.toggleFavorite(reference: "John 3:16")
        service.toggleLike(reference: "John 3:16")

        XCTAssertTrue(service.readReferences.contains("John 3:16"))
        XCTAssertTrue(service.favoriteReferences.contains("John 3:16"))
        XCTAssertTrue(service.likedReferences.contains("John 3:16"))
        XCTAssertTrue(remoteStore.savedRecords.isEmpty)
    }

    func testSignedInTogglePushesLocalStateToRemote() async {
        let remoteStore = FakeVerseEngagementRemoteStore()
        let service = VerseEngagementService(
            remoteStore: remoteStore,
            currentUserIDProvider: { "test-user" },
            defaults: makeDefaults()
        )

        service.toggleFavorite(reference: "Romans 8:28")

        XCTAssertEqual(remoteStore.savedUserIDs, ["test-user"])
        XCTAssertEqual(remoteStore.savedRecords.last?.first?.reference, "Romans 8:28")
        XCTAssertEqual(remoteStore.savedRecords.last?.first?.isFavorite, true)
    }

    func testRemoteNewerRecordWinsDuringMerge() async {
        let remoteStore = FakeVerseEngagementRemoteStore()
        let service = VerseEngagementService(
            remoteStore: remoteStore,
            currentUserIDProvider: { "test-user" },
            defaults: makeDefaults()
        )
        service.toggleFavorite(reference: "Psalm 23:1")

        remoteStore.recordsToFetch = [
            VerseEngagementRecord(
                reference: "Psalm 23:1",
                isRead: true,
                isFavorite: false,
                isLiked: true,
                createdAt: Date(timeIntervalSince1970: 10),
                updatedAt: Date(timeIntervalSince1970: 4_000_000_000)
            )
        ]

        service.syncFromFirebaseIfSignedIn()
        await Task.yield()

        let record = service.record(for: "Psalm 23:1")
        XCTAssertEqual(record?.isRead, true)
        XCTAssertEqual(record?.isFavorite, false)
        XCTAssertEqual(record?.isLiked, true)
    }

    func testLocalNewerRecordIsPushedDuringMerge() async {
        let remoteStore = FakeVerseEngagementRemoteStore()
        let service = VerseEngagementService(
            remoteStore: remoteStore,
            currentUserIDProvider: { "test-user" },
            defaults: makeDefaults()
        )
        service.toggleLike(reference: "Isaiah 41:10")
        remoteStore.savedRecords.removeAll()

        remoteStore.recordsToFetch = [
            VerseEngagementRecord(
                reference: "Isaiah 41:10",
                isRead: false,
                isFavorite: false,
                isLiked: false,
                createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 1)
            )
        ]

        service.syncFromFirebaseIfSignedIn()
        await Task.yield()

        XCTAssertTrue(service.likedReferences.contains("Isaiah 41:10"))
        XCTAssertEqual(remoteStore.savedRecords.last?.first?.isLiked, true)
    }

    func testEmptyRemoteDoesNotClearLocalState() async {
        let remoteStore = FakeVerseEngagementRemoteStore()
        let service = VerseEngagementService(
            remoteStore: remoteStore,
            currentUserIDProvider: { "test-user" },
            defaults: makeDefaults()
        )
        service.toggleRead(reference: "Matthew 5:9")
        remoteStore.savedRecords.removeAll()
        remoteStore.recordsToFetch = []

        service.syncFromFirebaseIfSignedIn()
        await Task.yield()

        XCTAssertTrue(service.readReferences.contains("Matthew 5:9"))
        XCTAssertEqual(remoteStore.savedRecords.last?.first?.reference, "Matthew 5:9")
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "VerseEngagementServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class FakeVerseEngagementRemoteStore: VerseEngagementRemoteStore {
    var recordsToFetch: [VerseEngagementRecord] = []
    var savedUserIDs: [String] = []
    var savedRecords: [[VerseEngagementRecord]] = []

    func fetchVerseEngagement(userID: String, completion: @escaping (Result<[VerseEngagementRecord], Error>) -> Void) {
        completion(.success(recordsToFetch))
    }

    func saveVerseEngagement(userID: String, records: [VerseEngagementRecord], completion: @escaping (Error?) -> Void) {
        savedUserIDs.append(userID)
        savedRecords.append(records)
        completion(nil)
    }
}
