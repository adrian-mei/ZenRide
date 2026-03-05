import SwiftUI

struct AddBikeCard: View {
    var body: some View {
        VStack {
            Image(systemName: "plus.circle.fill")
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.acLeaf)
            Text("Add Bike")
                .font(Theme.Typography.button)
                .foregroundColor(Theme.Colors.acTextDark)
                .padding(.top, 8)
        }
        .frame(width: 140, height: 160)
        .background(Theme.Colors.acCream)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(Theme.Colors.acBorder)
        )
    }
}
