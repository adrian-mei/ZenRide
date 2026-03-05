import SwiftUI

// MARK: - VehicleGarageView (Mario Kart Picker)

struct VehicleGarageView: View {
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var playerStore: PlayerStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = VehicleGarageViewModel()
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
                            badge: "\(vm.freeTemplates.count) rides",
                            icon: "checkmark.circle.fill",
                            color: Theme.Colors.acLeaf
                        )

                        VStack(spacing: 6) {
                            ForEach(vm.freeTemplates) { template in
                                TemplateRow(
                                    template: template,
                                    isLocked: false,
                                    isSelected: vehicleStore.selectedTemplateId == template.id,
                                    isHovered: vm.hoveredId == template.id,
                                    onTap: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                            vm.hoveredId = template.id
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
                            ForEach(vm.lockedTemplates) { template in
                                let isLocked = template.unlockLevel > playerStore.currentLevel
                                TemplateRow(
                                    template: template,
                                    isLocked: isLocked,
                                    isSelected: vehicleStore.selectedTemplateId == template.id,
                                    isHovered: vm.hoveredId == template.id,
                                    onTap: {
                                        if !isLocked {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                                vm.hoveredId = template.id
                                            }
                                            UISelectionFeedbackGenerator().selectionChanged()
                                        } else {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                                vm.hoveredId = template.id
                                            }
                                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 16)

                        // ── LEGENDARY section ───────────────────────────────
                        if !vm.legendaryTemplates.isEmpty {
                            PickerSectionHeader(
                                title: "LEGENDARY",
                                badge: "master XP",
                                icon: "sparkles",
                                color: Theme.Colors.acGold
                            )

                            VStack(spacing: 6) {
                                ForEach(vm.legendaryTemplates) { template in
                                    let isLocked = template.unlockLevel > playerStore.currentLevel
                                    TemplateRow(
                                        template: template,
                                        isLocked: isLocked,
                                        isSelected: vehicleStore.selectedTemplateId == template.id,
                                        isHovered: vm.hoveredId == template.id,
                                        onTap: {
                                            if !isLocked {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                                    vm.hoveredId = template.id
                                                }
                                                UISelectionFeedbackGenerator().selectionChanged()
                                            } else {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                                    vm.hoveredId = template.id
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
                        Image(systemName: vm.hoveredTemplate.type.icon)
                            .font(Theme.Typography.display)
                            .foregroundColor(Color(hex: vm.hoveredTemplate.colorHex))
                    }
                    .id(vm.hoveredId)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .scale(scale: 1.4).combined(with: .opacity)
                    ))
                    .padding(.bottom, 14)

                    // Name slides in/out
                    Text(vm.hoveredTemplate.name)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)
                        .id(vm.hoveredId + "_name")
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))

                    // FREE badge or type label
                    HStack(spacing: 6) {
                        Text(vm.hoveredTemplate.type.displayName)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.acTextMuted)

                        if vm.hoveredTemplate.unlockLevel == 1 {
                            Text("FREE")
                                .font(Theme.Typography.label)
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
                    .id(vm.hoveredId + "_type")
                    .transition(.opacity)
                    .padding(.bottom, 18)

                    // Stats — bars animate to new values
                    VStack(spacing: 10) {
                        StatRow(label: "Speed", value: vm.hoveredTemplate.speedStat, color: Theme.Colors.acSky)
                        StatRow(label: "Handling", value: vm.hoveredTemplate.handlingStat, color: Theme.Colors.acGold)
                        StatRow(label: "Safety", value: vm.hoveredTemplate.safetyStat, color: Theme.Colors.acCoral)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // Lock progress — shown only when hovering a locked template
                    let isLocked = vm.hoveredTemplate.unlockLevel > playerStore.currentLevel
                    if isLocked {
                        let levelsNeeded = vm.hoveredTemplate.unlockLevel - playerStore.currentLevel
                        VStack(spacing: 6) {
                            HStack {
                                Text("Your Progress")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.acTextMuted)
                                Spacer()
                                Text("Lv \(playerStore.currentLevel) → \(vm.hoveredTemplate.unlockLevel)")
                                    .font(Theme.Typography.caption)
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
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.acTextMuted)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Select button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        vehicleStore.setTemplate(id: vm.hoveredId)
                        dismiss()
                    } label: {
                        Text(isLocked ? "Locked · Level \(vm.hoveredTemplate.unlockLevel)" : "Select")
                            .font(Theme.Typography.button)
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
            vm.hoveredId = vehicleStore.selectedTemplateId
        }
    }
}

// MARK: - PickerSectionHeader

