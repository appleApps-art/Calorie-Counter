import Foundation

final class ParseAIAssistantActionsUseCase {
    func execute(toolCalls: [AIAssistantToolCall]) -> [AIAssistantAction] {
        toolCalls.compactMap(parse(call:))
    }

    private func parse(call: AIAssistantToolCall) -> AIAssistantAction? {
        let args = call.arguments.mapValues(\.value)
        switch call.name {
        case "propose_food_log":
            return parseFoodLog(args).map(AIAssistantAction.logFood)
        case "propose_food_replace":
            return parseReplace(args).map(AIAssistantAction.replaceFood)
        case "propose_food_swap":
            return parseSwap(args).map(AIAssistantAction.swapFood)
        case "propose_meal_suggestions":
            return parseMealSuggestions(args).map(AIAssistantAction.mealSuggestions)
        case "propose_recipe_save":
            return parseRecipeSave(args).map(AIAssistantAction.saveRecipe)
        case "propose_recipe_ingredient_swap":
            return parseRecipeIngredientSwap(args).map(AIAssistantAction.swapRecipeIngredient)
        case "propose_water_log":
            return parseWater(args).map(AIAssistantAction.logWater)
        case "propose_preference_save":
            return parsePreference(args).map(AIAssistantAction.savePreference)
        default:
            return nil
        }
    }

    private func parseFoodLog(_ args: [String: Any]) -> FoodLogProposal? {
        guard let name = ToolCallValue.string(args["name"]), !name.isEmpty else { return nil }
        return FoodLogProposal(
            name: name,
            mealType: ToolCallValue.mealType(args["mealType"]),
            calories: ToolCallValue.number(args["calories"]) ?? 0,
            protein: ToolCallValue.number(args["protein"]) ?? 0,
            carbs: ToolCallValue.number(args["carbs"]) ?? 0,
            fats: ToolCallValue.number(args["fats"]) ?? 0,
            fiber: ToolCallValue.number(args["fiber"]) ?? 0,
            sugar: ToolCallValue.number(args["sugar"]) ?? 0,
            sodium: ToolCallValue.number(args["sodium"]) ?? 0,
            portionGrams: ToolCallValue.number(args["portionGrams"]),
            portionMilliliters: ToolCallValue.number(args["portionMilliliters"]),
            confidence: min(1, max(0, ToolCallValue.number(args["confidence"]) ?? 0.5)),
            notes: ToolCallValue.string(args["notes"]) ?? "",
            source: ToolCallValue.string(args["source"]) ?? "text"
        )
    }

    private func parseReplace(_ args: [String: Any]) -> FoodReplaceProposal? {
        let newItemArgs = ToolCallValue.dictionary(args["newItem"])
        guard let newItem = parseFoodLog(newItemArgs) else { return nil }
        return FoodReplaceProposal(
            targetEntryId: ToolCallValue.uuid(args["targetEntryId"]),
            targetName: ToolCallValue.string(args["targetName"]),
            targetMealType: MealType(rawValue: ToolCallValue.string(args["targetMealType"]) ?? ""),
            newItem: newItem,
            reason: ToolCallValue.string(args["reason"])
        )
    }

    private func parseSwapItem(_ args: [String: Any]) -> FoodSwapItem? {
        guard let name = ToolCallValue.string(args["name"]), !name.isEmpty else { return nil }
        return FoodSwapItem(
            name: name,
            calories: ToolCallValue.number(args["calories"]) ?? 0,
            protein: ToolCallValue.number(args["protein"]) ?? 0,
            carbs: ToolCallValue.number(args["carbs"]) ?? 0,
            fats: ToolCallValue.number(args["fats"]) ?? 0,
            portionLabel: ToolCallValue.string(args["portionLabel"])
        )
    }

    private func parseSwap(_ args: [String: Any]) -> FoodSwapProposal? {
        guard
            let original = parseSwapItem(ToolCallValue.dictionary(args["original"])),
            let alternative = parseSwapItem(ToolCallValue.dictionary(args["alternative"]))
        else {
            return nil
        }
        return FoodSwapProposal(
            original: original,
            alternative: alternative,
            savingsKcal: ToolCallValue.number(args["savingsKcal"]) ?? max(0, original.calories - alternative.calories),
            savingsNote: ToolCallValue.string(args["savingsNote"]),
            applyToEntryId: ToolCallValue.uuid(args["applyToEntryId"])
        )
    }

