import Foundation

enum MemoryPressureLevel: String, Codable, Sendable {
    case normal
    case warning
    case critical

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Advertencia"
        case .critical: return "Crítica"
        }
    }
}

struct MemoryMetrics: Codable, Sendable, Equatable {
    let freeBytes: UInt64
    let activeBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let totalBytes: UInt64
    let pressure: MemoryPressureLevel
    let timestamp: Date

    var usedBytes: UInt64 {
        min(totalBytes, activeBytes + wiredBytes + compressedBytes)
    }

    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    func percentage(of bytes: UInt64) -> Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytes) / Double(totalBytes) * 100
    }

    var freePercentage: Double { percentage(of: freeBytes) }
    var activePercentage: Double { percentage(of: activeBytes) }
    var wiredPercentage: Double { percentage(of: wiredBytes) }
    var compressedPercentage: Double { percentage(of: compressedBytes) }
}
