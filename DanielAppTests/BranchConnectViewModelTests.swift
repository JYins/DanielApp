import XCTest
@testable import DanielApp

@MainActor
final class BranchConnectViewModelTests: XCTestCase {
    func testLoadsBranchScopedKakaoConfiguration() async throws {
        let info = BranchConnectInfo(
            groupNameZh: "加拿大测试堂",
            groupNameEn: "Canada Test Church",
            groupNameKo: "캐나다 테스트 교회",
            kakaoURL: "https://open.kakao.com/o/example",
            isActive: true
        )
        let store = FakeBranchConnectStore(result: .success(info))
        let viewModel = BranchConnectViewModel(store: store)

        viewModel.load(branchId: "canada-test")

        try await waitUntil { viewModel.info?.kakaoURL == info.kakaoURL }
        XCTAssertEqual(store.requestedBranchID, "canada-test")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testFailureProducesRecoverableErrorState() async throws {
        let viewModel = BranchConnectViewModel(
            store: FakeBranchConnectStore(result: .failure(TestError.unavailable))
        )

        viewModel.load(branchId: "canada-test")

        try await waitUntil { viewModel.errorMessage != nil }
        XCTAssertNil(viewModel.info)
        XCTAssertFalse(viewModel.isLoading)
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw TestError.timeout }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

private final class FakeBranchConnectStore: BranchConnectRemoteStore {
    let result: Result<BranchConnectInfo?, Error>
    private(set) var requestedBranchID: String?

    init(result: Result<BranchConnectInfo?, Error>) { self.result = result }

    func fetch(branchId: String, completion: @escaping (Result<BranchConnectInfo?, Error>) -> Void) {
        requestedBranchID = branchId
        completion(result)
    }
}

private enum TestError: Error {
    case unavailable
    case timeout
}
