import SwiftUI

struct ConfirmationSheet: View {
    let title: String
    let message: String
    let warnings: [String]
    let confirmLabel: String
    let isDestructive: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())

            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !warnings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Advertencias de seguridad", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline.bold())
                    ForEach(warnings, id: \.self) { warning in
                        Text("• \(warning)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Button("Cancelar", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(confirmLabel, role: isDestructive ? .destructive : nil, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(isDestructive ? .red : .accentColor)
            }
        }
        .padding(28)
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
