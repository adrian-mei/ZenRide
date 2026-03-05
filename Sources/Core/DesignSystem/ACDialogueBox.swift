import SwiftUI

// MARK: - ACDialogueBox

/// Animal Crossing style dialogue box with a "beaked" pointer and chunky border.
public struct ACDialogueBox<Content: View>: View {
    let content: Content
    var speakerName: String?
    var speakerColor: Color = Theme.Colors.acLeaf

    public init(speakerName: String? = nil, speakerColor: Color = Theme.Colors.acLeaf, @ViewBuilder content: () -> Content) {
        self.speakerName = speakerName
        self.speakerColor = speakerColor
        self.content = content()
    }

    public var body: some View {
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
