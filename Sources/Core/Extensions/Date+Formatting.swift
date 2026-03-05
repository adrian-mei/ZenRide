import Foundation

public extension Date {
    func relativeDateString() -> String {
        let days = Calendar.current.dateComponents([.day], from: self, to: Date()).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days) days ago"
        }
    }

    func markedLocationTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: self)
    }
}
