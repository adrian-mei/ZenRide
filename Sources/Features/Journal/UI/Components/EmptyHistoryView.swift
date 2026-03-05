import SwiftUI

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed.fill")
                .font(Theme.Typography.display)
                .foregroundColor(Theme.Colors.acWood.opacity(0.5))

            Text("Your Journal is empty.")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.acTextDark)

            Text("Take your first road trip to start collecting stamps and memories!")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
