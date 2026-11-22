import XCTest
@testable import FitTrackWatch

final class WatchSmokeTests: XCTestCase {
    func testAppName() {
        XCTAssertEqual(AppInfo.name, "FitTrack")
    }
}
