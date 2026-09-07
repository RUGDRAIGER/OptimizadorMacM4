import Darwin
import Foundation

enum ProcessTerminator {
    static let defaultTimeout: TimeInterval = 3.0

    enum TerminationResult: Sendable {
        case terminated
        case alreadyGone
        case failed(String)
    }

    static func terminateSafely(pid: Int32, timeout: TimeInterval = defaultTimeout) async -> TerminationResult {
        guard kill(pid, 0) == 0 else { return .alreadyGone }

        if kill(pid, SIGTERM) != 0 {
            return .failed(String(cString: strerror(errno)))
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if kill(pid, 0) != 0 { return .terminated }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        if kill(pid, SIGKILL) != 0 {
            return kill(pid, 0) != 0 ? .terminated : .failed(String(cString: strerror(errno)))
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        return kill(pid, 0) != 0 ? .terminated : .failed("El proceso no respondió a SIGKILL.")
    }
}

enum NiceAdjuster {
    enum NiceResult: Sendable {
        case success(Int32)
        case failed(String)
    }

    static func boostPriority(pid: Int32, niceValue: Int32 = -5) -> NiceResult {
        let result = setpriority(PRIO_PROCESS, id_t(pid), niceValue)
        guard result == 0 else {
            return .failed(String(cString: strerror(errno)))
        }
        return .success(niceValue)
    }

    static func currentNice(pid: Int32) -> Int32? {
        errno = 0
        let value = getpriority(PRIO_PROCESS, id_t(pid))
        guard errno == 0 else { return nil }
        return value
    }
}
