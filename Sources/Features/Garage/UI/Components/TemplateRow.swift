import SwiftUI

struct TemplateRow: View {
    let template: VehicleTemplate
    let isLocked: Bool
    let isSelected: Bool
    let isHovered: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Icon badge
                ZStack {
                    Circle()
                        .fill(isLocked
                              ? Theme.Colors.acField
                              : Color(hex: template.colorHex).opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: isLocked ? "lock.fill" : template.type.icon)
                        .font(Theme.Typography.body)
                        .foregroundColor(isLocked
                                         ? Theme.Colors.acTextMuted
                                         : Color(hex: template.colorHex))
                }

                // Name + level
                VStack(alignment: .leading, spacing: 1) {
                    Text(template.name)
                        .font(Theme.Typography.caption)
                        .foregroundColor(isLocked ? Theme.Colors.acTextMuted : Theme.Colors.acTextDark)
                        .lineLimit(1)
                    if isLocked {
                        Text("Lv \(template.unlockLevel)")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.acWood.opacity(0.7))
                    }
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.acGold)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered && !isLocked
                          ? Theme.Colors.acGold.opacity(0.12)
                          : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isHovered && !isLocked ? Theme.Colors.acGold : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .opacity(isLocked && !isHovered ? 0.5 : 1.0)
        .animation(.spring(response: 0.2), value: isHovered)
    }
}
