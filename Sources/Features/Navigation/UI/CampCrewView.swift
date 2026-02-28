import SwiftUI

struct CampCrewView: View {
    let avatars = ["🦊", "🐶", "🐱"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ROAD TRIP CREW")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(Theme.Colors.acTextDark.opacity(0.6))
                .padding(.leading, 4)
            
            HStack(spacing: -8) {
                ForEach(0..<avatars.count, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.acCream)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Theme.Colors.acBorder, lineWidth: 2)
                            )
                        
                        Text(avatars[index])
                            .font(.system(size: 20))
                    }
                    .shadow(color: Theme.Colors.acBorder.opacity(0.3), radius: 2, x: 0, y: 2)
                    .zIndex(Double(avatars.count - index))
                }
                
                Button(action: {
                    // Invite action
                }) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.acField)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Theme.Colors.acBorder, style: StrokeStyle(lineWidth: 2, dash: [4]))
                            )
                        
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.acTextMuted)
                    }
                }
                .padding(.leading, 12)
            }
        }
        .padding(12)
        .background(Theme.Colors.acCream.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.Colors.acBorder.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: Theme.Colors.acBorder.opacity(0.3), radius: 0, x: 0, y: 4)
    }
}
