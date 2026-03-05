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

    @Test func unlockedCharacters_atLevel1_returnsOnlyFox() {
        clearPlayerDefaults()
        let store = PlayerStore()
        // Only camper_fox has unlockLevel 1 among the base characters
        #expect(store.unlockedCharacters.count == 1)
        #expect(store.unlockedCharacters[0].id == "camper_fox")
    }

    @Test func unlockedCharacters_atLevel5_includesThreeChars() {
        clearPlayerDefaults()
        let store = PlayerStore()
        // 100 + 200 + 300 + 400 = 1000 XP → level 5
        store.addXP(1000)
        #expect(store.currentLevel == 5)
        // camper_fox(1), scout_bear(3), breezy_bird(5) are all ≤ level 5
        #expect(store.unlockedCharacters.count == 3)
    }

    @Test func selectedCharacter_invalidId_fallsBackToFirst() {
        clearPlayerDefaults()
        let store = PlayerStore()
        store.selectedCharacterId = "nonexistent_id"
        #expect(store.selectedCharacter.id == "camper_fox")
    }

    @Test func xpForNextLevel_level1_returns100() {
        clearPlayerDefaults()
        let store = PlayerStore()
        #expect(store.xpForNextLevel() == 100)
    }

    @Test func xpForNextLevel_level2_returns200() {
        clearPlayerDefaults()
        let store = PlayerStore()
        store.addXP(100) // exactly hits level 2
        #expect(store.currentLevel == 2)
        #expect(store.xpForNextLevel() == 200)
    }

    @Test func addXP_levelUp_setsShowLevelUpToast() {
        clearPlayerDefaults()
        let store = PlayerStore()
        store.addXP(100)
        #expect(store.showLevelUpToast == true)
    }

    @Test func addXP_levelUp_populatesNewlyUnlockedCharacters() {
        clearPlayerDefaults()
        let store = PlayerStore()
        // 100 + 200 = 300 XP → level 3; scout_bear unlocks at level 3
        store.addXP(300)
        #expect(store.currentLevel == 3)
        #expect(store.newlyUnlockedCharacters.contains { $0.id == "scout_bear" })
    }

    @Test func processRideEnd_atExactlySpeed15_earnsZero() {
        clearPlayerDefaults()
        let store = PlayerStore()
        // avgSpeed == 15.0 does NOT satisfy > 15.0
        let xp = store.processRideEnd(durationSeconds: 600, avgSpeed: 15.0, distanceMiles: 5, questWaypointCount: 0)
        #expect(xp == 0)
    }

    @Test func currentLevelProgress_midLevel_returnsHalf() {
        clearPlayerDefaults()
        let store = PlayerStore()
        store.addXP(50) // 50 out of 100 XP needed for level 2
        let progress = store.currentLevelProgress()
        #expect(abs(progress - 0.5) < 0.001)
    }

    @Test func addXP_multiLevel_unlocksAllSkippedCharacters() {
        clearPlayerDefaults()
        let store = PlayerStore()
        // 100+200+300+400+500 = 1500 XP → level 6
        // newlyUnlockedCharacters should include scout_bear(3) and breezy_bird(5)
        store.addXP(1500)
        #expect(store.currentLevel == 6)
        #expect(store.newlyUnlockedCharacters.contains { $0.id == "scout_bear" })
        #expect(store.newlyUnlockedCharacters.contains { $0.id == "breezy_bird" })
    }
}
