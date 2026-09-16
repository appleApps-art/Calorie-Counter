import Foundation

enum MealPlanMapper {
    private struct StoredPlan: Codable {
        var recipes: [RecipeDTO]
        var dayLayouts: [Int]?
        var mealTypeKeys: [String]?
    }

    private struct RecipeDTO: Codable {
        var id: UUID
        var externalId: String?
        var title: String
        var summary: String?
        var imageURLString: String?
        var readyInMinutes: Int?
        var servings: Int?
        var weightGrams: Double?
        var volumeMilliliters: Double?
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fats: Double?
        var sourceName: String?
        var origin: String?
        var foodType: FoodType?
        var hasCompleteNutrition: Bool?
        var ingredients: [IngredientDTO]
        var steps: [String]
    }

    private struct IngredientDTO: Codable {
        var id: String
        var name: String
        var amount: Double?
        var unit: String?
        var originalText: String?
    }

    static func map(_ object: CDMealPlan) -> MealPlan? {
        guard let id = object.id, let title = object.title, let createdAt = object.createdAt else { return nil }
        let stored = decodePlan(object.recipesJSON)
        return MealPlan(
            id: id,
            title: title,
            weeks: max(1, Int(object.weeks)),
            imageURL: object.imageURLString.flatMap(URL.init(string:)),
            recipes: stored.recipes.map(mapRecipe),
            createdAt: createdAt,
            dayLayouts: stored.dayLayouts ?? [],
            mealTypeKeys: stored.mealTypeKeys ?? []
        )
    }

    static func apply(_ plan: MealPlan, to object: CDMealPlan) {
        object.id = plan.id
        object.title = plan.title
        object.weeks = Int32(max(1, plan.weeks))
        object.imageURLString = plan.imageURL?.absoluteString
        object.createdAt = plan.createdAt
        object.recipesJSON = encodePlan(plan)
    }

    private static func decodePlan(_ json: String?) -> StoredPlan {
        guard let json, let data = json.data(using: .utf8) else {
            return StoredPlan(recipes: [], dayLayouts: nil, mealTypeKeys: nil)
        }
        if let stored = try? JSONDecoder().decode(StoredPlan.self, from: data) {
            return stored
        }
        let recipes = (try? JSONDecoder().decode([RecipeDTO].self, from: data)) ?? []
        return StoredPlan(recipes: recipes, dayLayouts: nil, mealTypeKeys: nil)
    }

    private static func encodePlan(_ plan: MealPlan) -> String {
        let stored = StoredPlan(
            recipes: plan.recipes.map(mapDTO),
            dayLayouts: plan.dayLayouts.isEmpty ? nil : plan.dayLayouts,
            mealTypeKeys: plan.mealTypeKeys.isEmpty ? nil : plan.mealTypeKeys
        )
        guard let data = try? JSONEncoder().encode(stored),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    private static func mapRecipe(_ dto: RecipeDTO) -> Recipe {
        Recipe(
            id: dto.id,
            externalId: dto.externalId,
            title: dto.title,
            summary: dto.summary,
            imageURL: dto.imageURLString.flatMap(URL.init(string:)),
            readyInMinutes: dto.readyInMinutes,
            servings: dto.servings,
            calories: dto.calories,
            protein: dto.protein,
            carbs: dto.carbs,
            fats: dto.fats,
            ingredients: dto.ingredients.map {
                RecipeIngredient(
                    id: $0.id,
                    name: $0.name,
                    amount: $0.amount,
                    unit: $0.unit,
                    originalText: $0.originalText
                )
            },
            steps: dto.steps,
            sourceName: dto.sourceName,
            origin: FoodProductSource(apiValue: dto.origin),
            weightGrams: dto.weightGrams,
            volumeMilliliters: dto.volumeMilliliters,
            foodType: dto.foodType,
            hasCompleteNutrition: dto.hasCompleteNutrition
        )
    }

    private static func mapDTO(_ recipe: Recipe) -> RecipeDTO {
        RecipeDTO(
            id: recipe.id,
            externalId: recipe.externalId,
            title: recipe.title,
            summary: recipe.summary,
            imageURLString: recipe.imageURL?.absoluteString,
            readyInMinutes: recipe.readyInMinutes,
            servings: recipe.servings,
            weightGrams: recipe.weightGrams,
            volumeMilliliters: recipe.volumeMilliliters,
            calories: recipe.calories,
            protein: recipe.protein,
            carbs: recipe.carbs,
            fats: recipe.fats,
            sourceName: recipe.sourceName,
            origin: recipe.origin.rawValue,
            foodType: recipe.foodType,
            hasCompleteNutrition: recipe.hasCompleteNutrition,
            ingredients: recipe.ingredients.map {
                IngredientDTO(
                    id: $0.id,
                    name: $0.name,
                    amount: $0.amount,
                    unit: $0.unit,
                    originalText: $0.originalText
                )
            },
            steps: recipe.steps
        )
    }
}
