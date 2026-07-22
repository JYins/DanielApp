import XCTest
@testable import DanielApp

@MainActor
final class RegistrationBranchServiceTests: XCTestCase {
    func testLoadsActiveBranchesFromInjectedStore() async {
        let branch = RegistrationBranch(
            id: "canada-daniel-test-church",
            regionId: "canada",
            nameZh: "Daniel 测试分堂",
            nameEn: "Daniel Test Church",
            nameKo: "Daniel 테스트 교회",
            regionNameZh: "加拿大",
            regionNameEn: "Canada",
            regionNameKo: "캐나다",
            country: "CA"
        )
        let remoteStore = FakeRegistrationBranchRemoteStore(result: .success([branch]))
        let viewModel = RegistrationBranchViewModel(remoteStore: remoteStore)

        viewModel.loadBranchesIfNeeded()
        await Task.yield()

        XCTAssertEqual(viewModel.branches, [branch])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testFailureExposesErrorWithoutCrashing() async {
        let remoteStore = FakeRegistrationBranchRemoteStore(result: .failure(TestBranchError.failure))
        let viewModel = RegistrationBranchViewModel(remoteStore: remoteStore)

        viewModel.loadBranchesIfNeeded()
        await Task.yield()

        XCTAssertTrue(viewModel.branches.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testLoadBranchesOnlyRunsOnce() async {
        let remoteStore = FakeRegistrationBranchRemoteStore(result: .success([]))
        let viewModel = RegistrationBranchViewModel(remoteStore: remoteStore)

        viewModel.loadBranchesIfNeeded()
        await Task.yield()
        viewModel.loadBranchesIfNeeded()
        await Task.yield()

        XCTAssertEqual(remoteStore.fetchCount, 1)
    }
}

private final class FakeRegistrationBranchRemoteStore: RegistrationBranchRemoteStore {
    private let result: Result<[RegistrationBranch], Error>
    private(set) var fetchCount = 0

    init(result: Result<[RegistrationBranch], Error>) {
        self.result = result
    }

    func fetchActiveBranches(completion: @escaping (Result<[RegistrationBranch], Error>) -> Void) {
        fetchCount += 1
        completion(result)
    }
}

private enum TestBranchError: LocalizedError {
    case failure

    var errorDescription: String? {
        "Branch load failed"
    }
}
