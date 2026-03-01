import SwiftUI
import UIKit

// MARK: - ACSectionHeader

/// Labelled section header with an icon, matching the Animal Crossing wood-tone style.
struct ACSectionHeader: View {
    let title: String
    let icon: String
    var color: Color = Theme.Colors.acWood

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(color)
                .kerning(1.5)
        }
    }
}

// MARK: - ACDialogueBox

/// Animal Crossing style dialogue box with a "beaked" pointer and chunky border.
struct ACDialogueBox<Content: View>: View {
    let content: Content
    var speakerName: String? = nil
    var speakerColor: Color = Theme.Colors.acLeaf

    init(speakerName: String? = nil, speakerColor: Color = Theme.Colors.acLeaf, @ViewBuilder content: () -> Content) {
        self.speakerName = speakerName
        self.speakerColor = speakerColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: -12) {
            if let name = speakerName {
                Text(name.uppercased())
                    .font(Theme.Typography.label)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(speakerColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))
                    .shadow(color: Theme.Colors.acBorder.opacity(0.5), radius: 0, x: 0, y: 3)
                    .padding(.leading, 20)
                    .zIndex(1)
            }

            content
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        Theme.Colors.acCream
                        ACTextureOverlay()
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 3))
                .shadow(color: Theme.Colors.acBorder.opacity(0.5), radius: 0, x: 0, y: 6)
        }
    }
}

// MARK: - ACSnapshotEffect

/// Full-screen white flash with a camera shutter sound (simulated by haptics).
struct ACSnapshotEffect: View {
    @Binding var isTriggered: Bool
    
    var body: some View {
        Color.white
            .opacity(isTriggered ? 1.0 : 0.0)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.1), value: isTriggered)
            .onChange(of: isTriggered) { _, newValue in
                if newValue {
                    // Quick flash out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isTriggered = false
                    }
                }
            }
    }
}

// MARK: - RoutineToken

struct RoutineToken: View {
    let category: RoutineCategory
    let index: Int
    let route: SavedRoute?
    var isPredicted: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // Depth slab
                    Circle()
                        .fill(Theme.Colors.acBorder.opacity(0.8))
                        .offset(y: 4)
                    
                    // Main face
                    Circle()
                        .fill(faceColor)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 2)
                        )
                    
                    // Content
                    if let route = route {
                        if category == .partyMember, let _ = route.contactIdentifier {
                            // Contact Photo placeholder (Ideally would fetch from CNContact)
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(8)
                        } else {
                            Image(systemName: customIcon ?? category.icon)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(Theme.Colors.acBorder.opacity(0.5))
                    }
                }
                .frame(width: 64, height: 64)
                .acWobble(isPressed: false)
                .overlay(
                    Group {
                        if isPredicted {
                            Circle()
                                .stroke(Theme.Colors.acGold, lineWidth: 3)
                                .scaleEffect(1.2)
                                .opacity(0.6)
                        }
                    }
                )
                
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(1)
                    .frame(width: 70)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var faceColor: Color {
        if route == nil { return Theme.Colors.acField }
        switch category {
        case .home: return Theme.Colors.acLeaf
        case .work: return Theme.Colors.acWood
        case .gym: return Theme.Colors.acSky
        case .partyMember: return Theme.Colors.acCoral
        case .holySpot: return Theme.Colors.acGold
        case .dayCare: return Theme.Colors.acMint
        case .school: return Theme.Colors.acSky
        case .afterSchool: return Theme.Colors.acCoral
        case .dateSpot: return Theme.Colors.acCoral
        }
    }
    
    private var label: String {
        if let route = route {
            return route.destinationName
        }
        return "\(category.displayName) \(index + 1)"
    }
    
    private var customIcon: String? {
        route?.customIcon
    }
}

// MARK: - View Extension

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - ACTextField

/// Labelled text field with AC card styling.
struct ACTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextDark)

            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextDark)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Theme.Colors.acCream)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acBorder, lineWidth: 2))
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            hideKeyboard()
                        }
                        .font(.body.bold())
                        .foregroundColor(Theme.Colors.acWood)
                    }
                }
        }
    }
}

