import SwiftUI

struct GuidanceView: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider

    @State private var currentInstructionIndex: Int = 0
    @State private var isApproachingTurn = false
    private let haptic500 = UINotificationFeedbackGenerator()
    private let haptic100 = UIImpactFeedbackGenerator(style: .heavy)

    // A nice thematic color for the top banner
    private let bannerColor = Theme.Colors.acLeaf

    var body: some View {
        VStack(spacing: 0) {
            if !routingService.instructions.isEmpty, currentInstructionIndex < routingService.instructions.count {
                let instruction = routingService.instructions[currentInstructionIndex]

                VStack(spacing: 0) {
                    mainGuidanceRow(instruction: instruction)
                    nextInstructionRow
                }
                .background(bannerColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Theme.Colors.acTextDark.opacity(0.15), radius: 8, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.Colors.acField.opacity(0.3), lineWidth: 2))
                .padding(.horizontal, 12)
                .padding(.top, 12)
                // Navigation Logic
                .onChange(of: locationProvider.distanceTraveledInSimulationMeters) { _, traveled in
                    if locationProvider.isSimulating {
                        updateProgress(traveled: traveled, instruction: instruction)
                    }
                }
                .onChange(of: routingService.distanceTraveledMeters) { _, traveled in
                    if !locationProvider.isSimulating {
                        updateProgress(traveled: traveled, instruction: instruction)
                    }
                }
            }
        }
        .onAppear {
            currentInstructionIndex = routingService.currentInstructionIndex
        }
        .onChange(of: routingService.currentInstructionIndex) { _, newValue in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                currentInstructionIndex = newValue
            }
        }
    }

    @ViewBuilder
    private func mainGuidanceRow(instruction: NavigationInstruction) -> some View {
        HStack(spacing: 16) {
            // Instruction Icon & Distance
            VStack(spacing: 2) {
                Image(systemName: instruction.turnType.icon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Theme.Colors.acCream)
                    .scaleEffect(isApproachingTurn ? 1.15 : 1.0)
                    .frame(height: 40)

                Text(formatDistance(instruction: instruction))
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acCream)
                    .contentTransition(.numericText())
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isApproachingTurn)
            .frame(width: 70)

            // Instruction Text
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction.text)
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.acCream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            // Right side replay icon
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                SpeechService.shared.speak(instruction.text)
            }) {
                Circle()
                    .fill(Theme.Colors.acCream.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.Colors.acCream)
                    )
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var nextInstructionRow: some View {
        if currentInstructionIndex + 1 < routingService.instructions.count {
            let nextInst = routingService.instructions[currentInstructionIndex + 1]
            if nextInst.turnType != .arrive {
                VStack(spacing: 0) {
                    Divider()
                        .background(Theme.Colors.acCream.opacity(0.3))

                    HStack(spacing: 12) {
                        Text("THEN")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.acCream.opacity(0.8))
                            .kerning(0.5)

                        Image(systemName: nextInst.turnType.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.Colors.acCream)

                        Text(nextInst.text)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acCream)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.15))
                }
            }
        }
    }

    private func updateProgress(traveled: Double, instruction: NavigationInstruction) {
        let distToTurn = Double(instruction.routeOffsetInMeters) - traveled

        let distToTurnFt = distToTurn * Constants.metersToFeet
        if distToTurnFt > 0 && distToTurnFt < 350 {
            if !isApproachingTurn { isApproachingTurn = true }
        } else {
            if isApproachingTurn { isApproachingTurn = false }
        }

        if distToTurnFt > 0 {
            if distToTurnFt <= 500 && !routingService.hasWarned500ft {
                haptic500.notificationOccurred(.warning)
                routingService.hasWarned500ft = true
                SpeechService.shared.speak("In 500 feet, \(instruction.text)")
            }
            if distToTurnFt <= 100 && !routingService.hasWarned100ft {
                haptic100.impactOccurred()
                routingService.hasWarned100ft = true
                SpeechService.shared.speak(instruction.text)
            }
        }

        if distToTurn <= 12 { // Increased tolerance slightly for smoother transitions
            if currentInstructionIndex < routingService.instructions.count - 1 {
                routingService.currentInstructionIndex += 1
                if instruction.turnType == .arrive {
                    routingService.currentInstructionIndex = routingService.instructions.count
                }
            }
        }
    }

    private func formatDistance(instruction: NavigationInstruction) -> String {
        let traveled = locationProvider.isSimulating
            ? locationProvider.distanceTraveledInSimulationMeters
            : routingService.distanceTraveledMeters

        let distMeters = Double(instruction.routeOffsetInMeters) - traveled
        let distFeet = max(0, distMeters * Constants.metersToFeet)

        if distFeet > 1320 { // More than 0.25 miles
            let distMiles = distFeet / 5280.0
            return String(format: "%.1f mi", distMiles)
        } else {
            // Round to nearest 50 feet for cleaner UI
            let roundedFeet = Int(round(distFeet / 50.0) * 50)
            return "\(max(50, roundedFeet)) ft"
        }
    }
}
