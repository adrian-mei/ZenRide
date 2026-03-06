import SwiftUI

struct HomeSheetDiscoverActions: View {
    var onWanderTap: () -> Void
    var onDiscoverNewTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onWanderTap()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "tent.fill")
                        .font(Theme.Typography.title2)
                    Text("Wander & Discover")
                        .font(Theme.Typography.button)
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
                        .font(Theme.Typography.title2)
                    Text("Discover New")
                        .font(Theme.Typography.button)
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
