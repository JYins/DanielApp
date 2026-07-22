import XCTest
@testable import DanielApp

@MainActor
final class ChurchResourceServiceTests: XCTestCase {
    func testFirebaseResourcesReplaceLocalSeedWhenAvailable() async {
        let remoteStore = FakeChurchResourceRemoteStore(result: .success([Self.resource(id: "remote", type: "bible_study")]))
        let service = ChurchResourceService(remoteStore: remoteStore, localSeed: [Self.resource(id: "local", type: "hymnbook")])

        service.loadResources()
        await Task.yield()

        XCTAssertEqual(service.source, .firebase)
        XCTAssertEqual(service.resources.map(\.id), ["remote"])
    }

    func testFirebaseFailureFallsBackToLocalSeed() async {
        let remoteStore = FakeChurchResourceRemoteStore(result: .failure(TestError.failure))
        let service = ChurchResourceService(remoteStore: remoteStore, localSeed: [Self.resource(id: "local", type: "hymnbook")])

        service.loadResources()
        await Task.yield()

        XCTAssertEqual(service.resources.map(\.id), ["local"])
        if case .localFallback = service.source {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected local fallback")
        }
    }

    func testEmptyFirebaseCollectionFallsBackToLocalSeed() async {
        let remoteStore = FakeChurchResourceRemoteStore(result: .success([]))
        let service = ChurchResourceService(remoteStore: remoteStore, localSeed: [Self.resource(id: "local", type: "hymnbook")])

        service.loadResources()
        await Task.yield()

        XCTAssertEqual(service.resources.map(\.id), ["local"])
    }

    func testSearchMatchesTitleSubtitleAndCategory() {
        let service = ChurchResourceService(
            remoteStore: FakeChurchResourceRemoteStore(result: .success([])),
            localSeed: [
                Self.resource(id: "study", type: "bible_study", title: "Bible Study", subtitle: "Topical guide"),
                Self.resource(id: "links", type: "useful_links", title: "Useful Links", subtitle: "Websites")
            ]
        )

        XCTAssertEqual(service.filteredResources(searchText: "topical", selectedCategory: .all, language: .english).map(\.id), ["study"])
        XCTAssertEqual(service.filteredResources(searchText: "Links", selectedCategory: .all, language: .english).map(\.id), ["links"])
        XCTAssertEqual(service.filteredResources(searchText: "Bible Study", selectedCategory: .all, language: .english).map(\.id), ["study"])
    }

    func testCategoryFilter() {
        let service = ChurchResourceService(
            remoteStore: FakeChurchResourceRemoteStore(result: .success([])),
            localSeed: [
                Self.resource(id: "study", type: "bible_study"),
                Self.resource(id: "links", type: "useful_links")
            ]
        )

        XCTAssertEqual(service.filteredResources(searchText: "", selectedCategory: .links, language: .english).map(\.id), ["links"])
    }

    private static func resource(id: String, type: String, title: String = "Title", subtitle: String = "Subtitle") -> ChurchResource {
        ChurchResource(
            id: id,
            type: type,
            category: ChurchResourceCategory(resourceType: type),
            categoryKey: type,
            title: LocalizedResourceText(chinese: title, english: title, korean: title),
            subtitle: LocalizedResourceText(chinese: subtitle, english: subtitle, korean: subtitle),
            description: LocalizedResourceText(chinese: "Description", english: "Description", korean: "Description"),
            actionTitle: LocalizedResourceText(chinese: "Open", english: "Open", korean: "Open"),
            url: nil,
            content: nil,
            icon: "book",
            isPublished: true,
            accessLevel: "public",
            sortOrder: 10,
            updatedAt: Date(),
            createdAt: Date()
        )
    }
}

private final class FakeChurchResourceRemoteStore: ChurchResourceRemoteStore {
    let result: Result<[ChurchResource], Error>

    init(result: Result<[ChurchResource], Error>) {
        self.result = result
    }

    func fetchPublishedResources(completion: @escaping (Result<[ChurchResource], Error>) -> Void) {
        completion(result)
    }
}

private enum TestError: Error {
    case failure
}
