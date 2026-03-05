import SwiftUI

struct RouteListRow: View {
    let route: TomTomRoute
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.Colors.acLeaf : Theme.Colors.acBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Theme.Colors.acLeaf).frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(formatTime(route.summary.travelTimeInSeconds))
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.acTextDark)
                        Spacer()
                        if route.isSafeRoute {
                            Image(systemName: "shield.fill")
                                .foregroundColor(Theme.Colors.acSky)
                                .font(.system(size: 13))
                        }
                        if route.isZeroCameras {
                            Image(systemName: "eye.slash.fill")
                                .foregroundColor(Theme.Colors.acLeaf)
                                .font(.system(size: 13))
                        }
                        if route.hasTolls {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(Theme.Colors.acGold)
                                .font(.system(size: 13))
                        }
                    }
                    Text(formatDistance(route.summary.lengthInMeters))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Theme.Colors.acLeaf.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: Int) -> String {
        let min = seconds / 60
        return min < 60 ? "\(min) min" : "\(min / 60)h \(min % 60)m"
    }

    private func formatDistance(_ meters: Int) -> String {
        String(format: "%.1f mi", Double(meters) * 0.000621371)
    }
}