    private func parseMealSuggestions(_ args: [String: Any]) -> MealSuggestionsProposal? {
        let rawOptions = args["options"] as? [Any] ?? []
        let options: [MealSuggestionOption] = rawOptions.compactMap { item in
            let dict = ToolCallValue.dictionary(item)
            guard let title = ToolCallValue.string(dict["title"]), !title.isEmpty else { return nil }
            return MealSuggestionOption(
                title: title,
                summary: ToolCallValue.string(dict["summary"]) ?? "",
                calories: ToolCallValue.number(dict["calories"]) ?? 0,
                protein: ToolCallValue.number(dict["protein"]) ?? 0,
                carbs: ToolCallValue.number(dict["carbs"]) ?? 0,
                fats: ToolCallValue.number(dict["fats"]) ?? 0,
                cookTimeMinutes: ToolCallValue.number(dict["cookTimeMinutes"]),
                externalRecipeId: ToolCallValue.string(dict["externalRecipeId"]),
                ingredients: ToolCallValue.stringArray(dict["ingredients"])
            )
        }
        guard !options.isEmpty else { return nil }
        return MealSuggestionsProposal(
            mealType: ToolCallValue.mealType(args["mealType"]),
            remainingCaloriesTarget: ToolCallValue.number(args["remainingCaloriesTarget"]),
            options: options
        )
    }

    private func parseRecipeSave(_ args: [String: Any]) -> RecipeSaveProposal? {
        guard let title = ToolCallValue.string(args["title"]), !title.isEmpty else { return nil }
        return RecipeSaveProposal(
            title: title,
            summary: ToolCallValue.string(args["summary"]),
            calories: ToolCallValue.number(args["calories"]) ?? 0,
            protein: ToolCallValue.number(args["protein"]) ?? 0,
            carbs: ToolCallValue.number(args["carbs"]) ?? 0,
            fats: ToolCallValue.number(args["fats"]) ?? 0,
            cookTimeMinutes: ToolCallValue.number(args["cookTimeMinutes"]),
            externalRecipeId: ToolCallValue.string(args["externalRecipeId"]),
            ingredients: ToolCallValue.stringArray(args["ingredients"]),
            steps: ToolCallValue.stringArray(args["steps"])
        )
    }

    private func parseRecipeIngredientSwap(_ args: [String: Any]) -> RecipeIngredientSwapProposal? {
        let original = ToolCallValue.dictionary(args["originalIngredient"])
        let replacement = ToolCallValue.dictionary(args["replacement"])
        guard
            let originalName = ToolCallValue.string(original["name"]),
            let replacementName = ToolCallValue.string(replacement["name"])
        else {
            return nil
        }
        return RecipeIngredientSwapProposal(
            recipeExternalId: ToolCallValue.string(args["recipeExternalId"]),
            originalName: originalName,
            originalAmount: ToolCallValue.number(original["amount"]),
            originalUnit: ToolCallValue.string(original["unit"]),
            replacementName: replacementName,
            replacementAmount: ToolCallValue.number(replacement["amount"]),
            replacementUnit: ToolCallValue.string(replacement["unit"]),
            replacementCalories: ToolCallValue.number(replacement["calories"]),
            replacementProtein: ToolCallValue.number(replacement["protein"]),
            replacementCarbs: ToolCallValue.number(replacement["carbs"]),
            replacementFats: ToolCallValue.number(replacement["fats"]),
            updatedRecipeCalories: ToolCallValue.number(args["updatedRecipeCalories"]),
            updatedRecipeProtein: ToolCallValue.number(args["updatedRecipeProtein"]),
            updatedRecipeCarbs: ToolCallValue.number(args["updatedRecipeCarbs"]),
            updatedRecipeFats: ToolCallValue.number(args["updatedRecipeFats"]),
            reason: ToolCallValue.string(args["reason"])
        )
    }

    private func parseWater(_ args: [String: Any]) -> WaterLogProposal? {
        guard let amount = ToolCallValue.number(args["amountMilliliters"]), amount > 0 else { return nil }
        return WaterLogProposal(amountMilliliters: amount, note: ToolCallValue.string(args["note"]))
    }

    private func parsePreference(_ args: [String: Any]) -> PreferenceSaveProposal? {
        guard
            let kindRaw = ToolCallValue.string(args["kind"]),
            let kind = UserPreferenceKind(rawValue: kindRaw),
            let value = ToolCallValue.string(args["value"]),
            !value.isEmpty
        else {
            return nil
        }
        return PreferenceSaveProposal(kind: kind, value: value, note: ToolCallValue.string(args["note"]))
    }
}

final class ConfirmAIAssistantActionUseCase {
    private let logFoodUseCase: LogFoodUseCase
    private let replaceFoodEntryUseCase: ReplaceFoodEntryUseCase
    private let logWaterUseCase: LogWaterUseCase
    private let saveUserPreferenceUseCase: SaveUserPreferenceUseCase
    private let recipeRepository: RecipeRepositoryProtocol
    private let foodEntryRepository: FoodEntryRepositoryProtocol
    private let awardXPUseCase: AwardXPUseCase?

