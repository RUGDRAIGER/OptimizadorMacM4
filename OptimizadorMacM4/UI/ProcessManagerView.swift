import SwiftUI

struct ProcessManagerView: View {
    @ObservedObject var service: ProcessManagerService
    @State private var selectedGroupIDs = Set<String>()
    @State private var pendingGroupAction: PendingGroupAction?
    @State private var blockAtLogin = false

    @State private var sortOrder = [KeyPathComparator(\ProcessGroup.totalMemoryMB, order: .reverse)]

    private var sortedGroups: [ProcessGroup] {
        service.filteredGroups.sorted(using: sortOrder)
    }

    private struct PendingGroupAction: Identifiable {
        let group: ProcessGroup
        let kind: ProcessActionKind
        var id: String { "\(group.id)-\(kind.rawValue)" }
    }

    var body: some View {
        PageContainer(title: "Procesos") {
            VStack(spacing: 12) {
                toolbar
                infoBanner
                statusBanner
                groupTable
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .task { await service.refresh() }
        .sheet(item: $pendingGroupAction) { pending in
            groupConfirmationSheet(for: pending)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            TextField("Buscar proceso...", text: $service.searchQuery)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, maxWidth: 280)

            Toggle("Solo background", isOn: $service.showOnlyBackground)
                .toggleStyle(.checkbox)

            Spacer(minLength: 8)

            Button {
                Task { await service.refresh() }
            } label: {
                Label("Actualizar", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                guard let id = selectedGroupIDs.first,
                      let group = sortedGroups.first(where: { $0.id == id }) else { return }
                blockAtLogin = false
                pendingGroupAction = PendingGroupAction(group: group, kind: .terminate)
            } label: {
                Label("Finalizar grupo", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selectedGroupIDs.isEmpty)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var infoBanner: some View {
        Text("Solo apps de usuario y helpers en segundo plano. Procesos del sistema están excluidos. Los grupos unen instancias con el mismo nombre.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let error = service.lastActionError {
            banner(text: error, color: .red)
        } else if let message = service.lastActionMessage {
            banner(text: message, color: .green)
        }
    }

    private var groupTable: some View {
        Table(sortedGroups, selection: $selectedGroupIDs, sortOrder: $sortOrder) {
            TableColumn("Nombre", value: \.name) { group in
                HStack(spacing: 6) {
                    Text(group.name)
                        .lineLimit(1)
                    if service.isBlockedAtLogin(group.name) {
                        Image(systemName: "nosign")
                            .foregroundStyle(.orange)
                            .help("Marcado para no auto-inicio")
                    }
                }
            }
            .width(min: 140, ideal: 180)

            TableColumn("Instancias", value: \.instanceCount) { group in
                Text("\(group.instanceCount)").monospacedDigit()
            }
            .width(min: 70, ideal: 80)

            TableColumn("PIDs", value: \.pidSummary) { group in
                Text(group.pidSummary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 140)

            TableColumn("CPU total", value: \.totalCPUPercent) { group in
                Text(String(format: "%.1f%%", group.totalCPUPercent)).monospacedDigit()
            }
            .width(min: 80, ideal: 90)

            TableColumn("RAM total (MB)", value: \.totalMemoryMB) { group in
                Text(String(format: "%.0f", group.totalMemoryMB)).monospacedDigit()
            }
            .width(min: 100, ideal: 110)

            TableColumn("Acciones") { group in
                ProcessGroupActionButtons(
                    group: group,
                    isRowSelected: selectedGroupIDs.contains(group.id),
                    onTerminate: {
                        blockAtLogin = false
                        pendingGroupAction = PendingGroupAction(group: group, kind: .terminate)
                    },
                    onBoost: {
                        pendingGroupAction = PendingGroupAction(group: group, kind: .boostPriority)
                    }
                )
            }
            .width(min: 220, ideal: 240)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func groupConfirmationSheet(for pending: PendingGroupAction) -> some View {
        let group = pending.group
        let agents = service.launchAgents(for: group)

        VStack(alignment: .leading, spacing: 16) {
            Text(pending.kind == .terminate ? "Finalizar grupo" : "Ajustar prioridad del grupo")
                .font(.title3.bold())

            Text(actionMessage(for: pending))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if pending.kind == .terminate {
                Toggle(isOn: $blockAtLogin) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Evitar auto-inicio al encender")
                            .font(.subheadline.weight(.semibold))
                        Text(blockAtLoginHelp(agents: agents))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }

            HStack {
                Button("Cancelar") {
                    pendingGroupAction = nil
                    blockAtLogin = false
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button(pending.kind == .terminate ? "Finalizar grupo" : "Aplicar", role: pending.kind == .terminate ? .destructive : nil) {
                    let action = pending
                    let block = blockAtLogin
                    pendingGroupAction = nil
                    blockAtLogin = false
                    Task { await execute(action, blockAtLogin: block) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(pending.kind == .terminate ? .red : .accentColor)
            }
        }
        .padding(28)
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func blockAtLoginHelp(agents: [LaunchAgentManager.LaunchAgentInfo]) -> String {
        if agents.isEmpty {
            return "Si no hay Launch Agent, macOS puede reiniciar el helper con su app padre. Se guardará tu preferencia."
        }
        return "Se desactivará el Launch Agent: \(agents.map(\.label).joined(separator: ", "))"
    }

    private func banner(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func actionMessage(for pending: PendingGroupAction) -> String {
        let group = pending.group
        switch pending.kind {
        case .terminate:
            return "Se finalizarán \(group.actionableProcesses.count) instancia(s) de '\(group.name)' (PIDs: \(group.pidSummary)) con SIGTERM → SIGKILL si es necesario."
        case .boostPriority:
            return "Se elevará la prioridad (nice -5) de \(group.actionableProcesses.count) instancia(s) de '\(group.name)'."
        }
    }

    private func execute(_ pending: PendingGroupAction, blockAtLogin: Bool) async {
        switch pending.kind {
        case .terminate:
            await service.terminateGroup(pending.group, blockAtLogin: blockAtLogin)
        case .boostPriority:
            await service.boostGroup(pending.group)
        }
        selectedGroupIDs.removeAll()
    }
}

private struct ProcessGroupActionButtons: View {
    let group: ProcessGroup
    let isRowSelected: Bool
    let onTerminate: () -> Void
    let onBoost: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTerminate) {
                Label("Finalizar (\(group.instanceCount))", systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(isRowSelected ? .red : .red.opacity(0.55))
            .controlSize(.small)
            .disabled(!group.isFullyActionable)

            Button(action: onBoost) {
                Label("Prioridad", systemImage: "arrow.up.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(isRowSelected ? .blue : .blue.opacity(0.55))
            .controlSize(.small)
            .disabled(group.actionableProcesses.isEmpty)
        }
    }
}
