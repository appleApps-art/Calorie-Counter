import Foundation

// Semantic presentation is independent of the provider's lookup namespace.
enum FoodType: String, Codable, Equatable {
    case product
    case dish

    static func inferred(kind: FoodProductKind?, source: FoodProductSource, hasBrand: Bool = false, hasSteps: Bool = false) -> FoodType? {
        if kind == .recipe { return .dish }
        if kind == .product && (source == .openFoodFacts || source == .spoonacular || hasBrand) {
            return .product
        }
        if hasSteps { return .dish }
        return nil
    }
}

enum FoodProductKind: String, Equatable {
    case ingredient
    case product
    case recipe

}

enum FoodProductSource: String, Equatable {
    case openAI = "openai"
    case openFoodFacts = "openfoodfacts"
    case spoonacular = "spoonacular"
    case tavily = "tavily"
    case textAnalysis = "text"
    case catalog = "catalog"
    case unknown = "unknown"

    init(apiValue: String?) {
        switch apiValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "openai", "ai":
            self = .openAI
        case "openfoodfacts":
            self = .openFoodFacts
        case "spoonacular":
            self = .spoonacular
        case "tavily", "web":
            self = .tavily
        case "text", "text_analysis":
            self = .textAnalysis
        case "catalog":
            self = .catalog
        default:
            self = .unknown
        }
    }

    var isAIRecipe: Bool {
        self == .openAI || self == .tavily || self == .textAnalysis
    }

    var localizationKey: String? {
        switch self {
        case .openAI, .tavily, .textAnalysis:
            return "search.source.openai"
        case .openFoodFacts:
            return "search.source.openFoodFacts"
        case .spoonacular:
            return "search.source.spoonacular"
        case .catalog, .unknown:
            return nil
        }
    }
}

struct FoodProduct: Equatable, Identifiable {
    var id: UUID
    var externalId: String
    var name: String
    var brand: String?
    var kind: FoodProductKind
    var imageURL: URL?
    var calories: Double?
    var protein: Double?
    var carbs: Double?
    var fats: Double?
    var fiber: Double? = nil
    var sugar: Double? = nil
    var sodium: Double? = nil
    var amount: Double?
    var unit: String?
    var source: FoodProductSource = .unknown
    var ingredients: [String] = []
    var steps: [String] = []
    var servingSizeLabel: String? = nil
    var foodType: FoodType? = nil
    var hasCompleteNutrition: Bool? = nil

    var resolvedFoodType: FoodType? {
        foodType ?? FoodType.inferred(kind: kind, source: source,
                                      hasBrand: brand?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                                      hasSteps: !steps.isEmpty)
    }

    var hasPhoto: Bool {
        guard let imageURL else { return false }
        return !FoodImageURL.isPlaceholder(imageURL)
    }

    func mergingNutrition(from details: FoodProduct) -> FoodProduct {
        var next = details
        next.id = id
        if !externalId.isEmpty {
            next.externalId = externalId
        }
        next.kind = kind
        next.source = source == .unknown ? details.source : source
        next.foodType = foodType ?? details.foodType ?? resolvedFoodType
        if Self.prefersLocalizedDisplayName(name, over: details.name) {
            next.name = name
        }
        if let brand, !brand.isEmpty, details.brand == nil || details.brand?.isEmpty == true {
            next.brand = brand
        }
        if hasPhoto, !details.hasPhoto {
            next.imageURL = imageURL
        }
        if let servingSizeLabel, !servingSizeLabel.isEmpty,
           details.servingSizeLabel == nil || details.servingSizeLabel?.isEmpty == true {
            next.servingSizeLabel = servingSizeLabel
        }
        return next
    }

    static func prefersLocalizedDisplayName(_ current: String, over candidate: String) -> Bool {
        let left = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        if left.isEmpty { return false }
        if right.isEmpty { return true }
        if left == right { return true }
        let leftLocal = left.unicodeScalars.contains { !$0.isASCII }
        let rightLocal = right.unicodeScalars.contains { !$0.isASCII }
        return leftLocal && !rightLocal
    }
}

