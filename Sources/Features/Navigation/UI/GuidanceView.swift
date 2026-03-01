import SwiftUI

struct GuidanceView: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @State private var currentInstructionIndex: Int = 0
    @State private var isApproachingTurn = false
    private let haptic500 = UINotificationFeedbackGenerator()
    private let haptic100 = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        VStack {
            if !routingService.instructions.isEmpty, currentInstructionIndex < routingService.instructions.count {
                let instruction = routingService.instructions[currentInstructionIndex]
                
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Image(systemName: instruction.turnType.icon)
                                .font(.system(size: 32, weight: .heavy))
                                .foregroundColor(Theme.Colors.acLeaf)
                                .scaleEffect(isApproachingTurn ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isApproachingTurn)
                                .frame(width: 50)
                            
                            Text(formatDistance(instruction: instruction))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.acTextDark)
                                .contentTransition(.numericText())
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(instruction.text)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.Colors.acTextDark)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    
                    // Next Instruction preview
                    if currentInstructionIndex + 1 < routingService.instructions.count {
                        let nextInst = routingService.instructions[currentInstructionIndex + 1]
                        if nextInst.turnType != .arrive {
                            ACSectionDivider(leadingInset: 0)
                            HStack(spacing: 8) {
                                Text("THEN")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(Theme.Colors.acTextMuted)
                                
                                Image(systemName: nextInst.turnType.icon)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Theme.Colors.acTextDark)
                                
                                Text(nextInst.text)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Theme.Colors.acTextDark)
                                    .lineLimit(1)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.Colors.acField)
                        }
                    }
                }
                .background(Theme.Colors.acCream)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Theme.Colors.acBorder, lineWidth: 2)
                )
                .shadow(color: Theme.Colors.acBorder.opacity(0.5), radius: 0, x: 0, y: 6)
                .frame(maxWidth: 260) // Limits width in the corner
                .padding(.horizontal, 16)
                .padding(.top, 16)
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentInstructionIndex = newValue
            }
        }
    }

    private func updateProgress(traveled: Double, instruction: NavigationInstruction) {
        let distToTurn = Double(instruction.routeOffsetInMeters) - traveled
        
        let distToTurnFt = distToTurn * 3.28084
        if distToTurnFt > 0 && distToTurnFt < 300 {
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

        if distToTurn <= 10 { // 10 meters tolerance to snap to next
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
        let distFeet = max(0, distMeters * 3.28084)
        
        if distFeet > 1000 { // Approx 0.2 miles
            let distMiles = distFeet / 5280.0
            return String(format: "%.1f mi", distMiles)
        } else {
            // Round to nearest 50 feet for cleaner UI
            let roundedFeet = Int(round(distFeet / 50.0) * 50)
            return "\(max(50, roundedFeet)) ft"
        }
    }
}
