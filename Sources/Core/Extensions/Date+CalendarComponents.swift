import Foundation

extension Date {
    var hour: Int    { Calendar.current.component(.hour, from: self) }
    var weekday: Int { Calendar.current.component(.weekday, from: self) }
    var month: Int   { Calendar.current.component(.month, from: self) }
    var year: Int    { Calendar.current.component(.year, from: self) }
}