struct FoodSearchCatalogPage: Equatable {
    var products: [FoodProduct]
    var nextOffset: Int
    var hasMore: Bool
    var isRetryableFailure = false
}

enum FoodImageURL {
    static let thumbnailPixelWidth = 320
    static let detailPixelWidth = 960

    static func spoonacularRecipeURL(id: String?) -> URL? {
        let digits = id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber) else { return nil }
        return URL(string: "https://img.spoonacular.com/recipes/\(digits)-636x393.jpg")
    }

    static func isPlaceholder(_ url: URL) -> Bool {
        isPlaceholder(url.absoluteString)
    }

    static func isPlaceholder(_ raw: String) -> Bool {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return true }
        let file = value.split(whereSeparator: { "/?#".contains($0) }).last.map(String.init) ?? value
        let stem = file.split(separator: ".").first.map(String.init) ?? file
        if ["no", "none", "null", "unknown", "placeholder", "default", "undefined", "missing"].contains(stem) {
            return true
        }
        return value.contains("placeholder")
            || value.contains("no-image")
            || value.contains("missing-image")
            || value.contains("default-image")
            || value.contains("/no.")
            || value.contains("/none.")
            || value.contains("/null.")
            || value.contains("/unknown.")
            || value.hasSuffix("/ingredients_100x100")
            || value.hasSuffix("/ingredients_100x100/")
            || value.contains("favicon")
            || value.contains(".svg")
    }

    static func displayURL(_ url: URL, pixelWidth: Int) -> URL {
        wikimediaThumbnailURL(url, pixelWidth: snappedPixelWidth(pixelWidth)) ?? url
    }

    static func snappedPixelWidth(_ pixelWidth: Int) -> Int {
        let allowed = [160, 320, 640, 960, 1280]
        let target = max(pixelWidth, 1)
        return allowed.first(where: { $0 >= target }) ?? allowed[allowed.count - 1]
    }

    private static func wikimediaThumbnailURL(_ url: URL, pixelWidth: Int) -> URL? {
        guard url.host?.lowercased() == "upload.wikimedia.org" else { return nil }
        let parts = url.path(percentEncoded: true).split(separator: "/").map(String.init)
        guard parts.count >= 5, parts[0] == "wikipedia" else { return nil }
        let project = parts[1]
        let hashA: String
        let hashB: String
        let file: String
        if parts.count >= 7, parts[2] == "thumb" {
            hashA = parts[3]
            hashB = parts[4]
            file = parts[5]
        } else if parts.count == 5 {
            hashA = parts[2]
            hashB = parts[3]
            file = parts[4]
        } else {
            return nil
        }
        guard hashA.count == 1, hashB.count == 2, file.isEmpty == false else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "upload.wikimedia.org"
        components.percentEncodedPath =
            "/wikipedia/\(project)/thumb/\(hashA)/\(hashB)/\(file)/\(pixelWidth)px-\(file)"
        return components.url
    }
}

extension FoodProduct {
    init(recipe: Recipe) {
        self.init(
            id: recipe.id,
            externalId: recipe.catalogFoodID ?? recipe.externalId ?? recipe.id.uuidString,
            name: recipe.title,
            brand: nil,
            kind: recipe.catalogFoodKind ?? .recipe,
            imageURL: recipe.imageURL,
            calories: recipe.calories,
            protein: recipe.protein,
            carbs: recipe.carbs,
            fats: recipe.fats,
            amount: recipe.volumeMilliliters ?? recipe.weightGrams,
            unit: recipe.volumeMilliliters != nil ? "ml" : (recipe.weightGrams == nil ? nil : "g"),
            source: recipe.origin,
            ingredients: recipe.ingredients.map { $0.originalText ?? $0.name }.filter { !$0.isEmpty },
            steps: recipe.steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            foodType: recipe.foodType ?? .dish,
            hasCompleteNutrition: recipe.hasCompleteNutrition
        )
    }
}
