import SwiftUI

struct CacheCleanerView: View {
    @ObservedObject var service: CacheManagerService
    @State private var selectedEntryIDs = Set<String>()
    @State private var pendingConfirmation: CacheConfirmation?
    @State private var sortOrder = [KeyPathComparator(\CacheEntry.sizeBytes, order: .reverse)]
    @State private var showAdvisory = true

    private var sortedEntries: [CacheEntry] {
        guard let scan = service.scanResult else { return [] }
        return scan.entries
            .filter { showAdvisory || $0.isAllowed }
            .sorted(using: sortOrder)
    }

    var body: some View {
        PageContainer(title: "Almacenamiento") {
            VStack(spacing: 12) {
                toolbar
                progressBanner
                if let scan = service.scanResult {
                    diskSummary(scan)
                    categorySummary(scan)
                }
                cacheTable
                logSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .sheet(item: $pendingConfirmation) { confirmation in
            confirmationSheet(for: confirmation)
        }
    }

    @ViewBuilder
    private func confirmationSheet(for confirmation: CacheConfirmation) -> some View {
        switch confirmation {
        case .clean(let selectedCount, let recoverable):
            ConfirmationSheet(
                title: "Confirmar limpieza de disco",
                message: cleanMessage(selectedCount: selectedCount, recoverable: recoverable),
                warnings: [
                    "Esta acción no se puede deshacer.",
                    "Solo se borran cachés y registros permitidos.",
                    "Las entradas marcadas 'Revisar' no se incluyen si limpias todo."
                ],
                confirmLabel: "Limpiar disco",
                isDestructive: true,
                onConfirm: {
                    let paths = selectedEntryIDs.isEmpty ? nil : selectedEntryIDs
                    pendingConfirmation = nil
                    Task { await service.performCleanup(selectedPaths: paths) }
                },
                onCancel: { pendingConfirmation = nil }
            )
        case .purge:
            ConfirmationSheet(
                title: "Purge de memoria RAM",
                message: "Libera RAM purgable, no espacio en disco. Para disco usa 'Limpiar disco'.",
                warnings: ["No borra archivos del disco duro."],
                confirmLabel: "Ejecutar purge RAM",
                isDestructive: false,
                onConfirm: {
                    pendingConfirmation = nil
                    Task { await service.performPurge() }
                },
                onCancel: { pendingConfirmation = nil }
            )
        case .simulators:
            ConfirmationSheet(
                title: "Limpiar simuladores iOS obsoletos",
                message: "Elimina simuladores iOS que ya no están disponibles. No afecta simuladores activos ni Xcode.",
                warnings: ["Seguro para desarrollo. Libera espacio en ~/Library/Developer/CoreSimulator."],
                confirmLabel: "Limpiar simuladores",
                isDestructive: false,
                onConfirm: {
                    pendingConfirmation = nil
                    Task { await service.performSimulatorCleanup() }
                },
                onCancel: { pendingConfirmation = nil }
            )
        }
    }

    private func cleanMessage(selectedCount: Int, recoverable: String) -> String {
        if selectedCount > 0 {
            return "Se eliminará el contenido de \(selectedCount) carpeta(s) seleccionada(s). Espacio estimado: \(recoverable)."
        }
        return "Se limpiarán todas las carpetas marcadas como 'Seguro'. Espacio estimado: \(recoverable)."
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button { Task { await service.performDryRun() } } label: {
                Label("Escanear disco", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(service.isScanning)

            Button(role: .destructive) {
                guard let scan = service.scanResult else { return }
                let selected = selectedEntryIDs.isEmpty
                    ? scan.cleanableEntries.filter { $0.risk == .safe }
                    : scan.entries.filter { selectedEntryIDs.contains($0.path) && $0.isAllowed }
                pendingConfirmation = .clean(
                    selectedCount: selected.count,
                    recoverable: ByteFormatter.string(from: selected.reduce(0) { $0 + $1.sizeBytes })
                )
            } label: {
                Label("Limpiar disco", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(service.scanResult == nil || service.isCleaning)

            Button { pendingConfirmation = .simulators } label: {
                Label("Simuladores", systemImage: "iphone")
            }
            .buttonStyle(.bordered)
            .disabled(service.isCleaningSimulators)

            Button { pendingConfirmation = .purge } label: {
                Label("Purge RAM", systemImage: "memorychip")
            }
            .buttonStyle(.bordered)
            .disabled(service.isPurging)

            Toggle("Info", isOn: $showAdvisory)
                .toggleStyle(.switch)
                .controlSize(.small)

            Spacer(minLength: 4)

            if let scan = service.scanResult {
                Text("Recuperable: \(scan.formattedTotal)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func diskSummary(_ scan: CacheScanResult) -> some View {
        if let volume = scan.volume {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Macintosh HD", systemImage: "internaldrive")
                        .font(.headline)
                    Spacer()
                    Text("\(volume.formattedUsed) usados · \(volume.formattedFree) libres")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: volume.usedPercent, total: 100)
                    .tint(volume.usedPercent > 85 ? .red : .accentColor)
                Text("\(String(format: "%.0f", volume.usedPercent))% del disco en uso")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private func categorySummary(_ scan: CacheScanResult) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(scan.categorySummaries) { summary in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(summary.category.rawValue, systemImage: summary.category.icon)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(summary.formattedTotal)
                            .font(.title3.monospacedDigit())
                    }
                    .padding(10)
                    .frame(minWidth: 130, alignment: .leading)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private var progressBanner: some View {
        if service.isScanning || service.isCleaning || service.isPurging || service.isCleaningSimulators {
            HStack {
                ProgressView()
                Text(bannerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var bannerText: String {
        if service.isScanning { return "Escaneando disco..." }
        if service.isCleaning { return "Limpiando archivos..." }
        if service.isCleaningSimulators { return "Limpiando simuladores..." }
        return "Liberando RAM..."
    }

    @ViewBuilder
    private var cacheTable: some View {
        if service.scanResult != nil {
            Table(sortedEntries, selection: $selectedEntryIDs, sortOrder: $sortOrder) {
                TableColumn("Categoría", value: \.category.rawValue) { entry in
                    Label(entry.category.rawValue, systemImage: entry.category.icon)
                        .font(.caption)
                }
                .width(min: 120, ideal: 140)

                TableColumn("Ruta", value: \.path) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if !entry.note.isEmpty {
                            Text(entry.note)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .width(min: 220, ideal: 360)

                TableColumn("Tamaño", value: \.sizeBytes) { entry in
                    Text(entry.formattedSize).monospacedDigit()
                }
                .width(min: 80, ideal: 100)

                TableColumn("Riesgo", value: \.risk.rawValue) { entry in
                    Text(entry.statusLabel)
                        .foregroundStyle(riskColor(entry.risk))
                        .fontWeight(.medium)
                }
                .width(min: 80, ideal: 90)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        } else {
            ContentUnavailableView(
                "Sin escaneo",
                systemImage: "internaldrive",
                description: Text("Escanea el disco para ver qué espacio puedes recuperar de forma segura.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func riskColor(_ risk: StorageRisk) -> Color {
        switch risk {
        case .safe: return .green
        case .caution: return .orange
        case .blocked: return .red
        case .advisory: return .blue
        }
    }

    private var logSection: some View {
        GroupBox("Log de acciones") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(service.logMessages, id: \.self) { message in
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 90)
        }
    }
}
