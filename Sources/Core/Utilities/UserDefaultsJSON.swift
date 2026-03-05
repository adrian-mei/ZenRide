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
}
