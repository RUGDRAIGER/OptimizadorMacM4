import Foundation

@MainActor
final class CacheManagerService: ObservableObject {
    @Published private(set) var scanResult: CacheScanResult?
    @Published private(set) var cleanupResult: CacheCleanupResult?
    @Published private(set) var purgeResult: PurgeExecutor.PurgeResult?
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var isPurging = false
    @Published private(set) var logMessages: [String] = []

    func performDryRun() async {
        isScanning = true
        appendLog("Iniciando Dry Run...")
        let result = await CacheScanner.scan(dryRun: true)
        scanResult = result
        appendLog("Dry Run completado: \(result.formattedTotal) recuperables en \(result.entries.filter(\.isAllowed).count) ubicaciones.")
        isScanning = false
    }

    func performCleanup(selectedPaths: Set<String>? = nil) async {
        guard let scanResult else {
            appendLog("Ejecuta un Dry Run antes de limpiar.")
            return
        }

        isCleaning = true
        appendLog("Iniciando limpieza...")

        let targets: [CacheEntry]
        if let selectedPaths {
            targets = scanResult.entries.filter { selectedPaths.contains($0.path) && $0.isAllowed }
        } else {
            targets = scanResult.entries.filter(\.isAllowed)
        }

        let result = await CacheCleaner.clean(entries: targets)
        cleanupResult = result
        appendLog("Limpieza completada: \(ByteFormatter.string(from: result.deletedBytes)) liberados.")
        for error in result.errors {
            appendLog("Error: \(error)")
        }
        isCleaning = false
        await performDryRun()
    }

    func performPurge() async {
        isPurging = true
        appendLog("Ejecutando purge de memoria purgable...")
        let result = await PurgeExecutor.purgeMemory()
        purgeResult = result
        appendLog(result.message)
        appendLog("Memoria libre antes: \(ByteFormatter.string(from: result.memoryBefore.freeBytes))")
        appendLog("Memoria libre después: \(ByteFormatter.string(from: result.memoryAfter.freeBytes))")
        isPurging = false
    }

    private func appendLog(_ message: String) {
        let entry = "[\(Self.timeFormatter.string(from: .now))] \(message)"
        logMessages.insert(entry, at: 0)
        AppLogger.info(message, category: .cache)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}
