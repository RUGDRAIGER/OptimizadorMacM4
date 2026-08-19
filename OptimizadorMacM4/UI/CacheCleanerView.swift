import SwiftUI

struct CacheCleanerView: View {
    @ObservedObject var service: CacheManagerService
    @State private var selectedEntryIDs = Set<String>()
    @State private var pendingConfirmation: CacheConfirmation?
    @State private var sortOrder = [KeyPathComparator(\CacheEntry.sizeBytes, order: .reverse)]

    private var sortedEntries: [CacheEntry] {
        guard let scan = service.scanResult else { return [] }
        return scan.entries.filter(\.isAllowed).sorted(using: sortOrder)
    }

    var body: some View {
        PageContainer(title: "Limpieza") {
            VStack(spacing: 12) {
                toolbar
                progressBanner
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
                title: "Confirmar limpieza",
                message: cleanMessage(selectedCount: selectedCount, recoverable: recoverable),
                warnings: ["Esta acción no se puede deshacer.", "Solo se borrarán carpetas de caché permitidas."],
                confirmLabel: "Limpiar",
                isDestructive: true,
                onConfirm: {
                    let paths = selectedEntryIDs.isEmpty ? nil : selectedEntryIDs
                    pendingConfirmation = nil
                    Task { await service.performCleanup(selectedPaths: paths) }
                },
                onCancel: {
                    pendingConfirmation = nil
                }
            )
        case .purge:
            ConfirmationSheet(
                title: "Confirmar purge de memoria",
                message: "Se ejecutará /usr/sbin/purge para liberar memoria purgable del sistema. Puede requerir permisos adicionales.",
                warnings: [],
                confirmLabel: "Ejecutar purge",
                isDestructive: false,
                onConfirm: {
                    pendingConfirmation = nil
                    Task { await service.performPurge() }
                },
                onCancel: {
                    pendingConfirmation = nil
                }
            )
        }
    }

    private func cleanMessage(selectedCount: Int, recoverable: String) -> String {
        if selectedCount > 0 {
            return "Se eliminará el contenido de \(selectedCount) carpeta(s) seleccionada(s). Espacio estimado a recuperar: \(recoverable)."
        }
        return "Se eliminará el contenido de todas las carpetas de caché escaneadas. Espacio estimado a recuperar: \(recoverable)."
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await service.performDryRun() }
            } label: {
                Label("Dry Run", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(service.isScanning)

            Button(role: .destructive) {
                guard let scan = service.scanResult else { return }
                let count = selectedEntryIDs.isEmpty ? sortedEntries.count : selectedEntryIDs.count
                pendingConfirmation = .clean(
                    selectedCount: count,
                    recoverable: scan.formattedTotal
                )
            } label: {
                Label("Limpiar seleccionados", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(service.scanResult == nil || service.isCleaning)

            Button {
                pendingConfirmation = .purge
            } label: {
                Label("Purge memoria", systemImage: "memorychip")
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(service.isPurging)

            Spacer(minLength: 8)

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
    private var progressBanner: some View {
        if service.isScanning || service.isCleaning || service.isPurging {
            HStack {
                ProgressView()
                Text(service.isScanning ? "Escaneando..." : service.isCleaning ? "Limpiando..." : "Liberando memoria...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var cacheTable: some View {
        if service.scanResult != nil {
            Table(sortedEntries, selection: $selectedEntryIDs, sortOrder: $sortOrder) {
                TableColumn("Ruta", value: \.path) { entry in
                    Text(entry.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .width(min: 200, ideal: 360)

                TableColumn("Tamaño", value: \.sizeBytes) { entry in
                    Text(entry.formattedSize).monospacedDigit()
                }
                .width(min: 90, ideal: 110)

                TableColumn("Estado", value: \.statusLabel) { entry in
                    Text(entry.statusLabel)
                        .foregroundStyle(entry.isAllowed ? .green : .red)
                        .fontWeight(.medium)
                }
                .width(min: 90, ideal: 100)
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
                systemImage: "externaldrive",
                description: Text("Ejecuta un Dry Run para ver el espacio recuperable.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(height: 100)
        }
    }
}
