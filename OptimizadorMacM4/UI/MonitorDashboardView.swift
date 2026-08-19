import SwiftUI

struct MonitorDashboardView: View {
    @ObservedObject var monitor: ResourceMonitorService

    var body: some View {
        PageContainer(title: "Monitor M4") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    cpuSection
                    memorySection
                    processSection(title: "Top CPU", processes: monitor.topProcessesByCPU)
                    processSection(title: "Top Memoria", processes: monitor.topProcessesByMemory)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .task { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recursos en tiempo real")
                    .font(.headline)
                Text("Actualización cada \(String(format: "%.1f", monitor.pollInterval))s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Actualizar ahora") {
                Task { await monitor.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var cpuSection: some View {
        GroupBox("CPU Apple Silicon") {
            VStack(spacing: 12) {
                UsageBar(
                    label: "Total (\(monitor.cpuMetrics.performanceCoreCount + monitor.cpuMetrics.efficiencyCoreCount) cores)",
                    value: monitor.cpuMetrics.totalUsage
                )
                UsageBar(
                    label: "P-Cores (\(monitor.cpuMetrics.performanceCoreCount))",
                    value: monitor.cpuMetrics.performanceCoresUsage,
                    color: .blue
                )
                UsageBar(
                    label: "E-Cores (\(monitor.cpuMetrics.efficiencyCoreCount))",
                    value: monitor.cpuMetrics.efficiencyCoresUsage,
                    color: .green
                )
            }
            .padding(.vertical, 4)
        }
    }

    private var memorySection: some View {
        GroupBox("Memoria Unificada") {
            VStack(spacing: 12) {
                UsageBar(
                    label: "Uso total (\(ByteFormatter.string(from: monitor.memoryMetrics.totalBytes)))",
                    value: monitor.memoryMetrics.usedPercentage,
                    color: pressureColor
                )
                UsageBar(
                    label: "Active",
                    value: monitor.memoryMetrics.activePercentage,
                    color: .blue
                )
                UsageBar(
                    label: "Wired",
                    value: monitor.memoryMetrics.wiredPercentage,
                    color: .orange
                )
                UsageBar(
                    label: "Compressed",
                    value: monitor.memoryMetrics.compressedPercentage,
                    color: .purple
                )
                UsageBar(
                    label: "Libre",
                    value: monitor.memoryMetrics.freePercentage,
                    color: .green
                )
            }
            .padding(.vertical, 4)
        }
    }

    private var pressureColor: Color {
        switch monitor.memoryMetrics.pressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private func processSection(title: String, processes: [ProcessSnapshot]) -> some View {
        GroupBox(title) {
            if processes.isEmpty {
                Text("Recopilando datos...")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(processes) { process in
                    ProcessRowView(process: process)
                    if process.id != processes.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}
