import Testing
import Foundation
import CoreLocation
@testable import ZenMap

// MARK: - Helpers

private func clearQuestDefaults() {
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.questsV2)
}

// MARK: - Tests

@MainActor
struct QuestStoreTests {

    @Test func freshStoreHasDefaultQuests() {
        clearQuestDefaults()
        let store = QuestStore()
        #expect(store.quests.count == 2)
        #expect(store.quests.contains { $0.title == "Morning Run" })
        #expect(store.quests.contains { $0.title == "Yosemite Trip" })
    }

    @Test func addQuest_incrementsCount() {
        clearQuestDefaults()
        let store = QuestStore()
        let initial = store.quests.count
        store.addQuest(DailyQuest(title: "Test Quest", waypoints: []))
        #expect(store.quests.count == initial + 1)
    }

    @Test func removeQuestById_removesCorrectEntry() {
        clearQuestDefaults()
        let store = QuestStore()
        let quest = DailyQuest(title: "Remove Me", waypoints: [])
        store.addQuest(quest)
        store.removeQuest(id: quest.id)
        #expect(!store.quests.contains { $0.id == quest.id })
    }

    @Test func removeQuestAtOffsets_removesCorrectEntry() {
        clearQuestDefaults()
        let store = QuestStore()
        store.addQuest(DailyQuest(title: "Extra Quest", waypoints: []))
        let count = store.quests.count
        store.removeQuest(at: IndexSet(integer: 0))
        #expect(store.quests.count == count - 1)
    }

    @Test func questPersistsRoundTrip() {
        clearQuestDefaults()
        let store1 = QuestStore()
        store1.addQuest(DailyQuest(title: "Persistent Quest", waypoints: []))
        let store2 = QuestStore()
        #expect(store2.quests.contains { $0.title == "Persistent Quest" })
    }
}
