import Foundation

struct CacheEntry: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let path: String
    let sizeBytes: UInt64
    let isAllowed: Bool
    let rejectionReason: String?
    let category: StorageCategory
    let risk: StorageRisk
    let note: String

    init(
        id: String,
        path: String,
        sizeBytes: UInt64,
        isAllowed: Bool,
        rejectionReason: String?,
        category: StorageCategory = .userCaches,
        risk: StorageRisk = .safe,
        note: String = ""
    ) {
        self.id = id
        self.path = path
        self.sizeBytes = sizeBytes
        self.isAllowed = isAllowed
        self.rejectionReason = rejectionReason
        self.category = category
        self.risk = risk
        self.note = note
    }

    var formattedSize: String {
        ByteFormatter.string(from: sizeBytes)
    }

    var statusLabel: String {
        if !isAllowed {
            return risk == .advisory ? "Solo info" : "Bloqueado"
        }
        return risk.label
    }
}

enum CacheConfirmation: Identifiable {
    case clean(selectedCount: Int, recoverable: String)
    case purge
    case simulators

    var id: String {
        switch self {
        case .clean: return "clean"
        case .purge: return "purge"
        case .simulators: return "simulators"
        }
    }
}

struct CacheScanResult: Sendable {
    let entries: [CacheEntry]
    let totalBytes: UInt64
    let scannedAt: Date
    let isDryRun: Bool
    let volume: DiskVolumeSummary?
    let categorySummaries: [CategorySummary]

    var formattedTotal: String {
        ByteFormatter.string(from: totalBytes)
    }

    var cleanableEntries: [CacheEntry] {
        entries.filter(\.isAllowed)
    }
}

struct CacheCleanupResult: Sendable {
    let deletedBytes: UInt64
    let deletedPaths: [String]
    let errors: [String]
}

struct SimulatorCleanupResult: Sendable {
    let deletedCount: Int
    let message: String
}
