import Foundation
import SwiftData

struct BackupDTO: Codable {
    var properties: [PropertyDTO]
    var tasks: [TaskDTO]
    var documents: [DocumentDTO]
    var utilities: [UtilityDTO]
    var inventory: [InventoryDTO]
    var rooms: [RoomDTO]
}
struct PropertyDTO: Codable { var id: UUID; var name: String; var address: String; var purchaseDate: Date?; var purchasePrice: Double?; var notes: String }
struct TaskDTO: Codable { var id: UUID; var title: String; var details: String; var dueDate: Date?; var frequencyDays: Int?; var costEstimate: Double?; var status: String; var category: String; var notify: Bool; var propertyID: UUID? }
struct DocumentDTO: Codable { var id: UUID; var title: String; var kind: String; var notes: String; var addedAt: Date; var fileName: String?; var storedPath: String?; var propertyID: UUID? }
struct UtilityDTO: Codable { var id: UUID; var provider: String; var accountNumber: String; var type: String; var tariff: String; var notes: String; var propertyID: UUID? }
struct InventoryDTO: Codable { var id: UUID; var name: String; var location: String; var serialNumber: String; var purchaseDate: Date?; var warrantyExpiry: Date?; var value: Double?; var notes: String; var propertyID: UUID? }
struct RoomDTO: Codable { var id: UUID; var name: String; var x: Double; var y: Double; var width: Double; var height: Double; var colorHex: String; var propertyID: UUID? }

enum BackupManager {
    static func exportJSON(from context: ModelContext) throws -> URL {
        let properties = try context.fetch(FetchDescriptor<Property>())
        let tasks = try context.fetch(FetchDescriptor<MaintenanceTask>())
        let docs = try context.fetch(FetchDescriptor<DocumentItem>())
        let utils = try context.fetch(FetchDescriptor<UtilityAccount>())
        let inv = try context.fetch(FetchDescriptor<InventoryItem>())
        let rooms = try context.fetch(FetchDescriptor<FloorRoom>())
        let dto = BackupDTO(
            properties: properties.map { PropertyDTO(id: $0.id, name: $0.name, address: $0.address, purchaseDate: $0.purchaseDate, purchasePrice: $0.purchasePrice, notes: $0.notes) },
            tasks: tasks.map { TaskDTO(id: $0.id, title: $0.title, details: $0.details, dueDate: $0.dueDate, frequencyDays: $0.frequencyDays, costEstimate: $0.costEstimate, status: $0.status.rawValue, category: $0.category.rawValue, notify: $0.notify, propertyID: $0.property?.id) },
            documents: docs.map { DocumentDTO(id: $0.id, title: $0.title, kind: $0.kind, notes: $0.notes, addedAt: $0.addedAt, fileName: $0.fileName, storedPath: $0.storedPath, propertyID: $0.property?.id) },
            utilities: utils.map { UtilityDTO(id: $0.id, provider: $0.provider, accountNumber: $0.accountNumber, type: $0.type, tariff: $0.tariff, notes: $0.notes, propertyID: $0.property?.id) },
            inventory: inv.map { InventoryDTO(id: $0.id, name: $0.name, location: $0.location, serialNumber: $0.serialNumber, purchaseDate: $0.purchaseDate, warrantyExpiry: $0.warrantyExpiry, value: $0.value, notes: $0.notes, propertyID: $0.property?.id) },
            rooms: rooms.map { RoomDTO(id: $0.id, name: $0.name, x: $0.x, y: $0.y, width: $0.width, height: $0.height, colorHex: $0.colorHex, propertyID: $0.property?.id) }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(dto)
        let url = FileHelper.documentsDirectory().appendingPathComponent("PropertyManagerBackup-\(ISO8601DateFormatter().string(from: Date())).json")
        try data.write(to: url)
        return url
    }
    static func importJSON(from url: URL, into context: ModelContext) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dto = try decoder.decode(BackupDTO.self, from: data)
        var propMap: [UUID: Property] = [:]
        for p in dto.properties {
            let prop = Property(id: p.id, name: p.name, address: p.address, purchaseDate: p.purchaseDate, purchasePrice: p.purchasePrice, notes: p.notes)
            context.insert(prop); propMap[p.id] = prop
        }
        for t in dto.tasks {
            let task = MaintenanceTask(id: t.id, title: t.title, details: t.details, dueDate: t.dueDate, frequencyDays: t.frequencyDays, costEstimate: t.costEstimate, status: TaskStatus(rawValue: t.status) ?? .pending, category: TaskCategory(rawValue: t.category) ?? .other, notify: t.notify, property: t.propertyID.flatMap { propMap[$0] })
            context.insert(task)
        }
        for d in dto.documents {
            let doc = DocumentItem(id: d.id, title: d.title, kind: d.kind, notes: d.notes, addedAt: d.addedAt, fileName: d.fileName, storedPath: d.storedPath, property: d.propertyID.flatMap { propMap[$0] })
            context.insert(doc)
        }
        for u in dto.utilities {
            let util = UtilityAccount(id: u.id, provider: u.provider, accountNumber: u.accountNumber, type: u.type, tariff: u.tariff, notes: u.notes, property: u.propertyID.flatMap { propMap[$0] })
            context.insert(util)
        }
        for i in dto.inventory {
            let item = InventoryItem(id: i.id, name: i.name, location: i.location, serialNumber: i.serialNumber, purchaseDate: i.purchaseDate, warrantyExpiry: i.warrantyExpiry, value: i.value, notes: i.notes, property: i.propertyID.flatMap { propMap[$0] })
            context.insert(item)
        }
        for r in dto.rooms {
            let room = FloorRoom(id: r.id, name: r.name, x: r.x, y: r.y, width: r.width, height: r.height, colorHex: r.colorHex, property: r.propertyID.flatMap { propMap[$0] })
            context.insert(room)
        }
        try context.save()
    }
}
