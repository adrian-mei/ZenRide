import SwiftUI

struct PickerSectionHeader: View {
    let title: String
    let badge: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(color)
                .kerning(1.5)
            Spacer()
            Text(badge)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}