// MARK: - ACToggleRow

/// Full-width toggle row with an icon and green tint.
struct ACToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Theme.Colors.acWood)
                    .frame(width: 24)
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextDark)
            }
        }
        .tint(Theme.Colors.acLeaf)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - ACSectionDivider

/// Inset divider matching the AC border opacity style.
struct ACSectionDivider: View {
    var leadingInset: CGFloat = 40

    var body: some View {
        Divider()
            .background(Theme.Colors.acBorder.opacity(0.3))
            .padding(.leading, leadingInset)
    }
}

// MARK: - ACDangerButton

/// Coral-outline capsule button for destructive / end actions.
struct ACDangerButton: View {
    let title: String
    var icon: String? = nil
    var isFullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(Theme.Typography.button)
                }
                Text(title).font(Theme.Typography.button)
            }
            .foregroundColor(Theme.Colors.acCoral)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, 12)
            .padding(.horizontal, isFullWidth ? 0 : 24)
            .background(Theme.Colors.acCream)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.Colors.acCoral, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ACPillButton

/// Neutral pill button (Find a Place, etc.).
struct ACPillButton: View {
    let title: String
    var icon: String? = nil
    var color: Color = Theme.Colors.acTextDark
    var isFullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title).font(Theme.Typography.button)
            }
            .foregroundColor(color)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, 12)
            .padding(.horizontal, isFullWidth ? 0 : 20)
            .background(Theme.Colors.acCream)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.Colors.acBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ACBadge

/// Capsule badge with optional leading icon.
struct ACBadge: View {
    let text: String
    var textColor: Color = Theme.Colors.acCream
    var backgroundColor: Color = Theme.Colors.acLeaf
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
            }
            Text(text)
                .font(Theme.Typography.label)
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(backgroundColor)
        .clipShape(Capsule())
    }
}

// MARK: - ACStatBar

/// Horizontal stat bar with label and colored fill.
struct ACStatBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.acTextMuted)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.acBorder.opacity(0.3))
                        .frame(height: 8)

                    Capsule()
                        .fill(color)
                        .frame(width: max(0, min(geo.size.width * (value / 10.0), geo.size.width)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - ACStatBox

/// Card-style stat box showing an optional icon, a value, and a label.
struct ACStatBox: View {
    let title: String
    let value: String
    var icon: String? = nil
    var iconColor: Color = Theme.Colors.acLeaf
    var padding: CGFloat = 16

    var body: some View {
        VStack(spacing: icon != nil ? 8 : 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.acTextDark)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.acTextMuted)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .acCardStyle(padding: padding)
    }
}

// MARK: - ACMetricsColumn

/// Single-column metric display used in navigation HUD (value + unit label).
struct ACMetricsColumn: View {
    let value: String
    let label: String
    var fontSize: CGFloat = 40

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundColor(Theme.Colors.acTextDark)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ACMapRoundButton

/// Circular map-overlay button with active/inactive state.
struct ACMapRoundButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isActive ? Theme.Colors.acLeaf : Theme.Colors.acTextDark)
                .frame(width: 52, height: 52)
                .background(isActive ? Theme.Colors.acLeaf.opacity(0.12) : Theme.Colors.acCream)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        isActive ? Theme.Colors.acLeaf : Theme.Colors.acBorder,
                        lineWidth: isActive ? 2.5 : 2
                    )
                )
                .shadow(color: Theme.Colors.acBorder.opacity(0.8), radius: 0, x: 0, y: 4)
                .bunnyPaw()
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
        .accessibilityLabel(label)
        .contentShape(Circle())
    }
}

// MARK: - ACBunnyPawEffect

/// Scale-bounce + soft haptic on tap — opt-in Bunny Police theme interaction.
struct ACBunnyPawEffect: ViewModifier {
    @State private var popped = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(popped ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: popped)
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                popped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { popped = false }
            }
    }
}

extension View {
    func bunnyPaw() -> some View { modifier(ACBunnyPawEffect()) }
}
