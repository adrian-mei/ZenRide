import SwiftUI

struct MemoryPolaroidCard: View {
    let memory: Memory

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Theme.Colors.acSky.opacity(0.3)
                VStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.acTextDark.opacity(0.5))
                    Text(memory.locationName)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.acTextDark)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .frame(width: 140, height: 120)
            .background(Color.white.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(10)
            .background(Color.white)
            .rotationEffect(.degrees(Double.random(in: -2...2)))

            Text(memory.thought)
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.acTextDark)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: 160)
                .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 4)
        .acCardStyle(padding: 0, interactive: true, hasTexture: false)
    }
}
