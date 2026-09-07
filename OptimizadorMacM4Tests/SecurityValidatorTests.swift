import XCTest
@testable import OptimizadorMacM4

final class SecurityValidatorTests: XCTestCase {
    func testProtectedPID() {
        let process = ProcessSnapshot(
            id: 1, name: "launchd", uid: 0, cpuPercent: 0, memoryMB: 0,
            state: .running, path: "", isBackgroundCandidate: false,
            isProtected: true, protectionReason: "PID de sistema"
        )
        XCTAssertNotNil(SecurityValidator.validateProcessAction(process))
    }

    func testRootProcessWarning() {
        let process = ProcessSnapshot(
            id: 200, name: "custom", uid: 0, cpuPercent: 0, memoryMB: 0,
            state: .running, path: "", isBackgroundCandidate: true,
            isProtected: true, protectionReason: "root"
        )
        let error = SecurityValidator.validateProcessAction(process)
        if case .rootProcess = error {
            XCTAssertTrue(true)
        } else {
            XCTFail("Se esperaba error rootProcess")
        }
    }
}
