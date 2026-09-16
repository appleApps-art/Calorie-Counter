import Foundation

enum PantryItemMapper {
    static func map(_ object: CDPantryItem) -> PantryItem? {
        guard let id = object.id, let name = object.name, let createdAt = object.createdAt else { return nil }
        return PantryItem(
            id: id,
            name: name,
            quantityText: object.quantityText ?? "",
            amount: object.amount?.doubleValue,
            unit: object.unit,
            useBy: object.useBy,
            imageURL: object.imageURLString.flatMap(URL.init(string:)),
            imageData: object.imageData,
            createdAt: createdAt,
            updatedAt: object.updatedAt ?? createdAt
        )
    }

    static func apply(_ item: PantryItem, to object: CDPantryItem) {
        object.id = item.id
        object.name = item.name
        object.quantityText = item.quantityText
        object.amount = item.amount.map { NSNumber(value: $0) }
        object.unit = item.unit
        object.useBy = item.useBy
        object.imageURLString = item.imageURL?.absoluteString
        object.imageData = item.imageData
        object.createdAt = item.createdAt
        object.updatedAt = item.updatedAt
    }
}
