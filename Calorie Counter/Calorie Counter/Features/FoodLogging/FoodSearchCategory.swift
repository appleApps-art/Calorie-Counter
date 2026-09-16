import Foundation

enum FoodSearchPhase: Equatable {
    case browse
    case results
}

enum FoodSearchCategory: String, CaseIterable, Equatable {
    case recent
    case preparedMeals
    case products
    case vegetablesGreens
    case fruitsBerries
    case meatPoultry
    case fishSeafood
    case dairyEggs
    case grainsCereals
    case beverages
    case chosenForYou
    case healthyBreakfast
    case quickLunch
    case dinnerTime
    case mainMeal
    case mexican
    case italian
    case greek
    case asian

    static let productCategories: [FoodSearchCategory] = [
        .vegetablesGreens, .fruitsBerries, .meatPoultry, .fishSeafood, .dairyEggs, .grainsCereals, .beverages
    ]

    static var mealCategories: [FoodSearchCategory] {
        RecipeBrowseSectionKind.catalogSections.compactMap { FoodSearchCategory(rawValue: $0.rawValue) }
    }

    var recipeSection: RecipeBrowseSectionKind? { RecipeBrowseSectionKind(rawValue: rawValue) }

    var titleKey: String { recipeSection?.titleKey ?? "search.category.\(rawValue)" }

    var catalogTag: String {
        switch self {
        case .recent, .preparedMeals, .products,
             .chosenForYou, .healthyBreakfast, .quickLunch, .dinnerTime, .mainMeal, .mexican, .italian, .greek, .asian:
            return rawValue
        case .vegetablesGreens: return "en:vegetables"
        case .fruitsBerries: return "en:fruits"
        case .meatPoultry: return "en:meats"
        case .fishSeafood: return "en:fishes"
        case .dairyEggs: return "en:dairies"
        case .grainsCereals: return "en:breakfast-cereals"
        case .beverages: return "en:beverages"
        }
    }

    var query: String {
        switch self {
        case .recent, .preparedMeals, .products: return ""
        case .chosenForYou, .healthyBreakfast, .quickLunch, .dinnerTime, .mainMeal, .mexican, .italian, .greek, .asian:
            return recipeSection?.query ?? ""
        case .vegetablesGreens: return "spinach"
        case .fruitsBerries: return "blueberry"
        case .meatPoultry: return "chicken"
        case .fishSeafood: return "salmon"
        case .dairyEggs: return "yogurt"
        case .grainsCereals: return "oats"
        case .beverages: return "coffee"
        }
    }
}

struct FoodSearchBrowseSection: Equatable {
    let category: FoodSearchCategory
    let items: [FoodSearchItem]
    var isLoading = false
    var loadFailed = false

    var showsMore: Bool { category != .recent }
}

enum FoodSearchScope: Int, CaseIterable {
    case all
    case products
    case meals

    var titleKey: String {
        switch self {
        case .all: return "search.scope.all"
        case .products: return "search.scope.products"
        case .meals: return "search.scope.meals"
        }
    }

    func includes(_ product: FoodProduct) -> Bool {
        switch self {
        case .all: return true
        case .products: return product.resolvedFoodType == .product
        case .meals: return product.resolvedFoodType == .dish
        }
    }
}
