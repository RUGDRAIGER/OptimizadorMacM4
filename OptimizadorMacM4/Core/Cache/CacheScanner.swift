import Foundation

enum CacheScanner {
    static func targetPaths() -> [String] {
        PathGuard.allowedCacheRoots.filter { FileManager.default.fileExists(atPath: $0) }
    }

    static func scan(dryRun: Bool = true) async -> CacheScanResult {
        let paths = targetPaths()
        var entries: [CacheEntry] = []

        for root in paths {
            let size = directorySize(at: root)
            let allowed = PathGuard.isAllowedCachePath(root)
            entries.append(CacheEntry(
                id: root,
                path: root,
                sizeBytes: size,
                isAllowed: allowed,
                rejectionReason: allowed ? nil : PathGuard.validateForDeletion(root)
            ))

            if let children = try? FileManager.default.contentsOfDirectory(atPath: root) {
                for child in children {
                    let childPath = (root as NSString).appendingPathComponent(child)
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: childPath, isDirectory: &isDir), isDir.boolValue else {
                        continue
                    }
                    let childSize = directorySize(at: childPath)
                    let childAllowed = PathGuard.isAllowedCachePath(childPath)
                    entries.append(CacheEntry(
                        id: childPath,
                        path: childPath,
                        sizeBytes: childSize,
                        isAllowed: childAllowed,
                        rejectionReason: childAllowed ? nil : PathGuard.validateForDeletion(childPath)
                    ))
                }
            }
        }

        let total = entries.filter(\.isAllowed).reduce(UInt64(0)) { $0 + $1.sizeBytes }
        return CacheScanResult(entries: entries.sorted { $0.sizeBytes > $1.sizeBytes }, totalBytes: total, scannedAt: .now, isDryRun: dryRun)
    }

    static func directorySize(at path: String) -> UInt64 {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }
            total += UInt64(size)
        }
        return total
    }
}

enum CacheCleaner {
    static func clean(entries: [CacheEntry]) async -> CacheCleanupResult {
        var deletedBytes: UInt64 = 0
        var deletedPaths: [String] = []
        var errors: [String] = []

        for entry in entries where entry.isAllowed {
            if let rejection = PathGuard.validateForDeletion(entry.path) {
                errors.append(rejection)
                continue
            }

            let sizeBefore = CacheScanner.directorySize(at: entry.path)
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: entry.path)
                for item in contents {
                    let itemPath = (entry.path as NSString).appendingPathComponent(item)
                    try FileManager.default.removeItem(atPath: itemPath)
                }
                deletedBytes += sizeBefore
                deletedPaths.append(entry.path)
                AppLogger.info("Limpiado: \(entry.path)", category: .cache)
            } catch {
                errors.append("\(entry.path): \(error.localizedDescription)")
                AppLogger.error("Error limpiando \(entry.path): \(error.localizedDescription)", category: .cache)
            }
        }

        return CacheCleanupResult(deletedBytes: deletedBytes, deletedPaths: deletedPaths, errors: errors)
    }
}

enum PurgeExecutor {
    struct PurgeResult: Sendable {
        let success: Bool
        let message: String
        let memoryBefore: MemoryMetrics
        let memoryAfter: MemoryMetrics
    }

    static func purgeMemory() async -> PurgeResult {
        let before = HostStatisticsReader.readMemoryMetrics()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        process.arguments = []

        var success = false
        var message = ""

        do {
            try process.run()
            process.waitUntilExit()
            success = process.terminationStatus == 0
            message = success
                ? "Memoria purgable liberada correctamente."
                : "purge terminó con código \(process.terminationStatus). Puede requerir privilegios elevados."
        } catch {
            message = "No se pudo ejecutar purge: \(error.localizedDescription)"
        }

        try? await Task.sleep(nanoseconds: 500_000_000)
        let after = HostStatisticsReader.readMemoryMetrics()
        return PurgeResult(success: success, message: message, memoryBefore: before, memoryAfter: after)
    }
}
