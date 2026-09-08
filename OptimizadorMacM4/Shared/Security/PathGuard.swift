import Foundation

enum PathGuard {
    static let blockedPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/var/db",
        "/private/var/db",
        "/Library",
    ]

    static let storageTargets: [StorageTargetDefinition] = {
        [
            StorageTargetDefinition(
                relativePath: "Library/Caches",
                category: .userCaches,
                risk: .safe,
                cleanable: true,
                note: "Cachés temporales de aplicaciones. Se regeneran al usar cada app."
            ),
            StorageTargetDefinition(
                relativePath: "Library/Logs",
                category: .logs,
                risk: .safe,
                cleanable: true,
                note: "Registros antiguos. No afecta apps ni documentos."
            ),
            StorageTargetDefinition(
                relativePath: "Library/Developer/Xcode/DerivedData",
                category: .developer,
                risk: .safe,
                cleanable: true,
                note: "Compilaciones temporales de Xcode. El próximo build tarda un poco más."
            ),
            StorageTargetDefinition(
                relativePath: "Library/Developer/Xcode/Archives",
                category: .developer,
                risk: .caution,
                cleanable: true,
                note: "Archivos .ipa/.xcarchive para publicar. Borra solo si ya no los necesitas."
            ),
            StorageTargetDefinition(
                relativePath: "Library/Developer/Xcode/iOS DeviceSupport",
                category: .developer,
                risk: .caution,
                cleanable: true,
                note: "Símbolos de iOS conectados. macOS los vuelve a descargar al conectar un iPhone."
            ),
            StorageTargetDefinition(
                relativePath: "Library/Developer/CoreSimulator/Caches",
                category: .developer,
                risk: .safe,
                cleanable: true,
                note: "Cachés del simulador iOS. Seguro de limpiar."
            ),
            StorageTargetDefinition(
                relativePath: "Library/Developer/CoreSimulator/Devices",
                category: .developer,
                risk: .caution,
                cleanable: false,
                note: "Datos de simuladores. Usa 'Limpiar simuladores obsoletos' en lugar de borrar todo."
            ),
            StorageTargetDefinition(
                relativePath: "Library/Caches/Homebrew",
                category: .userCaches,
                risk: .safe,
                cleanable: true,
                note: "Caché de descargas Homebrew. Se vuelve a descargar si hace falta."
            ),
            StorageTargetDefinition(
                relativePath: "Library/Caches/pip",
                category: .developer,
                risk: .safe,
                cleanable: true,
                note: "Caché de paquetes Python pip."
            ),
            StorageTargetDefinition(
                relativePath: ".npm/_cacache",
                category: .developer,
                risk: .safe,
                cleanable: true,
                note: "Caché de npm. Se regenera al instalar paquetes."
            ),
            StorageTargetDefinition(
                relativePath: "Downloads",
                category: .downloads,
                risk: .caution,
                cleanable: true,
                note: "Tus descargas. Revisa antes de borrar: pueden ser instaladores o archivos importantes."
            ),
            StorageTargetDefinition(
                relativePath: ".Trash",
                category: .trash,
                risk: .safe,
                cleanable: true,
                note: "Papelera del usuario. Vaciar libera espacio de forma segura."
            ),
        ]
    }()

    static let allowedCacheRoots: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return storageTargets
            .filter(\.cleanable)
            .map { $0.resolvedPath(home: home) }
    }()

    static func normalizedPath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    static func isBlocked(_ path: String) -> Bool {
        let normalized = normalizedPath(path)
        if blockedPrefixes.contains(where: { normalized == $0 || normalized.hasPrefix($0 + "/") }) {
            return true
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let appSupport = (home as NSString).appendingPathComponent("Library/Application Support")
        if normalized.hasPrefix(appSupport + "/") {
            return true
        }
        return false
    }

    static func targetDefinition(for path: String) -> StorageTargetDefinition? {
        let normalized = normalizedPath(path)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return storageTargets.first { target in
            let root = normalizedPath(target.resolvedPath(home: home))
            return normalized == root || normalized.hasPrefix(root + "/")
        }
    }

    static func isAllowedCachePath(_ path: String) -> Bool {
        let normalized = normalizedPath(path)
        if isBlocked(normalized) { return false }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return storageTargets.contains { target in
            guard target.cleanable else { return false }
            let root = normalizedPath(target.resolvedPath(home: home))
            return normalized == root || normalized.hasPrefix(root + "/")
        }
    }

    static func validateForDeletion(_ path: String) -> String? {
        let normalized = normalizedPath(path)
        if isBlocked(normalized) {
            return "Ruta protegida: \(normalized)"
        }
        if !isAllowedCachePath(normalized) {
            if let definition = targetDefinition(for: normalized), !definition.cleanable {
                return "Ruta solo informativa. Usa la acción dedicada si está disponible."
            }
            return "Ruta fuera de las ubicaciones permitidas: \(normalized)"
        }
        return nil
    }
}
