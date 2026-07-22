import XCTest
@testable import DanielApp

final class UserProfileAccessDisplayTests: XCTestCase {
    func testDisplaysBranchRegionRoleAndStatus() {
        let profile = UserProfile(
            name: "Member",
            email: "member@example.test",
            userId: "member-user",
            churchCountry: "CA",
            churchName: "Legacy Church",
            regionName: "Canada",
            branchName: "Daniel Test Church",
            isApproved: true,
            role: "branch_admin",
            accessRole: "branch_admin",
            membershipStatus: "active"
        )

        XCTAssertEqual(profile.displayBranchName(for: .english), "Daniel Test Church")
        XCTAssertEqual(profile.displayRegionName(for: .english), "Canada")
        XCTAssertEqual(profile.displayAccessRole(for: .chinese), "分堂管理员")
        XCTAssertEqual(profile.displayAccessRole(for: .english), "Branch Admin")
        XCTAssertEqual(profile.displayAccessRole(for: .korean), "지교회 관리자")
        XCTAssertEqual(profile.displayMembershipStatus(for: .english), "Approved")
    }

    func testFallsBackToLegacyChurchFieldsAndPendingStatus() {
        let profile = UserProfile(
            name: "Pending Member",
            email: "pending@example.test",
            userId: "pending-user",
            churchCountry: "Korea",
            churchName: "Seoul Central Church",
            isApproved: false,
            role: "member",
            accessRole: nil,
            membershipStatus: nil
        )

        XCTAssertEqual(profile.displayBranchName(for: .english), "Seoul Central Church")
        XCTAssertEqual(profile.displayRegionName(for: .english), "Korea")
        XCTAssertEqual(profile.displayAccessRole(for: .english), "Member")
        XCTAssertEqual(profile.displayMembershipStatus(for: .chinese), "审核中")
    }

    func testMissingBranchAndRegionAreLocalized() {
        let profile = UserProfile(
            name: "Member",
            email: "member@example.test",
            userId: "member-user",
            isApproved: true,
            role: "member",
            accessRole: "member",
            membershipStatus: "revoked"
        )

        XCTAssertEqual(profile.displayBranchName(for: .chinese), "未设置")
        XCTAssertEqual(profile.displayRegionName(for: .english), "Not set")
        XCTAssertEqual(profile.displayMembershipStatus(for: .korean), "중지됨")
    }
}
