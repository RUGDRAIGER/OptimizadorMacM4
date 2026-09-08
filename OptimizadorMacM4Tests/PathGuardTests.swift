import XCTest
@testable import OptimizadorMacM4

final class PathGuardTests: XCTestCase {
    func testBlocksSystemPath() {
        XCTAssertTrue(PathGuard.isBlocked("/System/Library/LaunchDaemons"))
    }

    func testBlocksApplicationSupport() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/Library/Application Support/Steam"
        XCTAssertTrue(PathGuard.isBlocked(path))
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

    func testAllowsLogs() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/Library/Logs/DiagnosticReports"
        XCTAssertNil(PathGuard.validateForDeletion(path))
    }

    func testSimulatorDevicesNotCleanable() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/Library/Developer/CoreSimulator/Devices"
        XCTAssertNotNil(PathGuard.validateForDeletion(path))
    }
}

final class StorageScannerTests: XCTestCase {
    func testScanReturnsVolume() async {
        let result = await CacheScanner.scan()
        XCTAssertNotNil(result.volume)
        XCTAssertFalse(result.entries.isEmpty)
    }

    func testCategorySummariesExist() async {
        let result = await CacheScanner.scan()
        XCTAssertFalse(result.categorySummaries.isEmpty)
    }
}
