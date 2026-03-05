import Testing
import Foundation
@testable import ZenMap

// MARK: - Helpers

private func clearPlayerDefaults() {
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.playerXP)
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.playerCharacter)
}

// MARK: - Tests

@MainActor
struct PlayerStoreTests {

    @Test func freshStoreStartsAtLevel1() {
        clearPlayerDefaults()
        let store = PlayerStore()
        #expect(store.currentLevel == 1)
        #expect(store.totalXP == 0)
    }

    @Test func addXP_belowThreshold_staysLevel1() {
        clearPlayerDefaults()
        let store = PlayerStore()
        store.addXP(99)
        #expect(store.currentLevel == 1)
    }

    @Test func addXP_atThreshold_levelsUp() {
        clearPlayerDefaults()
        let store = PlayerStore()
        store.addXP(100)
        #expect(store.currentLevel == 2)
    }

    @Test func levelProgressIsZeroAtLevelStart() {
        clearPlayerDefaults()
        let store = PlayerStore()
        store.addXP(100) // exactly at level 2 threshold
        let progress = store.currentLevelProgress()
        #expect(progress < 0.01)
    }

    @Test func processRideEnd_shortRide_earnsZeroXP() {
        clearPlayerDefaults()
        let store = PlayerStore()
        let xp = store.processRideEnd(durationSeconds: 300, avgSpeed: 30, distanceMiles: 2, questWaypointCount: 0)
        #expect(xp == 0)
    }

    @Test func processRideEnd_longRide_earnsDistanceXP() {
        clearPlayerDefaults()
        let store = PlayerStore()
        // 600s, >15 mph, 5 miles → max(50, Int(5*10)) = 50 XP
        let xp = store.processRideEnd(durationSeconds: 600, avgSpeed: 20, distanceMiles: 5, questWaypointCount: 0)
        #expect(xp == 50)
    }

    @Test func processRideEnd_withWaypoints_addsBonusXP() {
        clearPlayerDefaults()
        let store = PlayerStore()
        // 600s, >15 mph, 5 miles → 50 base + 2 waypoints * 25 = 100 XP
        let xp = store.processRideEnd(durationSeconds: 600, avgSpeed: 20, distanceMiles: 5, questWaypointCount: 2)
        #expect(xp == 100)
    }

    @Test func selectCharacter_lockedCharacter_isIgnored() {
        clearPlayerDefaults()
        let store = PlayerStore() // starts at level 1
        let lockedChar = Character.all.first { $0.unlockLevel > 1 }!
        store.selectCharacter(lockedChar)
        #expect(store.selectedCharacterId == "camper_fox")
    }
}
