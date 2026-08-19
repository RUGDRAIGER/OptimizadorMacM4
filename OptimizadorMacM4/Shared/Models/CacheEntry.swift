import Foundation

struct CacheEntry: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let path: String
    let sizeBytes: UInt64
    let isAllowed: Bool
    let rejectionReason: String?

    var formattedSize: String {
        ByteFormatter.string(from: sizeBytes)
    }

    var statusLabel: String {
        isAllowed ? "Permitido" : "Bloqueado"
    }
}

enum CacheConfirmation: Identifiable {
    case clean(selectedCount: Int, recoverable: String)
    case purge

    var id: String {
        switch self {
        case .clean: return "clean"
        case .purge: return "purge"
        }
    }
}

struct CacheScanResult: Sendable {
    let entries: [CacheEntry]
    let totalBytes: UInt64
    let scannedAt: Date
    let isDryRun: Bool

    var formattedTotal: String {
        ByteFormatter.string(from: totalBytes)
    }
}

struct CacheCleanupResult: Sendable {
    let deletedBytes: UInt64
    let deletedPaths: [String]
    let errors: [String]
}
