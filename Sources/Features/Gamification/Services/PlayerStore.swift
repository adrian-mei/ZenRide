import Foundation
import SwiftUI

// MARK: - Character Model
struct Character: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String // SF Symbol or custom image name
    var colorHex: String
    var unlockLevel: Int

    static let all: [Character] = [
        Character(id: "camper_fox",   name: "Camper Fox",   icon: "pawprint.fill",  colorHex: "FF8C00", unlockLevel: 1),
        Character(id: "scout_bear",   name: "Scout Bear",   icon: "tortoise.fill",  colorHex: "8B4513", unlockLevel: 3),
        Character(id: "breezy_bird",  name: "Breezy Bird",  icon: "bird.fill",      colorHex: "4169E1", unlockLevel: 5),
        Character(id: "racer_rabbit", name: "Racer Rabbit", icon: "hare.fill",      colorHex: "FF69B4", unlockLevel: 10),
        Character(id: "zen_frog",     name: "Zen Frog",     icon: "leaf.fill",      colorHex: "32CD32", unlockLevel: 15)
    ]
}

// MARK: - Player Store

@MainActor
class PlayerStore: ObservableObject {
    @Published var totalXP: Int = 0
    @Published var currentLevel: Int = 1
    @Published var selectedCharacterId: String = "camper_fox"
    @Published var showLevelUpToast: Bool = false
    @Published var newlyUnlockedCharacters: [Character] = []
    @Published var newlyEarnedAchievement: Achievement? = nil

    private let xpKey = UserDefaultsKeys.playerXP
    private let charKey = UserDefaultsKeys.playerCharacter

    init() {
        load()
    }

    var selectedCharacter: Character {
        Character.all.first { $0.id == selectedCharacterId } ?? Character.all[0]
    }

    var unlockedCharacters: [Character] {
        Character.all.filter { $0.unlockLevel <= currentLevel }
    }

    func xpForNextLevel() -> Int {
        return currentLevel * 100
    }

    /// Progress (0–1) within the current level, using the same triangular XP schedule as calculateLevel().
    func currentLevelProgress() -> Double {
        var level = 1
        var xpThreshold = 100
        var consumedXP = 0

        while consumedXP + xpThreshold <= totalXP {
            consumedXP += xpThreshold
            level += 1
            xpThreshold = level * 100
        }
        // consumedXP = XP at start of current level; xpThreshold = XP needed for next level
        let relativeXP = totalXP - consumedXP
        return min(1.0, max(0.0, Double(relativeXP) / Double(xpThreshold)))
    }

    func addXP(_ amount: Int) {
        let previousLevel = currentLevel
        totalXP += amount
        calculateLevel()
        save()

        if currentLevel > previousLevel {
            let newUnlocks = Character.all.filter { $0.unlockLevel > previousLevel && $0.unlockLevel <= currentLevel }
            newlyUnlockedCharacters = newUnlocks
            showLevelUpToast = true

            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
        }
    }

    func selectCharacter(_ character: Character) {
        if character.unlockLevel <= currentLevel {
            selectedCharacterId = character.id
            save()
        }
    }

    private func calculateLevel() {
        var level = 1
        var xpThreshold = 100
        var remainingXP = totalXP

        while remainingXP >= xpThreshold {
            remainingXP -= xpThreshold
            level += 1
            xpThreshold = level * 100
        }
        currentLevel = level
    }

    private func save() {
        UserDefaults.standard.set(totalXP, forKey: xpKey)
        UserDefaults.standard.set(selectedCharacterId, forKey: charKey)
    }

    private func load() {
        totalXP = UserDefaults.standard.integer(forKey: xpKey)
        selectedCharacterId = UserDefaults.standard.string(forKey: charKey) ?? "camper_fox"
        calculateLevel()
    }
}
