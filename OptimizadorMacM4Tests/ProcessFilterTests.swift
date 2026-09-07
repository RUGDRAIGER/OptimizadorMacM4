import XCTest
@testable import OptimizadorMacM4

final class ProcessFilterTests: XCTestCase {
    func testBackgroundCandidateDetectsHelper() {
        XCTAssertTrue(ProcessFilter.isBackgroundCandidate(name: "Chrome Helper", path: "/Applications/Chrome.app"))
    }

    func testWhitelistExcludesCursor() {
        XCTAssertFalse(ProcessFilter.isBackgroundCandidate(name: "Cursor Helper", path: "/Applications/Cursor.app"))
    }

    func testSearchMatchesPID() {
        let process = ProcessSnapshot(
            id: 1234, name: "test", uid: 501, cpuPercent: 1, memoryMB: 10,
            state: .running, path: "", isBackgroundCandidate: false,
            isProtected: false, protectionReason: nil
        )
        XCTAssertTrue(ProcessFilter.matchesSearch(process, query: "1234"))
        XCTAssertFalse(ProcessFilter.matchesSearch(process, query: "9999"))
    }
}
