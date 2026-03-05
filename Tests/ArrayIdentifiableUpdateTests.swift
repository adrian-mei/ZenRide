import Testing
import Foundation
@testable import ZenMap

private struct Item: Identifiable { var id: Int; var value: String }

struct ArrayIdentifiableUpdateTests {

    @Test func upsert_existingId_replacesInPlace() {
        var arr = [Item(id: 1, value: "a")]
        arr.upsert(Item(id: 1, value: "b"))
        #expect(arr.count == 1)
        #expect(arr[0].value == "b")
    }

    @Test func upsert_newId_appends() {
        var arr = [Item(id: 1, value: "a")]
        arr.upsert(Item(id: 2, value: "b"))
        #expect(arr.count == 2)
    }

    @Test func update_foundId_appliesTransformAndReturnsTrue() {
        var arr = [Item(id: 1, value: "a")]
        let found = arr.update(id: 1) { $0.value = "z" }
        #expect(found == true)
        #expect(arr[0].value == "z")
    }

    @Test func update_missingId_returnsFalseAndLeavesArrayUnchanged() {
        var arr = [Item(id: 1, value: "a")]
        let found = arr.update(id: 99) { $0.value = "z" }
        #expect(found == false)
        #expect(arr[0].value == "a")
    }
}
