import Foundation
import CoreLocation
import Combine

/// Manages active shared trips/crews.
@MainActor
class MultiplayerService: ObservableObject {
    @Published var activeSession: CampCrewSession?
    
    // In a real app, this would use WebSockets, Firebase, or CloudKit.
    // For now, we simulate friends joining a session.
    private var mockUpdateTimer: Timer?
    
    // Create a new session where we are the host.
    func startHostingSession(destinationName: String, destinationCoordinate: CLLocationCoordinate2D) {
        let session = CampCrewSession(
            id: UUID().uuidString,
            destinationName: destinationName,
            destinationCoordinate: destinationCoordinate,
            isHost: true
        )
        self.activeSession = session
        Log.info("Multiplayer", "Started hosting session to \(destinationName)")
        
        // Simulate a friend joining shortly after
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.simulateFriendJoining()
        }
    }
    
    func endSession() {
        self.activeSession = nil
        mockUpdateTimer?.invalidate()
        mockUpdateTimer = nil
        Log.info("Multiplayer", "Ended multiplayer session")
    }
    
    // We would call this repeatedly in RideView as the local user moves.
    func broadcastLocalLocation(coordinate: CLLocationCoordinate2D, heading: Double, speedMph: Double, route: [CLLocationCoordinate2D]?, etaSeconds: Int?) {
        guard let _ = activeSession else { return }
        // In reality, emit this to the server
        Log.info("Multiplayer", "Broadcasting location: \(speedMph) mph, ETA: \(etaSeconds ?? 0)s")
    }
    
    // --- Mocking ---
    
    private func simulateFriendJoining() {
        guard var session = activeSession else { return }
        
        // Spawn a friend somewhere nearby
        let friendLoc = CLLocationCoordinate2D(
            latitude: session.destinationCoordinate.latitude + 0.02,
            longitude: session.destinationCoordinate.longitude + 0.02
        )
        
        let friend = CampCrewMember(
            id: "friend_1",
            name: "Alex",
            coordinate: friendLoc,
            heading: 210,
            speedMph: 45.0,
            etaSeconds: 840, // 14 mins
            distanceToDestinationMeters: 5000,
            activeRoute: [friendLoc, session.destinationCoordinate] // simplify route
        )
        
        session.members.append(friend)
        self.activeSession = session
        
        // Start animating friend
        mockUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.animateMockFriends()
            }
        }
    }
    
    private func animateMockFriends() {
        guard var session = activeSession, !session.members.isEmpty else { return }
        
        for i in 0..<session.members.count {
            var member = session.members[i]
            
            // Move friend slightly towards destination
            let dx = session.destinationCoordinate.longitude - member.coordinate.longitude
            let dy = session.destinationCoordinate.latitude - member.coordinate.latitude
            
            // tiny step
            member.coordinate.latitude += dy * 0.01
            member.coordinate.longitude += dx * 0.01
            
            if let eta = member.etaSeconds, eta > 0 {
                member.etaSeconds = eta - 2
            }
            
            member.lastUpdated = Date()
            session.members[i] = member
        }
        
        self.activeSession = session
    }
}
