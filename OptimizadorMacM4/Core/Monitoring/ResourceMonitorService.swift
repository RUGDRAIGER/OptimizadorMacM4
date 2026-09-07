import Foundation

@MainActor
final class ResourceMonitorService: ObservableObject {
    @Published private(set) var cpuMetrics = CPUMetrics(
        performanceCoresUsage: 0, efficiencyCoresUsage: 0, totalUsage: 0,
        performanceCoreCount: 0, efficiencyCoreCount: 0, timestamp: .now
    )
    @Published private(set) var memoryMetrics = MemoryMetrics(
        freeBytes: 0, activeBytes: 0, wiredBytes: 0, compressedBytes: 0,
        totalBytes: 0, pressure: .normal, timestamp: .now
    )
    @Published private(set) var topProcessesByCPU: [ProcessSnapshot] = []
    @Published private(set) var topProcessesByMemory: [ProcessSnapshot] = []
    @Published private(set) var isRunning = false
    @Published var pollInterval: TimeInterval = 1.5

    private var pollingTask: Task<Void, Never>?
    private var cpuSample: CPUSample?

    func start() {
        guard pollingTask == nil else { return }
        isRunning = true
        pollingTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        isRunning = false
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            await refresh()
            let interval = pollInterval
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    func refresh() async {
        let memory = await Task.detached(priority: .utility) {
            HostStatisticsReader.readMemoryMetrics()
        }.value

        let cpuResult = await Task.detached(priority: .utility) { [cpuSample] in
            HostStatisticsReader.readCPULoad(previous: cpuSample.map {
                CPUSample(total: $0.total, performance: $0.performance, efficiency: $0.efficiency)
            })
        }.value

        let byCPU = await Task.detached(priority: .utility) {
            ProcessEnumerator.topProcesses(limit: 15, sortByCPU: true)
        }.value

        let byMemory = await Task.detached(priority: .utility) {
            ProcessEnumerator.topProcesses(limit: 15, sortByCPU: false)
        }.value

        cpuSample = cpuResult.sample
        cpuMetrics = cpuResult.metrics
        memoryMetrics = memory
        topProcessesByCPU = byCPU
        topProcessesByMemory = byMemory
    }
}
