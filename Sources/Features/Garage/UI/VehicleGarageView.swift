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

    private var freeTemplates: [VehicleTemplate] {
        VehicleTemplate.all.filter { $0.unlockLevel == 1 }
    }
    private var lockedTemplates: [VehicleTemplate] {
        VehicleTemplate.all.filter { $0.unlockLevel > 1 }
    }

    var body: some View {
        ZStack {
            Theme.Colors.acCream.ignoresSafeArea()

            HStack(spacing: 0) {
                // MARK: Left panel — sectioned template list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── FREE section ─────────────────────────────────
                        PickerSectionHeader(
                            title: "FREE",
                            badge: "\(freeTemplates.count) rides",
                            icon: "checkmark.circle.fill",
                            color: Theme.Colors.acLeaf
                        )

                        VStack(spacing: 6) {
                            ForEach(freeTemplates) { template in
                                TemplateRow(
                                    template: template,
                                    isLocked: false,
                                    isSelected: vehicleStore.selectedTemplateId == template.id,
                                    isHovered: hoveredId == template.id,
                                    onTap: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                            hoveredId = template.id
                                        }
                                        UISelectionFeedbackGenerator().selectionChanged()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 4)

                        // ── UNLOCK section ───────────────────────────────
                        PickerSectionHeader(
                            title: "UNLOCK",
                            badge: "earn XP",
                            icon: "lock.fill",
                            color: Theme.Colors.acWood
                        )

                        VStack(spacing: 6) {
                            ForEach(lockedTemplates) { template in
                                let isLocked = template.unlockLevel > playerStore.currentLevel
                                TemplateRow(
                                    template: template,
                                    isLocked: isLocked,
                                    isSelected: vehicleStore.selectedTemplateId == template.id,
                                    isHovered: hoveredId == template.id,
                                    onTap: {
                                        if !isLocked {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                                hoveredId = template.id
                                            }
                                            UISelectionFeedbackGenerator().selectionChanged()
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                                hoveredId = template.id
                                            }
                                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 16)
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.4)
                .background(Theme.Colors.acField)

                // MARK: Right panel — preview + stats + select
                VStack(spacing: 0) {
                    Spacer()

                    // Pedestal — pops in when template changes
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.acField)
                            .frame(width: 130, height: 130)
                        Image(systemName: hoveredTemplate.type.icon)
                            .font(.system(size: 66, weight: .bold))
                            .foregroundColor(Color(hex: hoveredTemplate.colorHex))
                    }
                    .id(hoveredId)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 1.4).combined(with: .opacity)
                    ))
                    .padding(.bottom, 14)

                    // Name slides in/out
                    Text(hoveredTemplate.name)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextDark)
                        .id(hoveredId + "_name")
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))

                    // FREE badge or type label
                    HStack(spacing: 6) {
                        Text(hoveredTemplate.type.displayName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextMuted)

                        if hoveredTemplate.unlockLevel == 1 {
                            Text("FREE")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .kerning(1.2)
                                .foregroundColor(Theme.Colors.acLeaf)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.Colors.acLeaf.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Theme.Colors.acLeaf.opacity(0.35), lineWidth: 1))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .id(hoveredId + "_type")
                    .transition(.opacity)
                    .padding(.bottom, 18)

                    // Stats — bars animate to new values
                    VStack(spacing: 10) {
                        StatRow(label: "Speed",    value: hoveredTemplate.speedStat,    color: Theme.Colors.acSky)
                        StatRow(label: "Handling", value: hoveredTemplate.handlingStat, color: Theme.Colors.acGold)
                        StatRow(label: "Safety",   value: hoveredTemplate.safetyStat,   color: Theme.Colors.acCoral)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // Lock progress — shown only when hovering a locked template
                    let isLocked = hoveredTemplate.unlockLevel > playerStore.currentLevel
                    if isLocked {
                        let levelsNeeded = hoveredTemplate.unlockLevel - playerStore.currentLevel
                        VStack(spacing: 6) {
                            HStack {
                                Text("Your Progress")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.Colors.acTextMuted)
                                Spacer()
                                Text("Lv \(playerStore.currentLevel) → \(hoveredTemplate.unlockLevel)")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.Colors.acTextMuted)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.Colors.acField)
                                    Capsule()
                                        .fill(Theme.Colors.acGold.opacity(0.7))
                                        .frame(width: geo.size.width * playerStore.currentLevelProgress())
                                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: playerStore.currentLevelProgress())
                                }
                            }
                            .frame(height: 8)
                            Text(levelsNeeded == 1 ? "1 more level to unlock" : "\(levelsNeeded) levels to unlock")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.Colors.acTextMuted)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Select button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        vehicleStore.setTemplate(id: hoveredId)
                        dismiss()
                    } label: {
                        Text(isLocked ? "Locked · Level \(hoveredTemplate.unlockLevel)" : "Select")
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

// MARK: - PickerSectionHeader

private struct PickerSectionHeader: View {
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

// MARK: - TemplateRow

private struct TemplateRow: View {
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
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(isLocked
                                         ? Theme.Colors.acTextMuted
                                         : Color(hex: template.colorHex))
                }

                // Name + level
                VStack(alignment: .leading, spacing: 1) {
                    Text(template.name)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(isLocked ? Theme.Colors.acTextMuted : Theme.Colors.acTextDark)
                        .lineLimit(1)
                    if isLocked {
                        Text("Lv \(template.unlockLevel)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(Theme.Colors.acWood.opacity(0.7))
                    }
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
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
