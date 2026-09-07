import Foundation

enum LaunchAgentManager {
    struct LaunchAgentInfo: Sendable {
        let url: URL
        let label: String
        let isDisabled: Bool
    }

    static func agents(matchingAppPath appPath: String?) -> [LaunchAgentInfo] {
        guard let appPath, !appPath.isEmpty else { return [] }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let agentsDir = URL(fileURLWithPath: "\(home)/Library/LaunchAgents", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: agentsDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "plist" || $0.lastPathComponent.hasSuffix(".plist.disabled") }
            .compactMap { url -> LaunchAgentInfo? in
                guard let data = try? Data(contentsOf: url),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                else { return nil }

                let program = (plist["Program"] as? String) ?? ""
                let args = (plist["ProgramArguments"] as? [String])?.joined(separator: " ") ?? ""
                let combined = program + " " + args
                guard combined.contains(appPath) || combined.contains((appPath as NSString).lastPathComponent) else {
                    return nil
                }

                let label = (plist["Label"] as? String) ?? url.deletingPathExtension().lastPathComponent
                return LaunchAgentInfo(url: url, label: label, isDisabled: url.lastPathComponent.hasSuffix(".disabled"))
            }
    }

    static func disable(_ agent: LaunchAgentInfo) -> String? {
        guard !agent.isDisabled else { return nil }
        let disabledURL = agent.url.deletingPathExtension().appendingPathExtension("plist.disabled")
        do {
            try FileManager.default.moveItem(at: agent.url, to: disabledURL)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static func enable(_ agent: LaunchAgentInfo) -> String? {
        guard agent.isDisabled else { return nil }
        let enabledURL = agent.url.deletingLastPathComponent()
            .appendingPathComponent(agent.url.lastPathComponent.replacingOccurrences(of: ".disabled", with: ""))
        do {
            try FileManager.default.moveItem(at: agent.url, to: enabledURL)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
