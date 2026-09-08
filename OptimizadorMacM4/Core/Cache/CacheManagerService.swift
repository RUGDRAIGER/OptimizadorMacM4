import Foundation

@MainActor
final class CacheManagerService: ObservableObject {
    @Published private(set) var scanResult: CacheScanResult?
    @Published private(set) var cleanupResult: CacheCleanupResult?
    @Published private(set) var purgeResult: PurgeExecutor.PurgeResult?
    @Published private(set) var isScanning = false
    @Published private(set) var isCleaning = false
    @Published private(set) var isPurging = false
    @Published private(set) var isCleaningSimulators = false
    @Published private(set) var logMessages: [String] = []

    func performDryRun() async {
        isScanning = true
        appendLog("Escaneando almacenamiento del disco...")
        let result = await CacheScanner.scan(dryRun: true)
        scanResult = result
        if let volume = result.volume {
            appendLog("Disco: \(volume.formattedUsed) usados de \(volume.formattedTotal) (\(String(format: "%.0f", volume.usedPercent))%).")
            appendLog("Espacio libre actual: \(volume.formattedFree).")
        }
        appendLog("Recuperable de forma segura: \(result.formattedTotal) en \(result.cleanableEntries.count) ubicaciones.")
        let advisory = result.entries.filter { $0.risk == .advisory }
        if !advisory.isEmpty {
            appendLog("Informativo: \(advisory.count) carpetas grandes detectadas (no se borran solas).")
        }
        isScanning = false
    }

    func performCleanup(selectedPaths: Set<String>? = nil) async {
        guard let scanResult else {
            appendLog("Ejecuta un Dry Run antes de limpiar.")
            return
        }

        isCleaning = true
        appendLog("Iniciando limpieza de disco...")

        let targets: [CacheEntry]
        if let selectedPaths, !selectedPaths.isEmpty {
            targets = scanResult.entries.filter { selectedPaths.contains($0.path) && $0.isAllowed }
        } else {
            targets = scanResult.entries.filter { entry in
                entry.isAllowed && entry.risk == .safe
            }
        }

        let result = await CacheCleaner.clean(entries: targets)
        cleanupResult = result
        appendLog("Limpieza completada: \(ByteFormatter.string(from: result.deletedBytes)) liberados en disco.")
        for error in result.errors {
            appendLog("Error: \(error)")
        }
        isCleaning = false
        await performDryRun()
    }

    func performPurge() async {
        isPurging = true
        appendLog("Ejecutando purge de memoria RAM (no libera disco)...")
        let result = await PurgeExecutor.purgeMemory()
        purgeResult = result
        appendLog(result.message)
        appendLog("RAM libre antes: \(ByteFormatter.string(from: result.memoryBefore.freeBytes))")
        appendLog("RAM libre después: \(ByteFormatter.string(from: result.memoryAfter.freeBytes))")
        isPurging = false
    }

    func performSimulatorCleanup() async {
        isCleaningSimulators = true
        appendLog("Eliminando simuladores iOS obsoletos...")
        let result = await SimulatorCleaner.deleteUnavailableSimulators()
        appendLog(result.message)
        isCleaningSimulators = false
        await performDryRun()
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
