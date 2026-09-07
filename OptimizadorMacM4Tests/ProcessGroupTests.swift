import XCTest
@testable import OptimizadorMacM4

final class ProcessGroupTests: XCTestCase {
    func testGroupsByName() {
        let processes = [
            sample(name: "Helper", pid: 1, memory: 100),
            sample(name: "Helper", pid: 2, memory: 50),
            sample(name: "Safari", pid: 3, memory: 200)
        ]
        let groups = ProcessGroup.grouped(from: processes)
        XCTAssertEqual(groups.count, 2)
        let helper = groups.first(where: { $0.name == "Helper" })
        XCTAssertEqual(helper?.instanceCount, 2)
        XCTAssertEqual(helper?.totalMemoryMB ?? 0, 150, accuracy: 0.1)
    }

    func testSystemProcessExcluded() {
        let system = sample(name: "WindowServer", pid: 200, memory: 100, path: "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer")
        XCTAssertFalse(ProcessFilter.isUserApplication(system))
    }

    func testUserAppIncluded() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let app = sample(
            name: "MyApp Helper",
            pid: 500,
            memory: 80,
            path: "\(home)/Library/Containers/com.test.app/Data/MyApp Helper"
        )
        XCTAssertTrue(ProcessFilter.isUserApplication(app))
    }

    private func sample(name: String, pid: Int32, memory: Double, path: String = "") -> ProcessSnapshot {
        ProcessSnapshot(
            id: pid, name: name, uid: getuid(), cpuPercent: 1, memoryMB: memory,
            state: .running, path: path, isBackgroundCandidate: true,
            isProtected: false, protectionReason: nil
        )
    }
}
