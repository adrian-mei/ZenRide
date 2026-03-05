import SwiftUI

struct HomeSheetRecentMemories: View {
    let memories: [Memory]

    var body: some View {
        if !memories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Memories")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)
                    Image(systemName: "eye.fill")
                        .foregroundColor(Theme.Colors.acGold)
                        .font(.caption.bold())
                    Spacer()
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(memories.prefix(5)) { memory in
                            MemoryPolaroidCard(memory: memory)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}
