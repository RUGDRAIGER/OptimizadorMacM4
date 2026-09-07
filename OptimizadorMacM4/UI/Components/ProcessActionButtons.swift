import SwiftUI

struct ProcessActionButtons: View {
    let process: ProcessSnapshot
    let isRowSelected: Bool
    let onTerminate: () -> Void
    let onBoost: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTerminate) {
                Label("Finalizar", systemImage: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(isRowSelected ? Color.red : Color.red.opacity(0.55))
            .controlSize(.small)
            .disabled(process.isProtected)
            .help("Finalizar \(process.name)")

            Button(action: onBoost) {
                Label("Prioridad", systemImage: "arrow.up.circle.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(isRowSelected ? Color.blue : Color.blue.opacity(0.55))
            .controlSize(.small)
            .disabled(process.isProtected)
            .help("Elevar prioridad de \(process.name)")
        }
        .padding(.vertical, 2)
    }
}
