import Foundation

struct VisitRecord: Codable {
    let date: Date
    let hour: Int
    let weekday: Int // 1-7
    let month: Int // 1-12

    init(date: Date, hour: Int, weekday: Int, month: Int) {
        self.date = date
        self.hour = hour
        self.weekday = weekday
        self.month = month
    }
}
