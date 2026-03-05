import SwiftUI

struct HomeSheetDiscoverActions: View {
    var onWanderTap: () -> Void
    var onDiscoverNewTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onWanderTap) {
                VStack(spacing: 8) {
                    Image(systemName: "tent.fill")
                        .font(.system(size: 24, weight: .bold))
                    Text("Wander & Discover")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(ACButtonStyle(variant: .largePrimary))

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDiscoverNewTap()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24, weight: .bold))
                    Text("Discover New")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(ACButtonStyle(variant: .largeSecondary))
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .padding(.top, 4)
    }
}
