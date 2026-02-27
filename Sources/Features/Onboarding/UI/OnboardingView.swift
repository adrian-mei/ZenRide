import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @EnvironmentObject var locationProvider: LocationProvider
    @State private var currentStep: Int = 0
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            Theme.Colors.acField.ignoresSafeArea()

            TabView(selection: $currentStep) {
                WelcomeStep(onNext: {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    onComplete()
                })
                .tag(0)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
            .ignoresSafeArea(.keyboard)
        }
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    let onNext: () -> Void
    @State private var appear = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)
                    
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.acLeaf.opacity(0.15))
                            .frame(width: 140, height: 140)
                        
                        Image(systemName: "map.fill")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(Theme.Colors.acLeaf)
                            .offset(y: appear ? 0 : 20)
                            .opacity(appear ? 1 : 0)
                    }

                    VStack(spacing: 12) {
                        Text("Welcome to\nFashodaMap")
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.acTextDark)
                            .multilineTextAlignment(.center)
                            .offset(y: appear ? 0 : 20)
                            .opacity(appear ? 1 : 0)

                        Text("Your daily commute, but make it cozy. Build custom routes, avoid traffic, and earn stamps.")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .offset(y: appear ? 0 : 20)
                            .opacity(appear ? 1 : 0)
                    }

                    Spacer(minLength: 40)

                    Button("Let's Go!") {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        onNext()
                    }
                    .buttonStyle(ACButtonStyle(variant: .primary))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                    .offset(y: appear ? 0 : 20)
                    .opacity(appear ? 1 : 0)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appear = true
            }
        }
    }
}
