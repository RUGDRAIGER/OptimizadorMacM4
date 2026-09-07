import Foundation

enum ProcessState: String, Codable, Sendable, Comparable {
    case running
    case sleeping
    case stopped
    case unknown

    static func < (lhs: ProcessState, rhs: ProcessState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct ProcessSnapshot: Identifiable, Codable, Sendable, Hashable {
    let id: Int32
    let name: String
    let uid: uid_t
    let cpuPercent: Double
    let memoryMB: Double
    let state: ProcessState
    let path: String
    let isBackgroundCandidate: Bool
    let isProtected: Bool
    let protectionReason: String?

    var pid: Int32 { id }

    var isRoot: Bool { uid == 0 }
}

enum ProcessActionKind: String, Sendable {
    case terminate
    case boostPriority
}

struct ProcessActionRequest: Identifiable, Sendable {
    let process: ProcessSnapshot
    let kind: ProcessActionKind

    var id: String { "\(process.pid)-\(kind.rawValue)" }
}
