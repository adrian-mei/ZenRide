import Foundation

extension Array where Element: Identifiable {
    /// Replaces the element with matching id, or appends if not found.
    mutating func upsert(_ element: Element) {
        if let idx = firstIndex(where: { $0.id == element.id }) {
            self[idx] = element
        } else {
            append(element)
        }
    }

    /// Applies a transform to the element with matching id. Returns true if found.
    @discardableResult
    mutating func update(id: Element.ID, _ transform: (inout Element) -> Void) -> Bool {
        guard let idx = firstIndex(where: { $0.id == id }) else { return false }
        transform(&self[idx])
        return true
    }
}
