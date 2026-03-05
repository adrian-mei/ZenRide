import Foundation

extension UserDefaults {
    func saveJSON<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            set(data, forKey: key)
        } catch {
            Log.error("UserDefaults", "Failed to encode \(T.self) for key '\(key)': \(error)")
        }
    }

    func loadJSON<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Log.error("UserDefaults", "Failed to decode \(T.self) for key '\(key)': \(error)")
            return nil
        }
    }

    /// Loads a `RawRepresentable` enum whose raw value is a `String`.
    func loadRawValue<E: RawRepresentable>(_ type: E.Type, forKey key: String) -> E?
        where E.RawValue == String {
        guard let raw = string(forKey: key) else { return nil }
        return E(rawValue: raw)
    }

    /// Loads a `UUID` stored as a plain string.
    func loadUUID(forKey key: String) -> UUID? {
        guard let str = string(forKey: key) else { return nil }
        return UUID(uuidString: str)
    }
}
