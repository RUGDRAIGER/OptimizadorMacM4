import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case monitor = "Monitor"
    case processes = "Procesos"
    case cache = "Limpieza"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .monitor: return "gauge.with.dots.needle.67percent"
        case .processes: return "cpu"
        case .cache: return "trash"
        }
    }
}

struct MainNavigationView: View {
    @StateObject private var monitor = ResourceMonitorService()
    @StateObject private var processManager = ProcessManagerService()
    @StateObject private var cacheManager = CacheManagerService()
    @State private var selection: AppSection = .monitor

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Optimizador M4")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ForEach(AppSection.allCases) { section in
                sidebarRow(section)
            }

            Spacer()

            Text("v0.0.1")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(minWidth: 220, idealWidth: 220, maxWidth: 220)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sidebarRow(_ section: AppSection) -> some View {
        let isSelected = selection == section
        return HStack(spacing: 10) {
            Image(systemName: section.icon)
                .frame(width: 20)
            Text(section.rawValue)
            Spacer()
        }
        .font(.body)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selection = section
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .monitor:
            MonitorDashboardView(monitor: monitor)
        case .processes:
            ProcessManagerView(service: processManager)
        case .cache:
            CacheCleanerView(service: cacheManager)
        }
    }
}
