import SwiftUI

// MARK: - ACSectionDivider

/// Inset divider matching the AC border opacity style.
public struct ACSectionDivider: View {
    var leadingInset: CGFloat = 40
    
    public init(leadingInset: CGFloat = 40) {
        self.leadingInset = leadingInset
    }

    public var body: some View {
        Divider()
            .background(Theme.Colors.acBorder.opacity(0.3))
            .padding(.leading, leadingInset)
    }
}
