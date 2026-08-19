import XCTest
@testable import OptimizadorMacM4

final class PathGuardTests: XCTestCase {
    func testBlocksSystemPath() {
        XCTAssertTrue(PathGuard.isBlocked("/System/Library/LaunchDaemons"))
    }

    func testAllowsUserCachePath() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let cachePath = "\(home)/Library/Caches/com.example"
        XCTAssertTrue(PathGuard.isAllowedCachePath(cachePath))
    }

    func testRejectsSystemForDeletion() {
        XCTAssertNotNil(PathGuard.validateForDeletion("/System/Library"))
    }

    func testAllowsDerivedData() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/Library/Developer/Xcode/DerivedData/MyApp"
        XCTAssertNil(PathGuard.validateForDeletion(path))
    }
}
