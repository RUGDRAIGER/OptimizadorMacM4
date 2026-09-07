import Foundation

enum ProcessFilter {
    static let backgroundKeywords: [String] = [
        "Helper", "Renderer", "GPU", "Plugin", "Agent", "Service", "Extension"
    ]

    static let devAppWhitelist: Set<String> = [
        "Cursor", "Xcode", "Code", "Terminal", "iTerm2", "OptimizadorMacM4"
    ]

    static let systemProcessNames: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow", "syslogd", "configd",
        "powerd", "mds", "mdworker", "mdworker_shared", "cfprefsd", "distnoted",
        "trustd", "secd", "securityd", "coreaudiod", "airportd", "mDNSResponder",
        "symptomsd", "opendirectoryd", "timed", "usbmuxd", "locationd", "sharingd",
        "bird", "cloudd", "fileproviderd", "nsurlsessiond", "rapportd", "biometrickitd",
        "backgroundtaskmanagementagent", "deleted", "logd", "fseventsd", "diskarbitrationd",
        "notifyd", "coreservicesd", "tccd", "sandboxd", "runningboardd", "dasd",
        "coreduetd", "apsd", "networkserviceproxy", "wifip2pd", "bluetoothd"
    ]

    static let systemPathPrefixes: [String] = [
        "/System/", "/usr/", "/bin/", "/sbin/", "/var/", "/Library/Apple/",
        "/private/var/", "/private/etc/", "/opt/"
    ]

    static func isUserApplication(_ process: ProcessSnapshot) -> Bool {
        if process.pid < SecurityValidator.minimumProtectedPID { return false }
        if process.uid == 0 { return false }
        if systemProcessNames.contains(process.name) { return false }
        if process.name.hasPrefix("com.apple.") { return false }

        let path = process.path
        if path.isEmpty {
            return process.uid == getuid()
        }

        if systemPathPrefixes.contains(where: { path.hasPrefix($0) }) { return false }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let isUserApp = path.contains("/Applications/")
            || path.hasPrefix("\(home)/Applications/")
            || path.hasPrefix("\(home)/Library/")
            || path.hasPrefix(home + "/")

        return isUserApp && process.uid == getuid()
    }

    static func isBackgroundCandidate(name: String, path: String) -> Bool {
        if devAppWhitelist.contains(where: { name.contains($0) }) { return false }
        return backgroundKeywords.contains { keyword in
            name.localizedCaseInsensitiveContains(keyword)
                || path.localizedCaseInsensitiveContains(keyword)
        }
    }

    static func filterUserApplications(_ processes: [ProcessSnapshot]) -> [ProcessSnapshot] {
        processes.filter(isUserApplication)
    }

    static func filterBackgroundCandidates(_ processes: [ProcessSnapshot]) -> [ProcessSnapshot] {
        filterUserApplications(processes).filter { $0.isBackgroundCandidate && !$0.isProtected }
    }

    static func matchesSearch(_ process: ProcessSnapshot, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return process.name.lowercased().contains(q)
            || process.path.lowercased().contains(q)
            || String(process.pid).contains(q)
    }

    static func matchesSearch(_ group: ProcessGroup, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let q = query.lowercased()
        return group.name.lowercased().contains(q)
            || group.pids.contains { String($0).contains(q) }
            || group.processes.contains { $0.path.lowercased().contains(q) }
    }
}
