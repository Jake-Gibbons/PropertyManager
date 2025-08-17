import Foundation
import SwiftData

@Model
final class Property: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var address: String
    var purchaseDate: Date?
    var purchasePrice: Double?
    var notes: String
    @Relationship(deleteRule: .cascade) var tasks: [MaintenanceTask] = []
    @Relationship(deleteRule: .cascade) var documents: [DocumentItem] = []
    @Relationship(deleteRule: .cascade) var utilities: [UtilityAccount] = []
    @Relationship(deleteRule: .cascade) var inventory: [InventoryItem] = []
    @Relationship(deleteRule: .cascade) var rooms: [FloorRoom] = []

    init(id: UUID = UUID(), name: String, address: String, purchaseDate: Date? = nil, purchasePrice: Double? = nil, notes: String = "") {
        self.id = id; self.name = name; self.address = address
        self.purchaseDate = purchaseDate; self.purchasePrice = purchasePrice; self.notes = notes
    }
}

enum TaskStatus: String, Codable, CaseIterable, Identifiable { case pending, scheduled, inProgress, completed, skipped; var id: String { rawValue } }
enum TaskCategory: String, Codable, CaseIterable, Identifiable { case safety = "Safety", seasonal = "Seasonal", plumbing = "Plumbing", electrical = "Electrical", garden = "Garden", cleaning = "Cleaning", other = "Other"; var id: String { rawValue } }

@Model
final class MaintenanceTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String
    var dueDate: Date?
    var frequencyDays: Int?
    var costEstimate: Double?
    var status: TaskStatus
    var category: TaskCategory
    var notify: Bool
    @Relationship var property: Property?
    init(id: UUID = UUID(), title: String, details: String = "", dueDate: Date? = nil, frequencyDays: Int? = nil, costEstimate: Double? = nil, status: TaskStatus = .pending, category: TaskCategory = .other, notify: Bool = true, property: Property? = nil) {
        self.id = id; self.title = title; self.details = details; self.dueDate = dueDate; self.frequencyDays = frequencyDays
        self.costEstimate = costEstimate; self.status = status; self.category = category; self.notify = notify; self.property = property
    }
}

@Model
final class DocumentItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var kind: String
    var notes: String
    var addedAt: Date
    var fileName: String?
    var storedPath: String?
    @Relationship var property: Property?
    init(id: UUID = UUID(), title: String, kind: String, notes: String = "", addedAt: Date = .now, fileName: String? = nil, storedPath: String? = nil, property: Property? = nil) {
        self.id = id; self.title = title; self.kind = kind; self.notes = notes; self.addedAt = addedAt; self.fileName = fileName; self.storedPath = storedPath; self.property = property
    }
}

@Model
final class UtilityAccount: Identifiable {
    @Attribute(.unique) var id: UUID
    var provider: String
    var accountNumber: String
    var type: String
    var tariff: String
    var notes: String
    @Relationship var property: Property?
    init(id: UUID = UUID(), provider: String, accountNumber: String, type: String, tariff: String = "", notes: String = "", property: Property? = nil) {
        self.id = id; self.provider = provider; self.accountNumber = accountNumber; self.type = type; self.tariff = tariff; self.notes = notes; self.property = property
    }
}

@Model
final class InventoryItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var location: String
    var serialNumber: String
    var purchaseDate: Date?
    var warrantyExpiry: Date?
    var value: Double?
    var notes: String
    @Relationship var property: Property?
    init(id: UUID = UUID(), name: String, location: String, serialNumber: String = "", purchaseDate: Date? = nil, warrantyExpiry: Date? = nil, value: Double? = nil, notes: String = "", property: Property? = nil) {
        self.id = id; self.name = name; self.location = location; self.serialNumber = serialNumber; self.purchaseDate = purchaseDate; self.warrantyExpiry = warrantyExpiry; self.value = value; self.notes = notes; self.property = property
    }
}

@Model
final class FloorRoom: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var colorHex: String
    @Relationship var property: Property?
    init(id: UUID = UUID(), name: String, x: Double, y: Double, width: Double, height: Double, colorHex: String = "#89CFF0", property: Property? = nil) {
        self.id = id; self.name = name; self.x = x; self.y = y; self.width = width; self.height = height; self.colorHex = colorHex; self.property = property
    }
}
