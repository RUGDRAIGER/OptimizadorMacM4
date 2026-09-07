import Darwin
import Foundation

enum ProcessEnumerator {
    private static var previousCPUTicks: [Int32: (user: UInt64, system: UInt64, date: Date)] = [:]
    private static let tickLock = NSLock()

    static func allPIDs() -> [Int32] {
        var length: size_t = 0
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        guard sysctl(&mib, 4, nil, &length, nil, 0) == 0, length > 0 else { return [] }

        let count = length / MemoryLayout<kinfo_proc>.size
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &length, nil, 0) == 0 else { return [] }

        return procs.map { Int32($0.kp_proc.p_pid) }.filter { $0 > 0 }
    }

    static func snapshot(for pid: Int32) -> ProcessSnapshot? {
        let kinfo = kinfoProc(for: pid)
        let name = processName(pid: pid, kinfo: kinfo)
        let path = processPath(pid: pid)
        let uid = processUID(pid: pid, kinfo: kinfo)
        let state = processState(kinfo: kinfo, pid: pid)

        let memoryMB: Double
        let cpu: Double
        if let info = taskInfo(for: pid) {
            memoryMB = Double(info.pti_resident_size) / 1_048_576.0
            cpu = cpuPercent(for: pid, info: info)
        } else {
            memoryMB = 0
            cpu = 0
        }

        let background = ProcessFilter.isBackgroundCandidate(name: name, path: path)
        let protection = protectionStatus(name: name, pid: pid, uid: uid)

        return ProcessSnapshot(
            id: pid,
            name: name,
            uid: uid,
            cpuPercent: cpu,
            memoryMB: memoryMB,
            state: state,
            path: path,
            isBackgroundCandidate: background,
            isProtected: protection.isProtected,
            protectionReason: protection.reason
        )
    }

    static func topProcesses(limit: Int = 20, sortByCPU: Bool = true) -> [ProcessSnapshot] {
        let snapshots = allPIDs()
            .compactMap { snapshot(for: $0) }
            .filter { ProcessFilter.isUserApplication($0) }
        let sorted = snapshots.sorted {
            if sortByCPU {
                if $0.cpuPercent == $1.cpuPercent { return $0.memoryMB > $1.memoryMB }
                return $0.cpuPercent > $1.cpuPercent
            }
            return $0.memoryMB > $1.memoryMB
        }
        return Array(sorted.filter { $0.name != "unknown" || $0.memoryMB > 0 }.prefix(limit))
    }

    private static func kinfoProc(for pid: Int32) -> kinfo_proc? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
        return info
    }

    private static func taskInfo(for pid: Int32) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let bytes = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        guard bytes == size else { return nil }
        return info
    }

    private static func processName(pid: Int32, kinfo: kinfo_proc?) -> String {
        if let kinfo {
            let name = withUnsafePointer(to: kinfo.kp_proc.p_comm) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) {
                    String(cString: $0)
                }
            }
            if !name.isEmpty, name != "(null)" { return name }
        }

        var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN))
        if proc_name(pid, &nameBuffer, UInt32(nameBuffer.count)) > 0 {
            let name = String(cString: nameBuffer)
            if !name.isEmpty { return name }
        }

        let path = processPath(pid: pid)
        if !path.isEmpty {
            return (path as NSString).lastPathComponent
        }

        return "PID-\(pid)"
    }

    private static func processPath(pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: Int(4 * MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(cString: buffer)
    }

    private static func processUID(pid: Int32, kinfo: kinfo_proc?) -> uid_t {
        if let kinfo { return kinfo.kp_eproc.e_ucred.cr_uid }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let bytes = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard bytes == size else { return getuid() }
        return info.pbi_uid
    }

    private static func processState(kinfo: kinfo_proc?, pid: Int32) -> ProcessState {
        if let kinfo {
            switch Int32(kinfo.kp_proc.p_stat) {
            case Int32(SRUN): return .running
            case Int32(SSLEEP): return .sleeping
            case Int32(SSTOP): return .stopped
            default: break
            }
        }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return .unknown }
        switch info.pbi_status {
        case UInt32(SRUN): return .running
        case UInt32(SSLEEP): return .sleeping
        case UInt32(SSTOP): return .stopped
        default: return .unknown
        }
    }

    private static func cpuPercent(for pid: Int32, info: proc_taskinfo) -> Double {
        let now = Date()
        let currentUser = info.pti_total_user
        let currentSystem = info.pti_total_system

        tickLock.lock()
        defer { tickLock.unlock() }

        guard let previous = previousCPUTicks[pid] else {
            previousCPUTicks[pid] = (currentUser, currentSystem, now)
            return 0
        }

        let elapsed = now.timeIntervalSince(previous.date)
        guard elapsed > 0 else { return 0 }

        let delta = Double(currentUser - previous.user) + Double(currentSystem - previous.system)
        let percent = delta / (elapsed * 1_000_000_000.0) * 100.0 / Double(ProcessInfo.processInfo.activeProcessorCount)
        previousCPUTicks[pid] = (currentUser, currentSystem, now)
        return min(100, max(0, percent))
    }

    private static func protectionStatus(name: String, pid: Int32, uid: uid_t) -> (isProtected: Bool, reason: String?) {
        if pid < SecurityValidator.minimumProtectedPID {
            return (true, "PID de sistema (\(pid))")
        }
        if SecurityValidator.protectedSystemProcesses.contains(name) {
            return (true, "Proceso crítico del sistema")
        }
        if uid == 0 {
            return (true, "Proceso root (UID 0)")
        }
        return (false, nil)
    }
}
