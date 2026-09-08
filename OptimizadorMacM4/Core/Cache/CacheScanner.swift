import Foundation

enum DiskVolumeReader {
    static func readHomeVolume() -> DiskVolumeSummary? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var stats = statfs()
        guard statfs(home, &stats) == 0 else { return nil }
        let blockSize = UInt64(stats.f_bsize)
        let total = UInt64(stats.f_blocks) * blockSize
        let free = UInt64(stats.f_bavail) * blockSize
        let used = total > free ? total - free : 0
        return DiskVolumeSummary(totalBytes: total, freeBytes: free, usedBytes: used)
    }
}

enum CacheScanner {
    static func targetPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return PathGuard.storageTargets.map { $0.resolvedPath(home: home) }
            .filter { FileManager.default.fileExists(atPath: $0) }
    }

    static func scan(dryRun: Bool = true) async -> CacheScanResult {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var entries: [CacheEntry] = []

        for target in PathGuard.storageTargets {
            let root = target.resolvedPath(home: home)
            guard FileManager.default.fileExists(atPath: root) else { continue }

            let rootSize = directorySize(at: root)
            let rootAllowed = target.cleanable && PathGuard.isAllowedCachePath(root)
            entries.append(makeEntry(
                path: root,
                size: rootSize,
                target: target,
                allowed: rootAllowed
            ))

            if target.cleanable,
               let children = try? FileManager.default.contentsOfDirectory(atPath: root) {
                for child in children {
                    let childPath = (root as NSString).appendingPathComponent(child)
                    var isDir: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: childPath, isDirectory: &isDir),
                          isDir.boolValue else { continue }
                    let childSize = directorySize(at: childPath)
                    let childAllowed = PathGuard.isAllowedCachePath(childPath)
                    entries.append(makeEntry(
                        path: childPath,
                        size: childSize,
                        target: target,
                        allowed: childAllowed
                    ))
                }
            }
        }

        entries.append(contentsOf: advisoryEntries(home: home))

        let deduped = dedupeEntries(entries)
        let cleanable = deduped.filter(\.isAllowed)
        let total = cleanable.reduce(UInt64(0)) { $0 + $1.sizeBytes }
        let summaries = makeCategorySummaries(from: deduped)

        return CacheScanResult(
            entries: deduped.sorted { $0.sizeBytes > $1.sizeBytes },
            totalBytes: total,
            scannedAt: .now,
            isDryRun: dryRun,
            volume: DiskVolumeReader.readHomeVolume(),
            categorySummaries: summaries
        )
    }

    private static func makeEntry(
        path: String,
        size: UInt64,
        target: StorageTargetDefinition,
        allowed: Bool
    ) -> CacheEntry {
        CacheEntry(
            id: path,
            path: path,
            sizeBytes: size,
            isAllowed: allowed,
            rejectionReason: allowed ? nil : PathGuard.validateForDeletion(path),
            category: target.category,
            risk: allowed ? target.risk : (target.cleanable ? .blocked : .advisory),
            note: target.note
        )
    }

    private static func advisoryEntries(home: String) -> [CacheEntry] {
        let advisoryPaths: [(String, StorageCategory, String)] = [
            ("Library/Application Support/Steam", .advisory, "Datos de juegos Steam. Libera espacio desinstalando juegos desde Steam, no borres esta carpeta."),
            ("Library/Application Support/Google", .advisory, "Datos de Chrome/Drive. Contiene perfiles y extensiones."),
            ("Library/Application Support/Cursor", .advisory, "Datos del editor Cursor. Incluye cachés internos y extensiones."),
            ("Library/Application Support/Notion", .advisory, "Base de datos local de Notion. No borrar manualmente."),
        ]

        return advisoryPaths.compactMap { relative, category, note in
            let path = (home as NSString).appendingPathComponent(relative)
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let size = directorySize(at: path)
            guard size > 0 else { return nil }
            return CacheEntry(
                id: "advisory:\(path)",
                path: path,
                sizeBytes: size,
                isAllowed: false,
                rejectionReason: "Solo informativo — no se eliminará automáticamente.",
                category: category,
                risk: .advisory,
                note: note
            )
        }
    }

    private static func dedupeEntries(_ entries: [CacheEntry]) -> [CacheEntry] {
        var bestByPath: [String: CacheEntry] = [:]
        for entry in entries {
            if let existing = bestByPath[entry.path] {
                if entry.sizeBytes >= existing.sizeBytes {
                    bestByPath[entry.path] = entry
                }
            } else {
                bestByPath[entry.path] = entry
            }
        }
        return Array(bestByPath.values)
    }

    private static func makeCategorySummaries(from entries: [CacheEntry]) -> [CategorySummary] {
        var totals: [StorageCategory: UInt64] = [:]
        for entry in entries where entry.isAllowed || entry.risk == .advisory {
            totals[entry.category, default: 0] += entry.sizeBytes
        }
        return totals.map { CategorySummary(category: $0.key, totalBytes: $0.value) }
            .sorted { $0.totalBytes > $1.totalBytes }
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

enum SimulatorCleaner {
    static func deleteUnavailableSimulators() async -> SimulatorCleanupResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "delete", "unavailable"]

        do {
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                return SimulatorCleanupResult(
                    deletedCount: 1,
                    message: output.isEmpty
                        ? "Simuladores iOS obsoletos eliminados correctamente."
                        : output.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            return SimulatorCleanupResult(
                deletedCount: 0,
                message: "simctl terminó con código \(process.terminationStatus): \(output)"
            )
        } catch {
            return SimulatorCleanupResult(
                deletedCount: 0,
                message: "No se pudo ejecutar simctl: \(error.localizedDescription)"
            )
        }
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
                ? "Memoria RAM purgable liberada. Nota: esto no libera espacio en disco."
                : "purge terminó con código \(process.terminationStatus)."
        } catch {
            message = "No se pudo ejecutar purge: \(error.localizedDescription)"
        }

        try? await Task.sleep(nanoseconds: 500_000_000)
        let after = HostStatisticsReader.readMemoryMetrics()
        return PurgeResult(success: success, message: message, memoryBefore: before, memoryAfter: after)
    }
}
