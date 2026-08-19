import XCTest
@testable import OptimizadorMacM4

final class MemoryMetricsTests: XCTestCase {
    func testPercentageCalculation() {
        let metrics = MemoryMetrics(
            freeBytes: 2_000_000_000,
            activeBytes: 6_000_000_000,
            wiredBytes: 2_000_000_000,
            compressedBytes: 1_000_000_000,
            totalBytes: 16_000_000_000,
            pressure: .warning,
            timestamp: .now
        )

        XCTAssertEqual(metrics.freePercentage, 12.5, accuracy: 0.1)
        XCTAssertEqual(metrics.activePercentage, 37.5, accuracy: 0.1)
        XCTAssertEqual(metrics.wiredPercentage, 12.5, accuracy: 0.1)
        XCTAssertEqual(metrics.compressedPercentage, 6.25, accuracy: 0.1)
    }

    func testUsedPercentage() {
        let metrics = MemoryMetrics(
            freeBytes: 4_000_000_000,
            activeBytes: 4_000_000_000,
            wiredBytes: 2_000_000_000,
            compressedBytes: 2_000_000_000,
            totalBytes: 16_000_000_000,
            pressure: .normal,
            timestamp: .now
        )

        XCTAssertEqual(metrics.usedPercentage, 50.0, accuracy: 0.1)
    }
}

final class AppSectionTests: XCTestCase {
    func testAllSectionsPresent() {
        XCTAssertEqual(AppSection.allCases.count, 3)
        XCTAssertTrue(AppSection.allCases.contains(.monitor))
        XCTAssertTrue(AppSection.allCases.contains(.processes))
        XCTAssertTrue(AppSection.allCases.contains(.cache))
    }
}

final class ProcessEnumeratorTests: XCTestCase {
    func testProcessNamesAreNotUnknown() {
        let processes = ProcessEnumerator.topProcesses(limit: 10, sortByCPU: false)
        XCTAssertFalse(processes.isEmpty, "Debe listar procesos del sistema")

        let unknownCount = processes.filter { $0.name == "unknown" }.count
        XCTAssertEqual(unknownCount, 0, "Ningún proceso debería llamarse 'unknown'")
    }

    func testProcessNamesAreReadable() {
        let processes = ProcessEnumerator.topProcesses(limit: 5, sortByCPU: true)
        for process in processes {
            XCTAssertFalse(process.name.isEmpty)
            XCTAssertNotEqual(process.name, "unknown")
        }
    }
}
