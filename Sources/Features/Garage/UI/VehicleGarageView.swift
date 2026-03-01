import SwiftUI

// MARK: - VehicleGarageView (Mario Kart Picker)

struct VehicleGarageView: View {
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var playerStore: PlayerStore
    @Environment(\.dismiss) private var dismiss

    @State private var hoveredId: String

    init() {
        _hoveredId = State(initialValue: "classic_sedan")
    }

    private var hoveredTemplate: VehicleTemplate {
        VehicleTemplate.all.first { $0.id == hoveredId } ?? VehicleTemplate.all[0]
    }

    var body: some View {
        ZStack {
            Theme.Colors.acCream.ignoresSafeArea()

            HStack(spacing: 0) {
                // MARK: Left panel — template list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(VehicleTemplate.all) { template in
                            let isLocked = template.unlockLevel > playerStore.currentLevel
                            let isSelected = vehicleStore.selectedTemplateId == template.id
                            let isHovered = hoveredId == template.id

                            Button {
                                if !isLocked {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                        hoveredId = template.id
                                    }
                                    UISelectionFeedbackGenerator().selectionChanged()
                                } else {
                                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(isLocked
                                                  ? Theme.Colors.acField
                                                  : Color(hex: template.colorHex).opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: isLocked ? "lock.fill" : template.type.icon)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(isLocked
                                                             ? Theme.Colors.acTextMuted
                                                             : Color(hex: template.colorHex))
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(template.name)
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(isLocked
                                                             ? Theme.Colors.acTextMuted
                                                             : Theme.Colors.acTextDark)
                                            .lineLimit(1)
                                        if isLocked {
                                            Text("Level \(template.unlockLevel)")
                                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                                .foregroundColor(Theme.Colors.acTextMuted)
                                        }
                                    }

                                    Spacer(minLength: 0)

                                    if isSelected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.Colors.acGold)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(isHovered && !isLocked
                                              ? Theme.Colors.acGold.opacity(0.12)
                                              : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            isHovered && !isLocked
                                                ? Theme.Colors.acGold
                                                : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                                .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)
                            }
                            .buttonStyle(.plain)
                            .opacity(isLocked ? 0.5 : 1.0)
                        }
                    }
                    .padding(12)
                }
                .frame(width: UIScreen.main.bounds.width * 0.4)
                .background(Theme.Colors.acField)

                // MARK: Right panel — preview + stats + select
                VStack(spacing: 0) {
                    Spacer()

                    // Pedestal preview — pops in when template changes
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.acField)
                            .frame(width: 140, height: 140)
                        Image(systemName: hoveredTemplate.type.icon)
                            .font(.system(size: 72, weight: .bold))
                            .foregroundColor(Color(hex: hoveredTemplate.colorHex))
                    }
                    .id(hoveredId)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 1.4).combined(with: .opacity)
                    ))
                    .padding(.bottom, 16)

                    // Name slides up/down between templates
                    Text(hoveredTemplate.name)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextDark)
                        .id(hoveredId + "_name")
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))

                    Text(hoveredTemplate.type.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .padding(.bottom, 20)
                        .id(hoveredId + "_type")
                        .transition(.opacity)

                    // Stats — bars animate to new values
                    VStack(spacing: 10) {
                        StatRow(label: "Speed",    value: hoveredTemplate.speedStat,    color: Theme.Colors.acSky)
                        StatRow(label: "Handling", value: hoveredTemplate.handlingStat, color: Theme.Colors.acGold)
                        StatRow(label: "Safety",   value: hoveredTemplate.safetyStat,   color: Theme.Colors.acCoral)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    // Select button
                    let isLocked = hoveredTemplate.unlockLevel > playerStore.currentLevel
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        vehicleStore.setTemplate(id: hoveredId)
                        dismiss()
                    } label: {
                        Text(isLocked ? "Locked (Level \(hoveredTemplate.unlockLevel))" : "Select")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isLocked ? Theme.Colors.acField : Theme.Colors.acLeaf)
                            .foregroundColor(isLocked ? Theme.Colors.acTextMuted : .white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(isLocked ? Theme.Colors.acBorder : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .disabled(isLocked)
                    .padding(.horizontal, 20)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isLocked)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Theme.Colors.acCream)
            }
        }
        .onAppear {
            hoveredId = vehicleStore.selectedTemplateId
        }
    }
}

// MARK: - StatRow

private struct StatRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
                .frame(width: 54, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.acField)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * (value / 10.0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: value)
                }
            }
            .frame(height: 10)

            Text(String(format: "%.0f", value))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(Theme.Colors.acTextDark)
                .frame(width: 18, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: value)
        }
    }
}
