import XCTest
@testable import OpencodeUsageTrackerApp

final class DesignTokensTests: XCTestCase {
    func testTypographyValues() {
        XCTAssertEqual(DesignSystem.Typography.displayLarge, 24)
        XCTAssertEqual(DesignSystem.Typography.captionSmall, 10)
    }

    func testSpacingValues() {
        XCTAssertEqual(DesignSystem.Spacing.xs, 4)
        XCTAssertEqual(DesignSystem.Spacing.xxl, 32)
    }

    func testUsageStatusSafe() {
        let status = UsageStatus(usedPercentage: 0.5)
        XCTAssertEqual(status, .safe)
    }

    func testUsageStatusWarning() {
        let status = UsageStatus(usedPercentage: 0.75)
        XCTAssertEqual(status, .warning)
    }

    func testUsageStatusCritical() {
        let status = UsageStatus(usedPercentage: 0.95)
        XCTAssertEqual(status, .critical)
    }

    func testUsageStatusBoundarySafe() {
        let status = UsageStatus(usedPercentage: 0.7)
        XCTAssertEqual(status, .warning)
    }

    func testUsageStatusBoundaryWarning() {
        let status = UsageStatus(usedPercentage: 0.9)
        XCTAssertEqual(status, .critical)
    }
}
