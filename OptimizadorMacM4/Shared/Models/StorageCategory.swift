import Foundation

enum StorageCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case userCaches = "Cachés de apps"
    case developer = "Desarrollador"
    case logs = "Registros"
    case downloads = "Descargas"
    case trash = "Papelera"
    case systemCaches = "Cachés del sistema (usuario)"
    case advisory = "Solo informativo"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .userCaches: return "folder.fill"
        case .developer: return "hammer.fill"
        case .logs: return "doc.text.fill"
        case .downloads: return "arrow.down.circle.fill"
        case .trash: return "trash.fill"
        case .systemCaches: return "externaldrive.fill"
        case .advisory: return "info.circle.fill"
        }
    }
}

enum StorageRisk: String, Codable, Sendable, Comparable {
    case safe
    case caution
    case blocked
    case advisory

    var label: String {
        switch self {
        case .safe: return "Seguro"
        case .caution: return "Revisar"
        case .blocked: return "Bloqueado"
        case .advisory: return "Info"
        }
    }

    private var sortOrder: Int {
        switch self {
        case .safe: return 0
        case .caution: return 1
        case .advisory: return 2
        case .blocked: return 3
        }
    }

    static func < (lhs: StorageRisk, rhs: StorageRisk) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

struct StorageTargetDefinition: Sendable {
    let relativePath: String
    let category: StorageCategory
    let risk: StorageRisk
    let cleanable: Bool
    let note: String

    func resolvedPath(home: String = FileManager.default.homeDirectoryForCurrentUser.path) -> String {
        if relativePath.hasPrefix("/") {
            return relativePath
        }
        return (home as NSString).appendingPathComponent(relativePath)
    }
}

struct DiskVolumeSummary: Sendable {
    let totalBytes: UInt64
    let freeBytes: UInt64
    let usedBytes: UInt64

    var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }

    var formattedTotal: String { ByteFormatter.string(from: totalBytes) }
    var formattedFree: String { ByteFormatter.string(from: freeBytes) }
    var formattedUsed: String { ByteFormatter.string(from: usedBytes) }
}

struct CategorySummary: Identifiable, Sendable {
    let category: StorageCategory
    let totalBytes: UInt64

    var id: String { category.rawValue }
    var formattedTotal: String { ByteFormatter.string(from: totalBytes) }
}
