import SwiftUI

struct PickerSectionHeader: View {
    let title: String
    let badge: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(Theme.Typography.label)
                .foregroundColor(color)
            Text(title)
                .font(Theme.Typography.label)
                .foregroundColor(color)
                .kerning(1.5)
            Spacer()
            Text(badge)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.acTextMuted)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}
