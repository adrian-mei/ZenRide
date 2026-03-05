import SwiftUI

// MARK: - ACGuideCard

public struct ACGuideCard: View {
    let title: String
    let count: Int
    let icon: String
    let bgColor: Color
    
    public init(title: String, count: Int, icon: String, bgColor: Color) {
        self.title = title
        self.count = count
        self.icon = icon
        self.bgColor = bgColor
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(bgColor)
                .frame(width: 140, height: 180)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acBorder, lineWidth: 2))
                .shadow(color: Theme.Colors.acBorder.opacity(0.8), radius: 0, x: 0, y: 4)

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundColor(Theme.Colors.acTextDark.opacity(0.6))
                        .padding(8)
                }
                Spacer()
            }

            ACGuideCardCenterView {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.acCream.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(2)
                Text("\(count) places")
                    .font(Theme.Typography.button)
                    .foregroundColor(Theme.Colors.acTextMuted)
            }
            .padding(12)
        }
        .frame(width: 140, height: 180)
    }
}

fileprivate struct ACGuideCardCenterView<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack {
            Spacer()
            content()
            Spacer()
        }
    }
}