    init(
        logFoodUseCase: LogFoodUseCase,
        replaceFoodEntryUseCase: ReplaceFoodEntryUseCase,
        logWaterUseCase: LogWaterUseCase,
        saveUserPreferenceUseCase: SaveUserPreferenceUseCase,
        recipeRepository: RecipeRepositoryProtocol,
        foodEntryRepository: FoodEntryRepositoryProtocol,
        awardXPUseCase: AwardXPUseCase? = nil
    ) {
        self.logFoodUseCase = logFoodUseCase
        self.replaceFoodEntryUseCase = replaceFoodEntryUseCase
        self.logWaterUseCase = logWaterUseCase
        self.saveUserPreferenceUseCase = saveUserPreferenceUseCase
        self.recipeRepository = recipeRepository
        self.foodEntryRepository = foodEntryRepository
        self.awardXPUseCase = awardXPUseCase
    }

    func execute(_ action: AIAssistantAction) throws {
        switch action {
        case .logFood(let proposal):
            _ = try logFoodUseCase.execute(proposal.toFoodEntry())
        case .replaceFood(let proposal):
            if let targetId = proposal.targetEntryId {
                _ = try replaceFoodEntryUseCase.execute(targetId: targetId, with: proposal.newItem)
            } else if let name = proposal.targetName {
                let today = try foodEntryRepository.fetchEntries(for: Date())
                if let match = today.last(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
                    _ = try replaceFoodEntryUseCase.execute(targetId: match.id, with: proposal.newItem)
                } else {
                    _ = try logFoodUseCase.execute(proposal.newItem.toFoodEntry())
                }
            } else {
                _ = try logFoodUseCase.execute(proposal.newItem.toFoodEntry())
            }
        case .swapFood(let proposal):
            let alternative = FoodLogProposal(
                name: proposal.alternative.name,
                mealType: .snacks,
                calories: proposal.alternative.calories,
                protein: proposal.alternative.protein,
                carbs: proposal.alternative.carbs,
                fats: proposal.alternative.fats,
                fiber: 0,
                sugar: 0,
                sodium: 0,
                notes: proposal.savingsNote ?? "",
                source: "swap"
            )
            if let targetId = proposal.applyToEntryId {
                _ = try replaceFoodEntryUseCase.execute(targetId: targetId, with: alternative)
            } else {
                _ = try logFoodUseCase.execute(alternative.toFoodEntry())
                try awardXPUseCase?.execute(kind: .foodSwap)
            }
        case .mealSuggestions:
            break
        case .saveRecipe(let proposal):
            try recipeRepository.save(proposal.toRecipe())
        case .swapRecipeIngredient(let proposal):
            try applyRecipeIngredientSwap(proposal)
        case .logWater(let proposal):
            _ = try logWaterUseCase.execute(amountMilliliters: proposal.amountMilliliters)
        case .savePreference(let proposal):
            _ = try saveUserPreferenceUseCase.execute(kind: proposal.kind, value: proposal.value, note: proposal.note)
        }
    }

    func executeMealSuggestion(_ option: MealSuggestionOption, mealType: MealType) throws {
        let proposal = FoodLogProposal(
            name: option.title,
            mealType: mealType,
            calories: option.calories,
            protein: option.protein,
            carbs: option.carbs,
            fats: option.fats,
            fiber: 0,
            sugar: 0,
            sodium: 0,
            notes: option.summary,
            source: "suggestion"
        )
        _ = try logFoodUseCase.execute(proposal.toFoodEntry())
    }

    private func applyRecipeIngredientSwap(_ proposal: RecipeIngredientSwapProposal) throws {
        guard let externalId = proposal.recipeExternalId, !externalId.isEmpty else {
            throw AIAssistantActionError.recipeNotFound
        }
        guard let recipe = try recipeRepository.fetchSaved(externalId: externalId) else {
            throw AIAssistantActionError.recipeNotSaved
        }
        let updated = ApplyRecipeIngredientSwapUseCase.execute(recipe: recipe, proposal: proposal)
        try recipeRepository.save(updated)
        try awardXPUseCase?.execute(kind: .foodSwap)
    }
}

enum AIAssistantActionError: LocalizedError {
    case recipeNotFound
    case recipeNotSaved

    var errorDescription: String? {
        switch self {
        case .recipeNotFound:
            return L10n.tr("ai.error.recipeMissing")
        case .recipeNotSaved:
            return L10n.tr("ai.error.recipeNotSaved")
        }
    }
}
