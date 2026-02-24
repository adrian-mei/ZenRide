import Foundation

enum Log {
    static func info(_ tag: String, _ message: String) {
        print("ℹ️ [\(tag)] \(message)")
    }

    static func error(_ tag: String, _ message: String) {
        print("❌ [\(tag)] \(message)")
    }

    static func warn(_ tag: String, _ message: String) {
        print("⚠️ [\(tag)] \(message)")
    }

    static func debug(_ tag: String, _ message: String) {
        #if DEBUG
        print("🔍 [\(tag)] \(message)")
        #endif
    }
}
