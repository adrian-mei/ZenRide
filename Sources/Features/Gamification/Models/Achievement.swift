import SwiftUI

public struct Achievement: Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let icon: String
    public let color: Color
    public let isEarned: Bool
    public let progress: Double   // 0–1, for partially earned badges

    public init(id: String, title: String, subtitle: String, icon: String, color: Color, isEarned: Bool, progress: Double) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.isEarned = isEarned
        self.progress = progress
    }
}
