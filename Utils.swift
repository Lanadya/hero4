import Foundation

func currentSchoolYear() -> String {
    let calendar = Calendar.current
    let date = Date()
    let year = calendar.component(.year, from: date)
    let month = calendar.component(.month, from: date)
    // Schuljahr beginnt im September
    if month >= 9 {
        return "\(year)/\(year + 1)"
    } else {
        return "\(year - 1)/\(year)"
    }
}
