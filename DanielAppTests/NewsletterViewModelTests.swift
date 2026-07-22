import XCTest
import FirebaseFirestore
@testable import DanielApp

@MainActor
final class NewsletterViewModelTests: XCTestCase {
    func testLoadingEmptyErrorAndContentStatesAreExpressive() async {
        let emptyStore = FakeNewsletterRemoteStore(result: .success([]))
        let emptyViewModel = NewsletterViewModel(remoteStore: emptyStore, accessProvider: { true }, branchIDProvider: { "canada-test" })
        emptyViewModel.loadNewsletters()
        await Task.yield()
        XCTAssertEqual(emptyViewModel.state, .empty)

        let errorViewModel = NewsletterViewModel(remoteStore: FakeNewsletterRemoteStore(result: .failure(TestNewsletterError.denied)), accessProvider: { true }, branchIDProvider: { "canada-test" })
        errorViewModel.loadNewsletters()
        await Task.yield()
        if case .error = errorViewModel.state {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected error state")
        }

        let contentViewModel = NewsletterViewModel(remoteStore: FakeNewsletterRemoteStore(result: .success([Self.newsletter()])), accessProvider: { true }, branchIDProvider: { "canada-test" })
        contentViewModel.loadNewsletters()
        await Task.yield()
        XCTAssertEqual(contentViewModel.state, .content)
        XCTAssertEqual(contentViewModel.newsletters.count, 1)
    }

    func testPermissionDeniedDoesNotCrashOrAttachListener() {
        let store = FakeNewsletterRemoteStore(result: .success([Self.newsletter()]))
        let viewModel = NewsletterViewModel(remoteStore: store, accessProvider: { false })

        viewModel.loadNewsletters()

        XCTAssertEqual(viewModel.state, .permissionDenied)
        XCTAssertFalse(store.didListen)
        XCTAssertTrue(viewModel.newsletters.isEmpty)
    }

    private static func newsletter() -> Newsletter {
        Newsletter(
            id: "newsletter",
            publishDate: Date(),
            imageURLs: [],
            caption: NewsletterCaption(
                chinese: "测试通讯",
                english: "Test newsletter",
                korean: "테스트 소식지"
            )
        )
    }
}

private final class FakeNewsletterRemoteStore: NewsletterRemoteStore {
    let result: Result<[Newsletter], Error>
    var didListen = false

    init(result: Result<[Newsletter], Error>) {
        self.result = result
    }

    func listenToPublishedNewsletters(
        branchId: String,
        onChange: @escaping (Result<[Newsletter], Error>) -> Void
    ) -> ListenerRegistration? {
        didListen = true
        onChange(result)
        return nil
    }
}

private enum TestNewsletterError: Error {
    case denied
}
