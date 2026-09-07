import Foundation

struct ProcessGroup: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let processes: [ProcessSnapshot]

    var instanceCount: Int { processes.count }

    var totalCPUPercent: Double {
        processes.reduce(0) { $0 + $1.cpuPercent }
    }

    var totalMemoryMB: Double {
        processes.reduce(0) { $0 + $1.memoryMB }
    }

    var pids: [Int32] {
        processes.map(\.pid).sorted()
    }

    var pidSummary: String {
        if pids.count <= 3 {
            return pids.map(String.init).joined(separator: ", ")
        }
        let first = pids.prefix(2).map(String.init).joined(separator: ", ")
        return "\(first)… (+\(pids.count - 2))"
    }

    var appBundlePath: String? {
        for path in processes.map(\.path) where path.contains(".app") {
            if let range = path.range(of: ".app") {
                return String(path[..<range.upperBound])
            }
        }
        return nil
    }

    var actionableProcesses: [ProcessSnapshot] {
        processes.filter { SecurityValidator.validateProcessAction($0) == nil }
    }

    var isFullyActionable: Bool {
        !actionableProcesses.isEmpty && actionableProcesses.count == processes.count
    }

    static func grouped(from processes: [ProcessSnapshot]) -> [ProcessGroup] {
        Dictionary(grouping: processes, by: \.name)
            .map { ProcessGroup(id: $0.key, name: $0.key, processes: $0.value) }
            .sorted { $0.totalMemoryMB > $1.totalMemoryMB }
    }
}

struct ProcessGroupActionRequest: Identifiable, Sendable {
    let group: ProcessGroup
    let kind: ProcessActionKind
    let blockAtLogin: Bool

    var id: String { "\(group.id)-\(kind.rawValue)-\(blockAtLogin)" }
}
