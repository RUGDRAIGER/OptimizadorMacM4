import Foundation

@MainActor
final class ProcessManagerService: ObservableObject {
    @Published private(set) var userProcesses: [ProcessSnapshot] = []
    @Published private(set) var backgroundCandidates: [ProcessSnapshot] = []
    @Published private(set) var lastActionMessage: String?
    @Published private(set) var lastActionError: String?
    @Published var searchQuery = ""
    @Published var showOnlyBackground = true

    private let blockedAtLoginKey = "blockedProcessGroupNames"

    var filteredProcesses: [ProcessSnapshot] {
        let base = showOnlyBackground ? backgroundCandidates : userProcesses
        return base.filter { ProcessFilter.matchesSearch($0, query: searchQuery) }
    }

    var filteredGroups: [ProcessGroup] {
        ProcessGroup.grouped(from: filteredProcesses)
            .filter { ProcessFilter.matchesSearch($0, query: searchQuery) }
    }

    func refresh() async {
        let processes = await Task.detached(priority: .utility) {
            ProcessEnumerator.allPIDs().compactMap { ProcessEnumerator.snapshot(for: $0) }
        }.value

        userProcesses = ProcessFilter.filterUserApplications(processes)
            .sorted { $0.memoryMB > $1.memoryMB }
        backgroundCandidates = ProcessFilter.filterBackgroundCandidates(processes)
            .sorted { $0.memoryMB > $1.memoryMB }
    }

    func launchAgents(for group: ProcessGroup) -> [LaunchAgentManager.LaunchAgentInfo] {
        LaunchAgentManager.agents(matchingAppPath: group.appBundlePath)
    }

    func terminateGroup(_ group: ProcessGroup, blockAtLogin: Bool) async {
        lastActionMessage = nil
        lastActionError = nil

        let targets = group.actionableProcesses
        guard !targets.isEmpty else {
            lastActionError = "No hay instancias accionables en '\(group.name)'."
            return
        }

        var terminated = 0
        var errors: [String] = []

        for process in targets {
            if let validation = SecurityValidator.validateProcessAction(process) {
                errors.append(validation.localizedDescription ?? "Error de validación")
                continue
            }
            switch await ProcessTerminator.terminateSafely(pid: process.pid) {
            case .terminated, .alreadyGone:
                terminated += 1
            case .failed(let message):
                errors.append("\(process.pid): \(message)")
            }
        }

        if blockAtLogin {
            let agents = launchAgents(for: group)
            if agents.isEmpty {
                saveBlockedAtLogin(group.name)
                errors.append("No se encontró Launch Agent. Se guardó preferencia; el helper puede reiniciarse con su app padre.")
            } else {
                for agent in agents where !agent.isDisabled {
                    if let err = LaunchAgentManager.disable(agent) {
                        errors.append("Launch Agent: \(err)")
                    }
                }
                saveBlockedAtLogin(group.name)
            }
        }

        if terminated > 0 {
            lastActionMessage = "Finalizadas \(terminated) instancia(s) de '\(group.name)'."
            if blockAtLogin {
                lastActionMessage? += " Preferencia de no auto-inicio guardada."
            }
        }
        if !errors.isEmpty {
            lastActionError = errors.joined(separator: " ")
        }
        await refresh()
    }

    func boostGroup(_ group: ProcessGroup) async {
        lastActionMessage = nil
        lastActionError = nil

        var boosted = 0
        for process in group.actionableProcesses {
            switch NiceAdjuster.boostPriority(pid: process.pid) {
            case .success:
                boosted += 1
            case .failed(let message):
                lastActionError = message
            }
        }
        if boosted > 0 {
            lastActionMessage = "Prioridad elevada en \(boosted) instancia(s) de '\(group.name)'."
        }
        await refresh()
    }

    func isBlockedAtLogin(_ name: String) -> Bool {
        blockedAtLoginNames.contains(name)
    }

    private var blockedAtLoginNames: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: blockedAtLoginKey) ?? [])
    }

    private func saveBlockedAtLogin(_ name: String) {
        var set = blockedAtLoginNames
        set.insert(name)
        UserDefaults.standard.set(Array(set), forKey: blockedAtLoginKey)
    }
}
