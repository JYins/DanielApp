import XCTest
import FirebaseAuth
import FirebaseFirestore
import Darwin
@testable import DanielApp

@MainActor
final class FirebaseEmulatorIntegrationTests: XCTestCase {
    private static var didConfigureEmulators = false
    private var db: Firestore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(Self.isPortOpen(host: "127.0.0.1", port: 8080), "Firestore emulator is not running on 127.0.0.1:8080.")
        try XCTSkipUnless(Self.isPortOpen(host: "127.0.0.1", port: 9099), "Auth emulator is not running on 127.0.0.1:9099.")
        Self.configureEmulatorsIfNeeded()
        db = Firestore.firestore()
    }

    override func tearDown() async throws {
        try? Auth.auth().signOut()
        try await super.tearDown()
    }

    func testVerseEngagementRoundTripsThroughEmulatorService() async throws {
        try await signIn(email: "approved@example.test", password: "password123")
        let reference = "Integration 1:1"
        let document = db.collection("users")
            .document("test-approved-user")
            .collection("verseEngagement")
            .document(reference)

        try await setData([
            "reference": reference,
            "isRead": true,
            "isFavorite": false,
            "isLiked": true,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], for: document)

        let service = VerseEngagementService(
            remoteStore: FirestoreVerseEngagementRemoteStore(db: db),
            currentUserIDProvider: { "test-approved-user" },
            defaults: makeDefaults()
        )
        service.syncFromFirebaseIfSignedIn()

        try await waitUntil {
            service.readReferences.contains(reference) && service.likedReferences.contains(reference)
        }
    }

    func testNewsletterViewModelReadsSeededNewsletters() async throws {
        try await signIn(email: "approved@example.test", password: "password123")
        let viewModel = NewsletterViewModel(
            remoteStore: FirestoreNewsletterRemoteStore(db: db),
            accessProvider: { true },
            branchIDProvider: { "canada-daniel-test-church" }
        )

        viewModel.loadNewsletters()

        try await waitUntil {
            viewModel.newsletters.contains { $0.id == "test-weekly-newsletter" }
        }
    }

    func testResourceServiceReadsSeededResources() async throws {
        try? Auth.auth().signOut()
        let service = ChurchResourceService(remoteStore: FirestoreChurchResourceRemoteStore(db: db))

        service.loadResources()

        try await waitUntil {
            service.resources.contains { $0.id == "test-bible-study" } && service.source == .firebase
        }
    }

    func testRegistrationBranchStoreReadsSeededBranches() async throws {
        try? Auth.auth().signOut()
        let remoteStore = FirestoreRegistrationBranchRemoteStore(db: db)

        let branches = try await fetchActiveBranches(from: remoteStore)

        XCTAssertTrue(branches.contains { $0.id == "canada-daniel-test-church" })
        XCTAssertTrue(branches.contains { $0.id == "canada-other-test-church" })
        XCTAssertTrue(branches.allSatisfy(\.isActive))
    }

    func testFirestoreRulesForEngagementResourcesAndNewsletters() async throws {
        try? Auth.auth().signOut()

        let publicResource = db.collection("resources").document("test-bible-study")
        let publicSnapshot = try await getDocument(publicResource)
        XCTAssertTrue(publicSnapshot.exists)

        let draftResource = db.collection("resources").document("test-draft-resource")
        await XCTAssertThrowsAsync {
            _ = try await getDocument(draftResource)
        }

        let newsletter = db.collection("newsletters").document("test-weekly-newsletter")
        await XCTAssertThrowsAsync {
            _ = try await getDocument(newsletter)
        }

        try await signIn(email: "approved@example.test", password: "password123")
        let approvedNewsletterSnapshot = try await getDocument(newsletter)
        XCTAssertTrue(approvedNewsletterSnapshot.exists)

        let ownEngagement = db.collection("users")
            .document("test-approved-user")
            .collection("verseEngagement")
            .document("Rules 1:1")
        try await setData([
            "reference": "Rules 1:1",
            "isRead": true,
            "isFavorite": true,
            "isLiked": false,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], for: ownEngagement)

        let otherEngagement = db.collection("users")
            .document("test-other-user")
            .collection("verseEngagement")
            .document("Rules 1:2")
        await XCTAssertThrowsAsync {
            try await setData([
                "reference": "Rules 1:2",
                "isRead": true,
                "isFavorite": false,
                "isLiked": false,
                "createdAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ], for: otherEngagement)
        }

        let pdfResource = db.collection("resources").document("test-admin-pdf-resource")
        await XCTAssertThrowsAsync {
            try await setData(Self.pdfResourcePayload(), for: pdfResource)
        }

        try await signIn(email: "admin@example.test", password: "password123")
        try await setData(Self.pdfResourcePayload(), for: pdfResource)
        let pdfResourceSnapshot = try await getDocument(pdfResource)
        XCTAssertTrue(pdfResourceSnapshot.exists)
        XCTAssertEqual(pdfResourceSnapshot.data()?["fileType"] as? String, "application/pdf")
    }

    func testFirestoreRulesForFavoritesNotesAndReadingProgress() async throws {
        try await signIn(email: "approved@example.test", password: "password123")
        let ownFavorite = db.collection("users")
            .document("test-approved-user")
            .collection("favorites")
            .document("verse_John_3:16")
        let ownNote = db.collection("users")
            .document("test-approved-user")
            .collection("notes")
            .document("verse_John_3:16")
        let ownProgress = db.collection("users")
            .document("test-approved-user")
            .collection("readingProgress")
            .document("bible")

        try await setData([
            "targetType": "verse",
            "targetId": "John 3:16",
            "reference": "John 3:16",
            "title": localized("John 3:16"),
            "snippet": localized("For God so loved the world"),
            "dateKey": "2026-06-07",
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], for: ownFavorite)

        try await setData([
            "targetType": "verse",
            "targetId": "John 3:16",
            "reference": "John 3:16",
            "body": "Remember this verse",
            "language": "english",
            "isPrivate": true,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], for: ownNote)

        try await setData([
            "targetType": "bible",
            "book": "John",
            "chapter": 3,
            "verse": 16,
            "updatedAt": Timestamp(date: Date())
        ], for: ownProgress)

        let favoriteSnapshot = try await getDocument(ownFavorite)
        let noteSnapshot = try await getDocument(ownNote)
        let progressSnapshot = try await getDocument(ownProgress)
        XCTAssertTrue(favoriteSnapshot.exists)
        XCTAssertTrue(noteSnapshot.exists)
        XCTAssertTrue(progressSnapshot.exists)

        let otherFavorite = db.collection("users")
            .document("test-other-user")
            .collection("favorites")
            .document("verse_John_3:16")
        await XCTAssertThrowsAsync {
            try await setData([
                "targetType": "verse",
                "targetId": "John 3:16",
                "title": localized("John 3:16"),
                "snippet": localized("For God so loved the world"),
                "dateKey": "2026-06-07",
                "createdAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ], for: otherFavorite)
        }
    }

    func testBranchAndRegionScopedRules() async throws {
        let sameBranchUser = db.collection("users").document("test-approved-user")
        let sameRegionOtherBranchUser = db.collection("users").document("test-other-user")
        let outsideRegionUser = db.collection("users").document("test-outside-region-user")
        let sameBranchMembership = db.collection("branchMemberships").document("canada-daniel-test-church_test-approved-user")
        let otherBranchMembership = db.collection("branchMemberships").document("canada-other-test-church_test-other-user")

        try await signIn(email: "branch-admin@example.test", password: "password123")
        let branchAdminSameBranchUser = try await getDocument(sameBranchUser)
        let branchAdminSameBranchMembership = try await getDocument(sameBranchMembership)
        XCTAssertTrue(branchAdminSameBranchUser.exists)
        XCTAssertTrue(branchAdminSameBranchMembership.exists)
        await XCTAssertThrowsAsync {
            _ = try await getDocument(sameRegionOtherBranchUser)
        }
        await XCTAssertThrowsAsync {
            _ = try await getDocument(otherBranchMembership)
        }

        try await signIn(email: "region-admin@example.test", password: "password123")
        let regionAdminSameBranchUser = try await getDocument(sameBranchUser)
        let regionAdminOtherBranchUser = try await getDocument(sameRegionOtherBranchUser)
        let regionAdminOtherBranchMembership = try await getDocument(otherBranchMembership)
        XCTAssertTrue(regionAdminSameBranchUser.exists)
        XCTAssertTrue(regionAdminOtherBranchUser.exists)
        XCTAssertTrue(regionAdminOtherBranchMembership.exists)
        await XCTAssertThrowsAsync {
            _ = try await getDocument(outsideRegionUser)
        }

        try await signIn(email: "approved@example.test", password: "password123")
        let memberOwnMembership = try await getDocument(sameBranchMembership)
        XCTAssertTrue(memberOwnMembership.exists)
        await XCTAssertThrowsAsync {
            _ = try await getDocument(otherBranchMembership)
        }
    }

    func testOnlyGlobalAdminCanWriteBranchStructure() async throws {
        let branch = db.collection("branches").document("canada-new-test-church")
        let branchData: [String: Any] = [
            "id": "canada-new-test-church",
            "orgId": "daniel-branch-church",
            "regionId": "canada",
            "regionName": localized("Canada"),
            "code": "canada-new-test-church",
            "name": localized("New Test Church"),
            "country": "CA",
            "city": "Mississauga",
            "timezone": "America/Toronto",
            "isActive": true,
            "sortOrder": 99,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]

        try await signIn(email: "approved@example.test", password: "password123")
        await XCTAssertThrowsAsync {
            try await setData(branchData, for: branch)
        }

        try await signIn(email: "region-admin@example.test", password: "password123")
        await XCTAssertThrowsAsync {
            try await setData(branchData, for: branch)
        }

        try await signIn(email: "admin@example.test", password: "password123")
        try await setData(branchData, for: branch)
        let createdBranch = try await getDocument(branch)
        XCTAssertTrue(createdBranch.exists)

        let membership = db.collection("branchMemberships").document("canada-new-test-church_test-approved-user")
        try await setData([
            "id": "canada-new-test-church_test-approved-user",
            "userId": "test-approved-user",
            "orgId": "daniel-branch-church",
            "regionId": "canada",
            "branchId": "canada-new-test-church",
            "role": "member",
            "accessRole": "member",
            "status": "active",
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], for: membership)
        let createdMembership = try await getDocument(membership)
        XCTAssertTrue(createdMembership.exists)
    }

    func testOnlyGlobalAdminCanAssignUserBranchAndMembership() async throws {
        let userDocument = db.collection("users").document("test-approved-user")
        let newMembership = db.collection("branchMemberships").document("canada-other-test-church_test-approved-user")

        try await signIn(email: "approved@example.test", password: "password123")
        await XCTAssertThrowsAsync {
            try await updateData([
                "branchId": "canada-other-test-church",
                "branchName": "Other Test Church",
                "updatedAt": Timestamp(date: Date())
            ], for: userDocument)
        }

        try await signIn(email: "admin@example.test", password: "password123")
        try await updateData([
            "orgId": "daniel-branch-church",
            "regionId": "canada",
            "regionName": "Canada",
            "branchId": "canada-other-test-church",
            "branchName": "Other Test Church",
            "churchCountry": "CA",
            "churchName": "Other Test Church",
            "role": "branch_admin",
            "accessRole": "branch_admin",
            "membershipStatus": "active",
            "updatedAt": Timestamp(date: Date())
        ], for: userDocument)

        try await setData([
            "id": "canada-other-test-church_test-approved-user",
            "userId": "test-approved-user",
            "orgId": "daniel-branch-church",
            "regionId": "canada",
            "branchId": "canada-other-test-church",
            "role": "branch_admin",
            "accessRole": "branch_admin",
            "status": "active",
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ], for: newMembership)

        let updatedUser = try await getDocument(userDocument)
        let updatedMembership = try await getDocument(newMembership)
        XCTAssertEqual(updatedUser.get("branchId") as? String, "canada-other-test-church")
        XCTAssertEqual(updatedUser.get("accessRole") as? String, "branch_admin")
        XCTAssertTrue(updatedMembership.exists)
    }

    private func signIn(email: String, password: String) async throws {
        try? Auth.auth().signOut()
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult?, Error>) in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }

    private func setData(_ data: [String: Any], for document: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.setData(data) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func updateData(_ data: [AnyHashable: Any], for document: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.updateData(data) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func getDocument(_ document: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            document.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: NSError(domain: "FirebaseEmulatorIntegrationTests", code: 1))
                }
            }
        }
    }

    private func fetchActiveBranches(from remoteStore: RegistrationBranchRemoteStore) async throws -> [RegistrationBranch] {
        try await withCheckedThrowingContinuation { continuation in
            remoteStore.fetchActiveBranches { result in
                continuation.resume(with: result)
            }
        }
    }

    private func localized(_ value: String) -> [String: String] {
        [
            "zh": value,
            "en": value,
            "ko": value
        ]
    }

    private static func pdfResourcePayload() -> [String: Any] {
        [
            "id": "test-admin-pdf-resource",
            "type": "hymnbook",
            "category": "hymnbook",
            "title": localizedStatic("PDF Hymnbook"),
            "subtitle": localizedStatic("Uploaded PDF resource"),
            "description": localizedStatic("A resource document with Firebase Storage metadata."),
            "actionTitle": localizedStatic("Open PDF"),
            "url": "https://firebasestorage.googleapis.com/v0/b/test/o/resources%2Ftest-admin-pdf-resource%2Fhymnbook.pdf?alt=media",
            "content": NSNull(),
            "storagePath": "resources/test-admin-pdf-resource/hymnbook.pdf",
            "fileName": "hymnbook.pdf",
            "fileSize": 1024,
            "fileType": "application/pdf",
            "downloadURL": "https://firebasestorage.googleapis.com/v0/b/test/o/resources%2Ftest-admin-pdf-resource%2Fhymnbook.pdf?alt=media",
            "icon": "doc.richtext",
            "isPublished": true,
            "accessLevel": "public",
            "sortOrder": 30,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
    }

    private static func localizedStatic(_ value: String) -> [String: String] {
        [
            "zh": value,
            "en": value,
            "ko": value
        ]
    }

    private func waitUntil(
        timeout: TimeInterval = 5,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("Timed out waiting for emulator condition")
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "FirebaseEmulatorIntegrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static func configureEmulatorsIfNeeded() {
        guard !didConfigureEmulators else {
            return
        }

        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)

        let settings = Firestore.firestore().settings
        settings.host = "127.0.0.1:8080"
        settings.isSSLEnabled = false
        settings.isPersistenceEnabled = false
        Firestore.firestore().settings = settings

        didConfigureEmulators = true
    }

    private static func isPortOpen(host: String, port: Int32) -> Bool {
        let socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFileDescriptor >= 0 else {
            return false
        }
        defer { close(socketFileDescriptor) }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        inet_pton(AF_INET, host, &address.sin_addr)

        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                connect(socketFileDescriptor, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }
}

private func XCTAssertThrowsAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected async expression to throw", file: file, line: line)
    } catch {
        XCTAssertTrue(true)
    }
}
