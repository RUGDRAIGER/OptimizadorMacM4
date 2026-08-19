import Darwin
import Foundation

enum HostStatisticsReader {
    static func readMemoryMetrics() -> MemoryMetrics {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            AppLogger.error("host_statistics64 falló: \(result)", category: .monitor)
            return MemoryMetrics(
                freeBytes: 0, activeBytes: 0, wiredBytes: 0, compressedBytes: 0,
                totalBytes: SysctlReader.physicalMemoryBytes(), pressure: .normal, timestamp: .now
            )
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(stats.free_count) * pageSize
        let active = UInt64(stats.active_count + stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let total = SysctlReader.physicalMemoryBytes()
        let pressure = calculatePressure(free: free, wired: wired, total: total)

        return MemoryMetrics(
            freeBytes: free,
            activeBytes: active,
            wiredBytes: wired,
            compressedBytes: compressed,
            totalBytes: total,
            pressure: pressure,
            timestamp: .now
        )
    }

    static func readCPULoad(previous: CPUSample?) -> (metrics: CPUMetrics, sample: CPUSample) {
        let coreInfo = SysctlReader.cpuCoreInfo()
        let sample = sampleProcessorLoads()
        let totalUsage = usagePercent(current: sample.total, previous: previous?.total)
        let perfUsage = usagePercent(current: sample.performance, previous: previous?.performance)
        let effUsage = usagePercent(current: sample.efficiency, previous: previous?.efficiency)

        let metrics = CPUMetrics(
            performanceCoresUsage: perfUsage,
            efficiencyCoresUsage: effUsage,
            totalUsage: totalUsage,
            performanceCoreCount: coreInfo.performanceCoreCount,
            efficiencyCoreCount: coreInfo.efficiencyCoreCount,
            timestamp: .now
        )
        return (metrics, sample)
    }

    private static func calculatePressure(free: UInt64, wired: UInt64, total: UInt64) -> MemoryPressureLevel {
        guard total > 0 else { return .normal }
        let freeRatio = Double(free) / Double(total)
        let wiredRatio = Double(wired) / Double(total)
        if freeRatio < 0.05 || wiredRatio > 0.75 { return .critical }
        if freeRatio < 0.15 || wiredRatio > 0.55 { return .warning }
        return .normal
    }

    private static func usagePercent(current: LoadSample, previous: LoadSample?) -> Double {
        guard let previous else { return 0 }
        let user = Double(current.user - previous.user)
        let system = Double(current.system - previous.system)
        let idle = Double(current.idle - previous.idle)
        let nice = Double(current.nice - previous.nice)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return min(100, max(0, (user + system + nice) / total * 100))
    }

    private static func sampleProcessorLoads() -> CPUSample {
        var cpuInfo: processor_info_array_t?
        var numCPUs: natural_t = 0
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &cpuInfoCount
        )

        defer {
            if let cpuInfo {
                let size = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
            }
        }

        guard result == KERN_SUCCESS, let cpuInfo else {
            return CPUSample(total: .zero, performance: .zero, efficiency: .zero)
        }

        let coreInfo = SysctlReader.cpuCoreInfo()
        let perfCount = coreInfo.performanceCoreCount
        var perf = LoadSample.zero
        var eff = LoadSample.zero
        var total = LoadSample.zero

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let load = LoadSample(
                user: UInt64(cpuInfo[offset + Int(CPU_STATE_USER)]),
                system: UInt64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)]),
                idle: UInt64(cpuInfo[offset + Int(CPU_STATE_IDLE)]),
                nice: UInt64(cpuInfo[offset + Int(CPU_STATE_NICE)])
            )
            total = total.adding(load)
            if i < perfCount {
                perf = perf.adding(load)
            } else {
                eff = eff.adding(load)
            }
        }

        return CPUSample(total: total, performance: perf, efficiency: eff)
    }
}

struct CPUSample {
    let total: LoadSample
    let performance: LoadSample
    let efficiency: LoadSample
}

struct LoadSample {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64

    static let zero = LoadSample(user: 0, system: 0, idle: 0, nice: 0)

    func adding(_ other: LoadSample) -> LoadSample {
        LoadSample(
            user: user + other.user,
            system: system + other.system,
            idle: idle + other.idle,
            nice: nice + other.nice
        )
    }
}
