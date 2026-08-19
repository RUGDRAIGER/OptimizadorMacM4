import Foundation

enum SecurityValidationError: LocalizedError, Equatable {
    case protectedPID(Int32)
    case rootProcess(name: String, pid: Int32)
    case systemCriticalProcess(name: String)
    case blockedPath(String)
    case requiresConfirmation(String)

    var errorDescription: String? {
        switch self {
        case .protectedPID(let pid):
            return "El proceso PID \(pid) está protegido (PID < 100)."
        case .rootProcess(let name, let pid):
            return "El proceso '\(name)' (PID \(pid)) pertenece a root (UID 0)."
        case .systemCriticalProcess(let name):
            return "El proceso '\(name)' es crítico del sistema."
        case .blockedPath(let path):
            return "Ruta bloqueada por SIP o política de seguridad: \(path)"
        case .requiresConfirmation(let message):
            return message
        }
    }
}

enum SecurityValidator {
    static let protectedSystemProcesses: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow",
        "syslogd", "configd", "powerd", "mds", "mdworker"
    ]

    static let minimumProtectedPID: Int32 = 100

    static func validateProcessAction(_ process: ProcessSnapshot) -> SecurityValidationError? {
        if process.pid < minimumProtectedPID {
            return .protectedPID(process.pid)
        }
        if process.isRoot {
            return .rootProcess(name: process.name, pid: process.pid)
        }
        if protectedSystemProcesses.contains(process.name) {
            return .systemCriticalProcess(name: process.name)
        }
        if process.isProtected {
            return .requiresConfirmation(process.protectionReason ?? "Proceso protegido.")
        }
        return nil
    }

    static func warnings(for process: ProcessSnapshot) -> [String] {
        var warnings: [String] = []
        if process.isRoot {
            warnings.append("Este proceso pertenece a root (UID 0).")
        }
        if process.pid < minimumProtectedPID {
            warnings.append("PID del sistema (\(process.pid)).")
        }
        return warnings
    }
}
