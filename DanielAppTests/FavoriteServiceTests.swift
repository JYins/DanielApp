import XCTest
@testable import DanielApp

@MainActor
final class FavoriteServiceTests: XCTestCase {
    func testGuestFavoriteWritesLocalOnly() {
        let remote = FakeFavoriteRemoteStore()
        let service = FavoriteService(
            favoriteRemoteStore: remote,
            noteRemoteStore: remote,
            currentUserIDProvider: { nil },
            defaults: makeDefaults()
        )

        let favorite = makeFavorite(reference: "John 3:16")
        service.toggleFavorite(favorite)

        XCTAssertTrue(service.isFavorite(targetType: .verse, targetId: "John 3:16"))
        XCTAssertTrue(remote.savedFavorites.isEmpty)
    }

    func testSignedInFavoritePushesRemote() {
        let remote = FakeFavoriteRemoteStore()
        let service = FavoriteService(
            favoriteRemoteStore: remote,
            noteRemoteStore: remote,
            currentUserIDProvider: { "test-user" },
            defaults: makeDefaults()
        )

        let favorite = makeFavorite(reference: "Romans 8:28")
        service.toggleFavorite(favorite)

        XCTAssertEqual(remote.savedUserIDs, ["test-user"])
        XCTAssertEqual(remote.savedFavorites.first?.targetId, "Romans 8:28")
    }

    func testSignedInNotePushesRemoteAndGuestNoteIsRejected() {
        let guestRemote = FakeFavoriteRemoteStore()
        let guestService = FavoriteService(
            favoriteRemoteStore: guestRemote,
            noteRemoteStore: guestRemote,
            currentUserIDProvider: { nil },
            defaults: makeDefaults()
        )
        XCTAssertFalse(guestService.saveNote(targetType: .verse, targetId: "Psalm 23:1", reference: "Psalm 23:1", body: "guest", language: .english))
        XCTAssertTrue(guestRemote.savedNotes.isEmpty)

        let remote = FakeFavoriteRemoteStore()
        let service = FavoriteService(
            favoriteRemoteStore: remote,
            noteRemoteStore: remote,
            currentUserIDProvider: { "test-user" },
            defaults: makeDefaults()
        )

        XCTAssertTrue(service.saveNote(targetType: .verse, targetId: "Psalm 23:1", reference: "Psalm 23:1", body: "remember this", language: .english))
        XCTAssertEqual(remote.savedNotes.first?.body, "remember this")
        XCTAssertEqual(remote.savedNoteUserIDs, ["test-user"])
    }

    private func makeFavorite(reference: String) -> FavoriteRecord {
        FavoriteRecord(
            id: "verse_\(reference.replacingOccurrences(of: " ", with: "_"))",
            targetType: .verse,
            targetId: reference,
            reference: reference,
            title: LocalizedResourceText(chinese: reference, english: reference, korean: reference),
            snippet: LocalizedResourceText(chinese: "中文", english: "English", korean: "한국어"),
            dateKey: "2026-06-07",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "FavoriteServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class FakeFavoriteRemoteStore: FavoriteRemoteStore, NoteRemoteStore {
    var favoritesToFetch: [FavoriteRecord] = []
    var notesToFetch: [NoteRecord] = []
    var savedUserIDs: [String] = []
    var savedFavorites: [FavoriteRecord] = []
    var deletedFavoriteIDs: [String] = []
    var savedNoteUserIDs: [String] = []
    var savedNotes: [NoteRecord] = []

    func fetchFavorites(userID: String, completion: @escaping (Result<[FavoriteRecord], Error>) -> Void) {
        completion(.success(favoritesToFetch))
    }

    func saveFavorite(userID: String, favorite: FavoriteRecord, completion: @escaping (Error?) -> Void) {
        savedUserIDs.append(userID)
        savedFavorites.append(favorite)
        completion(nil)
    }

    func deleteFavorite(userID: String, favoriteID: String, completion: @escaping (Error?) -> Void) {
        deletedFavoriteIDs.append(favoriteID)
        completion(nil)
    }

    func fetchNotes(userID: String, completion: @escaping (Result<[NoteRecord], Error>) -> Void) {
        completion(.success(notesToFetch))
    }

    func saveNote(userID: String, note: NoteRecord, completion: @escaping (Error?) -> Void) {
        savedNoteUserIDs.append(userID)
        savedNotes.append(note)
        completion(nil)
    }
}
