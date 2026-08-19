import SwiftUI

struct PageContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.35))
    }
}

struct SortIndicator: View {
    let isActive: Bool
    let ascending: Bool

    var body: some View {
        Image(systemName: ascending ? "chevron.up" : "chevron.down")
            .font(.caption2.weight(.bold))
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary.opacity(0.4))
    }
}
