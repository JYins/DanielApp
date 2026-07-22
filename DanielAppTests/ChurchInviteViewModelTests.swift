import XCTest
@testable import DanielApp

@MainActor
final class ChurchInviteViewModelTests: XCTestCase {
    func testFormatsAndSubmitsSixteenCharacterCode() {
        let redemption = ChurchInviteRedemption(
            branchID: "canada-daniel-test-church",
            branchName: "Daniel Test Church",
            membershipStatus: "pending"
        )
        let service = StubChurchInviteService(result: .success(redemption))
        let viewModel = ChurchInviteViewModel(service: service)
        let submitted = expectation(description: "invite submitted")

        viewModel.updateCode("abcd-efgh-jkmn-pqrs")

        XCTAssertEqual(viewModel.formattedCode, "ABCD-EFGH-JKMN-PQRS")
        XCTAssertTrue(viewModel.canSubmit)

        viewModel.redeem { submitted.fulfill() }
        wait(for: [submitted], timeout: 1)

        XCTAssertEqual(service.redeemedCode, "ABCDEFGHJKMNPQRS")
        XCTAssertEqual(viewModel.state, .submitted(redemption))
    }

    func testInvalidCodeNeverCallsService() {
        let service = StubChurchInviteService(result: .failure(.invalid))
        let viewModel = ChurchInviteViewModel(service: service)

        viewModel.updateCode("TOO-SHORT")
        viewModel.redeem {}

        XCTAssertNil(service.redeemedCode)
        XCTAssertEqual(viewModel.state, .failed(.invalid))
    }

    func testServerErrorBecomesRecoverableFailureState() {
        let service = StubChurchInviteService(result: .failure(.expired))
        let viewModel = ChurchInviteViewModel(service: service)

        viewModel.updateCode("ABCD-EFGH-JKMN-PQRS")
        viewModel.redeem {}
        waitForMainQueue()

        XCTAssertEqual(viewModel.state, .failed(.expired))

        viewModel.updateCode("ABCD-EFGH-JKMN-PQRT")
        XCTAssertEqual(viewModel.state, .idle)
    }

    private func waitForMainQueue() {
        let settled = expectation(description: "main queue settled")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 1)
    }
}

private final class StubChurchInviteService: ChurchInviteServicing {
    let result: Result<ChurchInviteRedemption, ChurchInviteError>
    private(set) var redeemedCode: String?

    init(result: Result<ChurchInviteRedemption, ChurchInviteError>) {
        self.result = result
    }

    func redeem(
        code: String,
        completion: @escaping (Result<ChurchInviteRedemption, ChurchInviteError>) -> Void
    ) {
        redeemedCode = code
        completion(result)
    }
}
