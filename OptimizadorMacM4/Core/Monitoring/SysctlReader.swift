import Darwin
import Foundation

enum SysctlReader {
    static func readInt32(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname(name, &value, &size, nil, 0)
        return result == 0 ? value : nil
    }

    static func readUInt64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        let result = sysctlbyname(name, &value, &size, nil, 0)
        return result == 0 ? value : nil
    }

    static func cpuCoreInfo() -> CPUCoreInfo {
        let perf = Int(readInt32("hw.perflevel0.physicalcpu") ?? 0)
        let eff = Int(readInt32("hw.perflevel1.physicalcpu") ?? 0)
        let total = Int(readInt32("hw.logicalcpu") ?? readInt32("hw.ncpu") ?? 1)
        if perf + eff > 0 {
            return CPUCoreInfo(
                performanceCoreCount: max(perf, 1),
                efficiencyCoreCount: max(eff, 0),
                totalLogicalCores: total
            )
        }
        return CPUCoreInfo(performanceCoreCount: total, efficiencyCoreCount: 0, totalLogicalCores: total)
    }

    static func physicalMemoryBytes() -> UInt64 {
        if let mem = readUInt64("hw.memsize") { return mem }
        return ProcessInfo.processInfo.physicalMemory
    }
}
