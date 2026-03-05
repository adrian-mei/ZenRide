import SwiftUI

// MARK: - ACSnapshotEffect

/// Full-screen white flash with a camera shutter sound (simulated by haptics).
public struct ACSnapshotEffect: View {
    @Binding var isTriggered: Bool
    
    public init(isTriggered: Binding<Bool>) {
        self._isTriggered = isTriggered
    }

    public var body: some View {
        Color.white
            .opacity(isTriggered ? 1.0 : 0.0)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.1), value: isTriggered)
            .onChange(of: isTriggered) { _, newValue in
                if newValue {
                    // Quick flash out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isTriggered = false
                    }
                }
            }
    }
}
