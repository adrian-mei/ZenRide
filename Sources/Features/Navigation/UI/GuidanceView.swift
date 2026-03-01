import SwiftUI

struct GuidanceView: View {
    @EnvironmentObject var routingService: RoutingService
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
                    mainGuidanceRow(instruction: instruction)
                    nextInstructionRow
                }
                .acCardStyle(padding: 0, interactive: false, hasTexture: true)
                .frame(maxWidth: 280)
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
    
    @ViewBuilder
    private func mainGuidanceRow(instruction: NavigationInstruction) -> some View {
        HStack(spacing: 16) {
            // Instruction Icon & Distance
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.acLeaf.opacity(isApproachingTurn ? 0.2 : 0.1))
                        .frame(width: 54, height: 54)
                    
                    Image(systemName: instruction.turnType.icon)
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(Theme.Colors.acLeaf)
                        .scaleEffect(isApproachingTurn ? 1.15 : 1.0)
                }
                
                Text(formatDistance(instruction: instruction))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(Theme.Colors.acTextDark)
                    .contentTransition(.numericText())
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isApproachingTurn)
            
            // Instruction Text
            VStack(alignment: .leading, spacing: 4) {
                Text(instruction.text)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(Theme.Colors.acCream)
    }
    
    @ViewBuilder
    private var nextInstructionRow: some View {
        if currentInstructionIndex + 1 < routingService.instructions.count {
            let nextInst = routingService.instructions[currentInstructionIndex + 1]
            if nextInst.turnType != .arrive {
                VStack(spacing: 0) {
                    ACSectionDivider(leadingInset: 0)
                    HStack(spacing: 10) {
                        Text("THEN")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .kerning(0.5)
                        
                        Image(systemName: nextInst.turnType.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.acTextDark.opacity(0.7))
                        
                        Text(nextInst.text)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextDark.opacity(0.7))
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.acField)
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
