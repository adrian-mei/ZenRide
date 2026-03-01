import SwiftUI

struct QuestCelebrationOverlay: View {
    let stopName: String
    let isFinal: Bool
    let onDismiss: () -> Void
    
    @State private var showContent = false
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            if showContent {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.acLeaf)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: isFinal ? "flag.checkered" : "checkmark")
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(showContent ? 1.0 : 0.5)
                    .rotationEffect(.degrees(isFinal ? 360 : 0))
                    
                    VStack(spacing: 8) {
                        Text(isFinal ? "Adventure Complete!" : "Stop Reached!")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextDark)
                        
                        Text(isFinal ? "You've reached your final destination." : "You've arrived at \(stopName).")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button {
                        onDismiss()
                    } label: {
                        Text(isFinal ? "Awesome!" : "Continue Journey")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Theme.Colors.acWood)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 10)
                }
                .padding(30)
                .background(Theme.Colors.acCream)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Theme.Colors.acBorder, lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                .transition(.scale.combined(with: .opacity))
            }
            
            if showConfetti {
                // Simple emoji confetti
                ForEach(0..<20) { i in
                    ConfettiPiece()
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }
            showConfetti = true
            
            if !isFinal {
                // Auto dismiss after 5 seconds if not final
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    onDismiss()
                }
            }
        }
    }
}

struct ConfettiPiece: View {
    @State private var pos = CGPoint(x: CGFloat.random(in: 0...400), y: -50)
    @State private var opacity = 1.0
    @State private var rotation = Double.random(in: 0...360)
    
    let emojis = ["🌸", "🍃", "✨", "⭐", "🍎"]
    
    var body: some View {
        Text(emojis.randomElement()!)
            .font(.system(size: CGFloat.random(in: 15...30)))
            .position(pos)
            .opacity(opacity)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: Double.random(in: 2...4))) {
                    pos.y = 800
                    pos.x += CGFloat.random(in: -100...100)
                    rotation += 360
                }
                withAnimation(.easeIn(duration: 1).delay(2)) {
                    opacity = 0
                }
            }
    }
}
