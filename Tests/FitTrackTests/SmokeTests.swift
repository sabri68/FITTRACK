import XCTest
@testable import FitTrack

final class SmokeTests: XCTestCase {
    func testAppName() {
        XCTAssertEqual(AppInfo.name, "FitTrack")
    }
}
