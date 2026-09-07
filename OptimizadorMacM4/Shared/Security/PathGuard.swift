import Foundation

enum PathGuard {
    static let blockedPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/var/db",
        "/private/var/db"
    ]

    static let allowedCacheRoots: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library/Caches",
            "/Library/Caches",
            "\(home)/Library/Developer/Xcode/DerivedData"
        ]
    }()

    static func normalizedPath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    static func isBlocked(_ path: String) -> Bool {
        let normalized = normalizedPath(path)
        return blockedPrefixes.contains { normalized == $0 || normalized.hasPrefix($0 + "/") }
    }

    static func isAllowedCachePath(_ path: String) -> Bool {
        let normalized = normalizedPath(path)
        if isBlocked(normalized) { return false }
        return allowedCacheRoots.contains { root in
            normalized == root || normalized.hasPrefix(root + "/")
        }
    }

    static func validateForDeletion(_ path: String) -> String? {
        let normalized = normalizedPath(path)
        if isBlocked(normalized) {
            return "Ruta protegida por SIP: \(normalized)"
        }
        if !isAllowedCachePath(normalized) {
            return "Ruta fuera de las ubicaciones de caché permitidas: \(normalized)"
        }
        return nil
    }
}
