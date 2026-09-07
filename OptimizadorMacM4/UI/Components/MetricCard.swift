import SwiftUI

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    var accent: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(accent)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct UsageBar: View {
    let label: String
    let value: Double
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(String(format: "%.1f%%", value))
                    .monospacedDigit()
            }
            .font(.caption)
            ProgressView(value: min(100, max(0, value)), total: 100)
                .tint(color)
        }
    }
}

struct ProcessRowView: View {
    let process: ProcessSnapshot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .fontWeight(.medium)
                Text("PID \(process.pid) · UID \(process.uid)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f%% CPU", process.cpuPercent))
                    .monospacedDigit()
                Text(String(format: "%.0f MB", process.memoryMB))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
