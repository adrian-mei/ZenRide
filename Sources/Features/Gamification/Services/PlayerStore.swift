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
        Character(id: "camper_fox", name: "Camper Fox", icon: "fox.fill", colorHex: "FF8C00", unlockLevel: 1),
        Character(id: "scout_bear", name: "Scout Bear", icon: "pawprint.fill", colorHex: "8B4513", unlockLevel: 3),
        Character(id: "breezy_bird", name: "Breezy Bird", icon: "bird.fill", colorHex: "4169E1", unlockLevel: 5),
        Character(id: "racer_rabbit", name: "Racer Rabbit", icon: "hare.fill", colorHex: "FF69B4", unlockLevel: 10),
        Character(id: "zen_frog", name: "Zen Frog", icon: "leaf.fill", colorHex: "32CD32", unlockLevel: 15)
    ]
}

// MARK: - Player Store
class PlayerStore: ObservableObject {
    @Published var totalXP: Int = 0
    @Published var currentLevel: Int = 1
    @Published var selectedCharacterId: String = "camper_fox"
    @Published var showLevelUpToast: Bool = false
    @Published var newlyUnlockedCharacters: [Character] = []
    
    private let xpKey = "PlayerStore_TotalXP_v1"
    private let charKey = "PlayerStore_Character_v1"
    
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
        return currentLevel * 100 // Level 1 -> 100 XP to reach Level 2. Level 2 -> 200 XP to reach Level 3, etc.
    }
    
    func currentLevelProgress() -> Double {
        let prevLevelXP = (currentLevel - 1) * 100
        let currentLevelXP = xpForNextLevel()
        let relativeXP = totalXP - prevLevelXP
        return min(1.0, max(0.0, Double(relativeXP) / Double(currentLevelXP)))
    }
    
    func addXP(_ amount: Int) {
        let previousLevel = currentLevel
        totalXP += amount
        calculateLevel()
        save()
        
        if currentLevel > previousLevel {
            // Level Up! Check for unlocks
            let newUnlocks = Character.all.filter { $0.unlockLevel > previousLevel && $0.unlockLevel <= currentLevel }
            
            // Haptic Feedback for Level Up!
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            #endif
            
            DispatchQueue.main.async {
                self.newlyUnlockedCharacters = newUnlocks
                self.showLevelUpToast = true
            }
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
