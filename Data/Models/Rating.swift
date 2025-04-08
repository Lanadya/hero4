import Foundation
import GRDB

struct Rating: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var studentId: UUID
    var classId: UUID
    var date: Date
    var value: RatingValue?
    var isAbsent: Bool
    var isArchived: Bool
    var createdAt: Date
    var schoolYear: String  // Neues Feld für das Schuljahr

    init(id: UUID = UUID(),
         studentId: UUID,
         classId: UUID,
         date: Date = Date(),
         value: RatingValue? = nil,
         isAbsent: Bool = false,
         isArchived: Bool = false,
         createdAt: Date = Date(),
         schoolYear: String) {  // Konstruktor mit schoolYear erweitern

        self.id = id
        self.studentId = studentId
        self.classId = classId
        self.date = date
        self.value = value
        self.isAbsent = isAbsent
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.schoolYear = schoolYear
    }
}

// MARK: - GRDB Record Protocols
extension Rating: TableRecord, FetchableRecord, PersistableRecord {
    // Define table name
    static var databaseTableName: String { "rating" }

    // Define column names
    enum Columns {
        static let id = Column("id")
        static let studentId = Column("studentId")
        static let classId = Column("classId")
        static let date = Column("date")
        static let value = Column("value")
        static let isAbsent = Column("isAbsent")
        static let isArchived = Column("isArchived")
        static let createdAt = Column("createdAt")
        static let schoolYear = Column("schoolYear")
    }

    // Encode the Rating to database columns
    func encode(to container: inout PersistenceContainer) {
        container[Columns.id] = id.uuidString
        container[Columns.studentId] = studentId.uuidString
        container[Columns.classId] = classId.uuidString
        container[Columns.date] = date
        container[Columns.value] = value?.rawValue
        container[Columns.isAbsent] = isAbsent
        container[Columns.isArchived] = isArchived
        container[Columns.createdAt] = createdAt
        container[Columns.schoolYear] = schoolYear
    }

    // Initialize Rating from database row
    init(row: Row) {
        self.id = UUID(uuidString: row[Columns.id]) ?? UUID()
        self.studentId = UUID(uuidString: row[Columns.studentId]) ?? UUID()
        self.classId = UUID(uuidString: row[Columns.classId]) ?? UUID()
        self.date = row[Columns.date]
        if let valueStr = row[Columns.value] as String? {
            self.value = RatingValue(rawValue: valueStr)
        } else if let valueInt = row[Columns.value] as Int? {
            // Handle legacy integer values
            switch valueInt {
            case 1: self.value = .excellent
            case 2: self.value = .good
            case 3: self.value = .fair
            case 4: self.value = .poor
            default: self.value = nil
            }
        } else {
            self.value = nil
        }
        self.isAbsent = row[Columns.isAbsent]
        self.isArchived = row[Columns.isArchived]
        self.createdAt = row[Columns.createdAt]
        self.schoolYear = row[Columns.schoolYear]
    }
}
