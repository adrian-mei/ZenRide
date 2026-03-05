import SwiftUI

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(Theme.Typography.button)
            }

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(Theme.Typography.button)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}
