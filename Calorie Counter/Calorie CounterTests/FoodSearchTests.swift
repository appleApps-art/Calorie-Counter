import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class FoodSearchTests: XCTestCase {
    func testFoodProductSourceMapsAPIValues() {
        XCTAssertEqual(FoodProductSource(apiValue: "ai"), .openAI)
        XCTAssertEqual(FoodProductSource(apiValue: "openai"), .openAI)
        XCTAssertEqual(FoodProductSource(apiValue: "openfoodfacts"), .openFoodFacts)
        XCTAssertEqual(FoodProductSource(apiValue: "spoonacular"), .spoonacular)
        XCTAssertEqual(FoodProductSource(apiValue: "catalog"), .catalog)
        XCTAssertTrue(FoodProductSource(apiValue: "ai").isAIRecipe)
        XCTAssertFalse(FoodProductSource(apiValue: "openfoodfacts").isAIRecipe)
        XCTAssertFalse(FoodProductSource.catalog.isAIRecipe)
        XCTAssertNil(FoodProductSource.catalog.localizationKey)
    }

    func testOpenFoodFactsPrefersLocalizedProductName() {
        XCTAssertEqual(
            OpenFoodFactsLocalizedName.pick(
                productName: "Jogurt",
                productNameEn: "Yogurt",
                productNameUk: "Йогурт",
                locale: "uk-UA"
            ),
            "Йогурт"
        )
        XCTAssertEqual(
            OpenFoodFactsLocalizedName.pick(
                productName: "Jogurt",
                productNameEn: "Yogurt",
                productNameUk: "Йогурт",
                locale: "en-US"
            ),
            "Jogurt"
        )
        XCTAssertEqual(
            OpenFoodFactsLocalizedName.pick(
                productName: "Yogurt",
                productNameEn: "Yogurt",
                productNameUk: nil,
                locale: "uk"
            ),
            "Yogurt"
        )
    }

    func testBundledFoodSearchCatalogHasBrowsePhotos() throws {
        let url = try XCTUnwrap(
            Bundle(for: AIFoodSearchService.self).url(forResource: "food-search-catalog", withExtension: "json")
        )
        let mapped = AIFoodSearchService.decodeCatalog(from: try Data(contentsOf: url), locale: "uk")
        XCTAssertEqual(Set(mapped.keys), Set(FoodSearchCategory.productCategories.map(\.rawValue)))
        for category in FoodSearchCategory.productCategories {
            let photos = (mapped[category.rawValue] ?? []).filter(\.hasPhoto)
            XCTAssertGreaterThanOrEqual(photos.count, 4, category.rawValue)
            XCTAssertFalse(photos[0].name.isEmpty)
        }
    }

    func testDecodeRawBilingualCatalogFile() {
        let mapped = AIFoodSearchService.decodeCatalog(
            from: Data(Self.bilingualCatalogFixture.utf8),
            locale: "uk"
        )
        XCTAssertEqual(mapped["vegetablesGreens"]?.map(\.externalId), ["catalog.spinach"])
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.name, "Шпинат")
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.servingSizeLabel, "1 чашка (30 г)")
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.source, .catalog)
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.calories, 7)
        XCTAssertEqual(
            mapped["vegetablesGreens"]?.first?.imageURL,
            URL(string: "https://upload.wikimedia.org/wikipedia/commons/3/37/Spinacia_oleracea_Spinazie_bloeiend.jpg")
        )
    }

    func testSpoonacularDishTitlesAreNotListingPages() {
        XCTAssertFalse(Recipe(
            id: UUID(),
            title: "Chicken Parmesan",
            ingredients: [],
            steps: []
        ).looksLikeListingPage)
        XCTAssertFalse(Recipe(
            id: UUID(),
            title: "Курячий пармезан",
            ingredients: [],
            steps: []
        ).looksLikeListingPage)
        XCTAssertTrue(Recipe(
            id: UUID(),
            title: "Грецькі рецепти",
            ingredients: [],
            steps: []
        ).looksLikeListingPage)
    }

    func testSpoonacularRecipeIdBuildsCDNURL() {
        XCTAssertEqual(
            FoodImageURL.spoonacularRecipeURL(id: "715538")?.absoluteString,
            "https://img.spoonacular.com/recipes/715538-636x393.jpg"
        )
        XCTAssertNil(FoodImageURL.spoonacularRecipeURL(id: "ai-123"))
        XCTAssertNil(FoodImageURL.spoonacularRecipeURL(id: ""))
    }

    func testSpoonacularRecipeWithoutAPIPhotoUsesCDNFallback() throws {
        let item = try JSONDecoder().decode(AIFoodSearchItem.self, from: Data("""
        {"source":"spoonacular","kind":"recipe","externalId":"715538","title":"Ratatouille"}
        """.utf8))
        let recipe = AIFoodSearchService.mapRecipe(item)
        XCTAssertEqual(recipe?.title, "Ratatouille")
        XCTAssertEqual(
            recipe?.imageURL?.absoluteString,
            "https://img.spoonacular.com/recipes/715538-636x393.jpg"
        )
        XCTAssertTrue(recipe?.isSearchableRecipe ?? false)
    }

    func testSearchRecipesKeepsCatalogDishesWithPhotos() async throws {
        let ai = FakeAIFoodSearch()
        ai.recipes = [
            Recipe(
                id: UUID(),
                externalId: "715538",
                title: "Pasta recipes",
                imageURL: URL(string: "https://img.spoonacular.com/recipes/1-636x393.jpg"),
                ingredients: [],
                steps: [],
                origin: .spoonacular
            )
        ]
        let useCase = SearchRecipesUseCase(
            spoonacularService: FakeSpoonacular(),
            aiFoodSearchService: ai
        )
        let recipes = try await useCase.execute(query: "pasta")
        XCTAssertEqual(recipes.map(\.title), ["Pasta recipes"])
    }

    func testRelatedRecipesVerifyCatalogDetailsAndRejectTitleOnlyAIFallback() async throws {
        let catalog = FakeSpoonacular()
        let ai = FakeAIFoodSearch()
        let yogurt = RecipeIngredient(id: "y", name: "йогурту", amount: 100, unit: "г")
        let oats = RecipeIngredient(id: "o", name: "вівсянка", amount: 50, unit: "г")
        catalog.recipes = [Recipe(id: UUID(), externalId: "42", title: "Йогурт у назві",
                                  ingredients: [yogurt], steps: ["Mix"], origin: .spoonacular)]
        catalog.detailedRecipe = Recipe(id: UUID(), externalId: "42", title: "Actual recipe", calories: 180, protein: 8, carbs: 24, fats: 6,
                                       ingredients: [oats], steps: ["Cook"], origin: .spoonacular)
        ai.recipes = [Recipe(id: UUID(), title: "Йогурт", calories: 180, protein: 8, carbs: 24, fats: 6, ingredients: [oats], steps: ["Add yogurt"]),
                      Recipe(id: UUID(), title: "Боул", calories: 180, protein: 8, carbs: 24, fats: 6, ingredients: [yogurt, oats], steps: ["Mix"], origin: .spoonacular)]
        let useCase = SearchRecipesUseCase(spoonacularService: catalog, aiFoodSearchService: ai)
        let result = try await useCase.recipes(containing: "йогурт")
        XCTAssertEqual(result.map(\.title), ["Боул"])
        XCTAssertEqual(catalog.recipeDetailsCalls, 1)
        XCTAssertEqual(ai.searchRecipeCalls, 1)
        XCTAssertEqual(result.first?.ingredients, [yogurt, oats])
    }

    func testRelatedRecipesReturnVerifiedCatalogAndDoNotInventMissingIngredient() async throws {
        let catalog = FakeSpoonacular()
        let ai = FakeAIFoodSearch()
        catalog.recipes = [Recipe(id: UUID(), externalId: "42", title: "Bowl", calories: 180, protein: 8, carbs: 24, fats: 6, ingredients: [], steps: [], origin: .spoonacular)]
        catalog.detailedRecipe = Recipe(id: UUID(), externalId: "42", title: "Bowl", calories: 180, protein: 8, carbs: 24, fats: 6, ingredients: [
            RecipeIngredient(id: "y", name: "Greek yogurt", amount: 100, unit: "g")
        ], steps: ["Mix"], origin: .spoonacular)
        let useCase = SearchRecipesUseCase(spoonacularService: catalog, aiFoodSearchService: ai)
        let matches = try await useCase.recipes(containing: "Greek yogurt")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.ingredients, catalog.detailedRecipe?.ingredients)
        XCTAssertEqual(ai.searchRecipeCalls, 0)
        let missing = try await useCase.recipes(containing: "apple")
        XCTAssertTrue(missing.isEmpty)
    }

    func testIngredientVerificationRequiresWholeWordsAndAllQualifiers() {
        func recipe(_ names: [String]) -> Recipe {
            Recipe(id: UUID(), title: "Egg", ingredients: names.map {
                RecipeIngredient(id: $0, name: $0, amount: 1, unit: nil)
            }, steps: ["Egg"])
        }
        XCTAssertFalse(SearchRecipesUseCase.containsIngredient("egg", in: recipe(["eggplant"])))
        XCTAssertFalse(SearchRecipesUseCase.containsIngredient("Greek yogurt", in: recipe(["Greek olives", "coconut yogurt"])))
        XCTAssertFalse(SearchRecipesUseCase.containsIngredient("йогурт", in: recipe(["соус без йогурту"])))
        XCTAssertTrue(SearchRecipesUseCase.containsIngredient("йогурт", in: recipe(["йогурт без цукру"])))
        XCTAssertTrue(SearchRecipesUseCase.containsIngredient("egg", in: recipe(["2 eggs"])))
        XCTAssertTrue(SearchRecipesUseCase.containsIngredient("яйце", in: recipe(["яйця"])))
        XCTAssertTrue(SearchRecipesUseCase.containsIngredient("грецький йогурт", in: recipe(["грецького йогурту"])))
        XCTAssertFalse(SearchRecipesUseCase.containsIngredient("egg", in: recipe([])))
    }

    func testGenerateRecipesKeepsRecipesWithoutPhotos() async throws {
        let ai = FakeAIFoodSearch()
        ai.recipes = [
            Recipe(
                id: UUID(),
                title: "Pantry Omelette",
                ingredients: [],
                steps: []
            )
        ]
        let useCase = SearchRecipesUseCase(
            spoonacularService: FakeSpoonacular(),
            aiFoodSearchService: ai
        )
        let catalog = try await useCase.execute(query: "omelette")
        XCTAssertTrue(catalog.isEmpty)
        let generated = try await useCase.generateRecipes(query: "omelette", filters: .empty)
        XCTAssertEqual(generated.map(\.title), ["Pantry Omelette"])
    }

    func testDecodeRecipeSectionsPayloadMapsKnownKinds() {
        let sections = RecipeSectionsService.decodeSections(from: Data(Self.recipeSectionsFixture.utf8))
        XCTAssertEqual(sections.map(\.id), [.healthyBreakfast])
        XCTAssertEqual(sections[0].recipes.map(\.title), ["Oatmeal"])
        XCTAssertEqual(sections[0].recipes.first?.calories, 320)
        XCTAssertEqual(sections[0].recipes.first?.readyInMinutes, 10)
        XCTAssertEqual(sections[0].recipes.first?.origin, .spoonacular)
    }

    func testDecodeRecipeSectionsDropsDuplicateKinds() {
        let sections = RecipeSectionsService.decodeSections(from: Data(Self.duplicateCuisineSectionsFixture.utf8))
        XCTAssertEqual(sections.map(\.id), [.greek, .asian])
        XCTAssertEqual(sections[0].recipes.map(\.title), ["Gyro"])
        XCTAssertEqual(sections[1].recipes.map(\.title), ["Pad Thai"])
    }

    func testRecipeCardCalorieBadgeUsesAvailableCalories() {
        XCTAssertEqual(
            RecipesViewModel.calorieBadgeText(for: Recipe(
                id: UUID(),
                title: "Oatmeal",
                readyInMinutes: 10,
                calories: 320,
                ingredients: [],
                steps: []
            )),
            L10n.format("recipes.kcal", 320)
        )
        XCTAssertNil(
            RecipesViewModel.calorieBadgeText(for: Recipe(
                id: UUID(),
                title: "Oatmeal",
                readyInMinutes: 10,
                calories: 0,
                ingredients: [],
                steps: []
            ))
        )
        XCTAssertEqual(
            RecipesViewModel.calorieBadgeText(for: Recipe(
                id: UUID(),
                title: "Oatmeal",
                calories: 320,
                ingredients: [],
                steps: []
            )),
            L10n.format("recipes.kcal", 320)
        )
        XCTAssertNil(
            RecipesViewModel.calorieBadgeText(for: Recipe(
                id: UUID(),
                title: "Oatmeal",
                ingredients: [],
                steps: []
            ))
        )
    }

    func testWikimediaDisplayURLUsesThumbnailSize() {
        let original = URL(
            string: "https://upload.wikimedia.org/wikipedia/commons/3/37/Spinacia_oleracea_Spinazie_bloeiend.jpg"
        )!
        XCTAssertEqual(
            FoodImageURL.displayURL(original, pixelWidth: 120),
            URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/3/37/Spinacia_oleracea_Spinazie_bloeiend.jpg/160px-Spinacia_oleracea_Spinazie_bloeiend.jpg")
        )

        let existingThumb = URL(
            string: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ad/Cooked_shrimp.jpg/960px-Cooked_shrimp.jpg"
        )!
        XCTAssertEqual(
            FoodImageURL.displayURL(existingThumb, pixelWidth: 320),
            URL(string: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/ad/Cooked_shrimp.jpg/320px-Cooked_shrimp.jpg")
        )

        let encoded = URL(
            string: "https://upload.wikimedia.org/wikipedia/commons/2/2c/Wei%C3%9Fbrot-1.jpg"
        )!
        XCTAssertEqual(
            FoodImageURL.displayURL(encoded, pixelWidth: 320).absoluteString,
            "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Wei%C3%9Fbrot-1.jpg/320px-Wei%C3%9Fbrot-1.jpg"
        )

        let generated = URL(string: "https://assistant.chatte.workers.dev/v1/generated-images/1")!
        XCTAssertEqual(FoodImageURL.displayURL(generated, pixelWidth: 320), generated)

        let spoonacular = URL(string: "https://img.spoonacular.com/recipes/yogurt.jpg")!
        XCTAssertEqual(FoodImageURL.displayURL(spoonacular, pixelWidth: 320), spoonacular)
    }

    func testDecodeCatalogPayloadMapsLocalizedItems() {
        let mapped = AIFoodSearchService.decodeCatalog(from: Data(Self.catalogFixture.utf8))
        XCTAssertEqual(mapped["vegetablesGreens"]?.map(\.externalId), ["catalog.spinach"])
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.name, "Spinach")
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.servingSizeLabel, "1 cup (30 g)")
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.calories, 7)
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.source, .catalog)
    }

    func testDecodeSpoonacularCatalogPayloadMapsIngredients() {
        let mapped = AIFoodSearchService.decodeCatalog(from: Data(Self.spoonacularCatalogFixture.utf8))
        XCTAssertEqual(mapped["vegetablesGreens"]?.map(\.externalId), ["1145"])
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.name, "broccoli")
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.kind, .ingredient)
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.source, .spoonacular)
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.amount, 100)
        XCTAssertEqual(mapped["vegetablesGreens"]?.first?.unit, "g")
        XCTAssertEqual(
            mapped["vegetablesGreens"]?.first?.imageURL,
            URL(string: "https://img.spoonacular.com/ingredients_250x250/broccoli.jpg")
        )
    }

    func testDecodePelmeniPayloadMapsAIRecipesFirst() {
        let items = AIFoodSearchService.decodeItems(from: Data(Self.pelmeniFixture.utf8))
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items[0].externalId, "ai-1")
        XCTAssertEqual(items[0].kind, "recipe")
        XCTAssertEqual(items[0].title, "Домашні пельмені зі свининою та яловичиною")
        XCTAssertEqual(items[0].calories, 520)
        XCTAssertEqual(items[0].serving, "1 порція (180 г)")
        XCTAssertEqual(items[0].steps, ["Замісити тісто", "Зліпити пельмені", "Варити 8 хвилин"])
        XCTAssertEqual(items[0].imageURL, "https://assistant.chatte.workers.dev/v1/generated-images/1")
        XCTAssertEqual(items[3].kind, "product")
        XCTAssertEqual(items[3].name, "Пельмені")
        XCTAssertEqual(items[3].calories, 237)
    }

    func testMapFoodKeepsAIServingAndCalories() {
        let items = AIFoodSearchService.decodeItems(from: Data(Self.pelmeniFixture.utf8))
        let product = AIFoodSearchService.mapFood(items[0])
        XCTAssertEqual(product?.servingSizeLabel, "1 порція (180 г)")
        XCTAssertEqual(product?.calories, 520)
        XCTAssertEqual(product?.fiber, 3)
        XCTAssertEqual(product?.sugar, 5)
        XCTAssertEqual(product?.sodium, 780)
        let line = FoodSearchItem.detailLine(for: product!)
        XCTAssertTrue(line.hasPrefix("1 порція (180 г) · "))
        XCTAssertTrue(line.contains("520"))
    }

    func testSearchDetailLineUsesServingThenKcal() {
        let product = FoodProduct(
            id: UUID(),
            externalId: "ai-yogurt",
            name: "Yogurt",
            brand: nil,
            kind: .recipe,
            imageURL: nil,
            calories: 90,
            protein: 16,
            carbs: 7,
            fats: 0,
            amount: 1,
            unit: "serving",
            source: .tavily,
            servingSizeLabel: "1 cup (227g)"
        )
        let line = FoodSearchItem.detailLine(for: product)
        XCTAssertTrue(line.hasPrefix("1 cup (227g) · "))
        XCTAssertTrue(line.contains("90"))
    }

    func testMergingNutritionKeepsLocalizedSearchName() {
        let search = FoodProduct(
            id: UUID(),
            externalId: "1",
            name: "Молоко",
            brand: nil,
            kind: .product,
            imageURL: URL(string: "https://img.example.com/milk.jpg"),
            calories: nil,
            protein: nil,
            carbs: nil,
            fats: nil,
            amount: nil,
            unit: nil,
            source: .spoonacular
        )
        let details = FoodProduct(
            id: UUID(),
            externalId: "99",
            name: "Milk",
            brand: "Dairy",
            kind: .product,
            imageURL: nil,
            calories: 60,
            protein: 3,
            carbs: 5,
            fats: 3,
            amount: 100,
            unit: "g",
            source: .spoonacular
        )
        let merged = search.mergingNutrition(from: details)
        XCTAssertEqual(merged.id, search.id)
        XCTAssertEqual(merged.externalId, "1")
        XCTAssertEqual(merged.name, "Молоко")
        XCTAssertEqual(merged.calories, 60)
        XCTAssertEqual(merged.brand, "Dairy")
        XCTAssertEqual(merged.imageURL, search.imageURL)
    }

    func testMergingNutritionUsesLocalizedDetailsName() {
        let search = FoodProduct(
            id: UUID(),
            externalId: "1",
            name: "Milk",
            brand: nil,
            kind: .product,
            imageURL: nil,
            calories: nil,
            protein: nil,
            carbs: nil,
            fats: nil,
            amount: nil,
            unit: nil,
            source: .spoonacular
        )
        let details = FoodProduct(
            id: UUID(),
            externalId: "1",
            name: "Молоко",
            brand: nil,
            kind: .product,
            imageURL: nil,
            calories: 60,
            protein: 3,
            carbs: 5,
            fats: 3,
            amount: 100,
            unit: "g",
            source: .spoonacular
        )
        XCTAssertEqual(search.mergingNutrition(from: details).name, "Молоко")
        XCTAssertEqual(search.mergingNutrition(from: details).calories, 60)
    }

    func testAttachProductPhotosKeepsUkrainianNameWhenCatalogIsEnglish() async {
        let spoonacular = FakeSpoonacular()
        spoonacular.ingredients = [
            FoodProduct(
                id: UUID(),
                externalId: "11529",
                name: "Tomato",
                brand: nil,
                kind: .ingredient,
                imageURL: URL(string: "https://img.spoonacular.com/ingredients_100x100/tomato.jpg"),
                calories: 18,
                protein: 1,
                carbs: 4,
                fats: 0,
                amount: 100,
                unit: "g",
                source: .spoonacular
            )
        ]
        let result = await makeUseCase(spoonacular: spoonacular).attachProductPhotos(
            to: [makePantryItem(name: "Помідор")]
        )
        XCTAssertEqual(result[0].name, "Помідор")
        XCTAssertEqual(
            result[0].imageURL,
            URL(string: "https://img.spoonacular.com/ingredients_250x250/tomato.jpg")
        )
    }

    func testAttachProductPhotosUsesLocalizedCatalogNameWhenScanNameIsEnglish() async {
        let spoonacular = FakeSpoonacular()
        spoonacular.ingredients = [
            FoodProduct(
                id: UUID(),
                externalId: "11529",
                name: "Помідор",
                brand: nil,
                kind: .ingredient,
                imageURL: URL(string: "https://img.spoonacular.com/ingredients_100x100/tomato.jpg"),
                calories: 18,
                protein: 1,
                carbs: 4,
                fats: 0,
                amount: 100,
                unit: "g",
                source: .spoonacular
            )
        ]
        let result = await makeUseCase(spoonacular: spoonacular).attachProductPhotos(
            to: [makePantryItem(name: "ripe red tomatoes")]
        )
        XCTAssertEqual(result[0].name, "Помідор")
        XCTAssertNotNil(result[0].imageURL)
    }

    func testAttachProductPhotosIgnoresADifferentProductThatSharesAWord() async {
        let spoonacular = FakeSpoonacular()
        spoonacular.ingredients = [
            FoodProduct(
                id: UUID(),
                externalId: "9000",
                name: "Виноградний сік",
                brand: nil,
                kind: .ingredient,
                imageURL: URL(string: "https://img.spoonacular.com/ingredients_100x100/grape-juice.jpg"),
                calories: 60,
                protein: 0,
                carbs: 15,
                fats: 0,
                amount: 100,
                unit: "g",
                source: .spoonacular
            )
        ]
        let result = await makeUseCase(spoonacular: spoonacular).attachProductPhotos(
            to: [makePantryItem(name: "Яблучний сік")]
        )
        XCTAssertNil(result[0].imageURL)
        XCTAssertEqual(result[0].name, "Яблучний сік")
    }

    func testAttachProductPhotosMatchesTheSameProductInAnotherWordOrder() async {
        let spoonacular = FakeSpoonacular()
        spoonacular.ingredients = [
            FoodProduct(
                id: UUID(),
                externalId: "9001",
                name: "Сік яблучний",
                brand: nil,
                kind: .ingredient,
                imageURL: URL(string: "https://img.spoonacular.com/ingredients_100x100/apple-juice.jpg"),
                calories: 46,
                protein: 0,
                carbs: 11,
                fats: 0,
                amount: 100,
                unit: "g",
                source: .spoonacular
            )
        ]
        let result = await makeUseCase(spoonacular: spoonacular).attachProductPhotos(
            to: [makePantryItem(name: "Яблучний сік")]
        )
        XCTAssertEqual(
            result[0].imageURL,
            URL(string: "https://img.spoonacular.com/ingredients_250x250/apple-juice.jpg")
        )
    }

    func testDecodeDetailsPayloadMapsFullNutrition() throws {
        let decoded = try JSONDecoder().decode(AIFoodDetailsResponse.self, from: Data(Self.detailsFixture.utf8))
        let product = AIFoodSearchService.mapFood(decoded.item!)
        XCTAssertEqual(product?.name, "Greek yogurt")
        XCTAssertEqual(product?.servingSizeLabel, "1 cup (227 g)")
        XCTAssertEqual(product?.calories, 90)
        XCTAssertEqual(product?.protein, 16)
        XCTAssertEqual(product?.fiber, 2)
        XCTAssertEqual(product?.sugar, 8)
        XCTAssertEqual(product?.sodium, 120)
        XCTAssertEqual(product?.ingredients, ["Greek yogurt 227 g", "honey 10 g"])
        XCTAssertEqual(product?.steps, ["Spoon yogurt into a bowl", "Drizzle honey"])
        XCTAssertEqual(
            product?.imageURL,
            URL(string: "https://img.spoonacular.com/recipes/yogurt.jpg")
        )
    }

    func testUseCaseEnrichDetailsReturnsFullCard() async throws {
        let ai = FakeAIFoodSearch()
        ai.detailsProduct = FoodProduct(
            id: UUID(),
            externalId: "tavily-1",
            name: "Greek yogurt",
            brand: nil,
            kind: .recipe,
            imageURL: URL(string: "https://img.spoonacular.com/recipes/yogurt.jpg"),
            calories: 90,
            protein: 16,
            carbs: 7,
            fats: 0,
            fiber: 2,
            sugar: 8,
            sodium: 120,
            amount: 1,
            unit: "serving",
            source: .tavily,
            ingredients: ["Greek yogurt 227 g"],
            steps: ["Spoon yogurt into a bowl"],
            servingSizeLabel: "1 cup (227 g)"
        )
        let product = try await makeUseCase(ai: ai).enrichDetails(
            title: "Greek yogurt",
            imageURL: nil,
            source: "tavily",
            kind: "recipe"
        )
        XCTAssertEqual(product?.calories, 90)
        XCTAssertEqual(product?.fiber, 2)
        XCTAssertEqual(product?.ingredients, ["Greek yogurt 227 g"])
        XCTAssertEqual(product?.servingSizeLabel, "1 cup (227 g)")
    }

    func testUseCaseKeepsUnifiedResults() async throws {
        let ai = FakeAIFoodSearch()
        ai.foods = [
            Self.product(id: "ai-1", name: "Пельмені AI", kind: .recipe),
            Self.product(id: "477", name: "Пельмені OFF", kind: .product)
        ]
        let off = FakeOpenFoodFacts()
        off.products = [Self.product(id: "477", name: "Пельмені OFF", kind: .product)]
        let results = try await makeUseCase(ai: ai, off: off).execute(query: "пельмені")
        XCTAssertEqual(results.map(\.externalId), ["ai-1", "477"])
    }

    func testUseCaseMergesOpenFoodFactsWhenUnifiedHasSpoonacular() async throws {
        let ai = FakeAIFoodSearch()
        ai.foods = [
            Self.product(id: "ai-1", name: "Пельмені AI", kind: .recipe),
            Self.product(
                id: "991",
                name: "Pelmeni Mix",
                kind: .product,
                source: .spoonacular,
                imageURL: URL(string: "https://img.spoonacular.com/recipes/pelmeni.jpg")
            )
        ]
        let off = FakeOpenFoodFacts()
        off.products = [Self.product(id: "off-1", name: "Пельмені Рудь", kind: .product)]
        let results = try await makeUseCase(ai: ai, off: off).execute(query: "пельмені")
        XCTAssertEqual(results.map(\.externalId), ["ai-1", "off-1", "991"])
        XCTAssertEqual(results.map(\.source), [.openAI, .openFoodFacts, .spoonacular])
    }

    func testUseCaseFallsBackToOpenFoodFactsWhenUnifiedFails() async throws {
        let ai = FakeAIFoodSearch()
        ai.error = FoodPhotoAnalysisError.invalidResponse
        let off = FakeOpenFoodFacts()
        off.products = [Self.product(id: "off-1", name: "Пельмені Рудь", kind: .product)]
        let results = try await makeUseCase(ai: ai, off: off).execute(query: "пельмені")
        XCTAssertEqual(results.map(\.externalId), ["off-1"])
        XCTAssertEqual(off.calls, 1)
    }

    func testUseCaseFallsBackToOpenFoodFactsWhenUnifiedEmpty() async throws {
        let ai = FakeAIFoodSearch()
        let off = FakeOpenFoodFacts()
        off.products = [Self.product(id: "off-2", name: "Пельмені", kind: .product)]
        let results = try await makeUseCase(ai: ai, off: off).execute(query: "пельмені")
        XCTAssertEqual(results.map(\.externalId), ["off-2"])
    }

    func testUseCaseAnalyzesDishWhenCatalogsAreEmpty() async throws {
        let text = FakeTextAnalysis()
        text.analysis = FoodPhotoAnalysis(
            name: "Пельмені",
            mealType: .breakfast,
            calories: 450,
            protein: 18,
            carbs: 55,
            fats: 18,
            fiber: 3,
            sugar: 0,
            sodium: 900,
            portionGrams: 250,
            portionMilliliters: nil,
            confidence: 0.65,
            notes: "",
            assistantMessage: "",
            foodType: .dish
        )
        let results = try await makeUseCase(text: text).execute(query: "пельмені")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Пельмені")
        XCTAssertEqual(results[0].calories, 450)
        XCTAssertEqual(results[0].kind, .ingredient)
        XCTAssertEqual(results[0].foodType, .dish)
        XCTAssertTrue(results[0].externalId.hasPrefix("ai-"))
        XCTAssertEqual(results[0].source, .textAnalysis)
    }

    func testSearchFindsProductFromExpandedSectionWhenRemoteSearchMissesIt() async throws {
        let ai = FakeAIFoodSearch()
        let tomato = Self.product(id: "tomato", name: "Помідор", kind: .ingredient, source: .spoonacular)
        ai.sectionCatalog = ["vegetables": [tomato]]
        let useCase = makeUseCase(ai: ai)
        _ = await useCase.executeCategoryCatalogPage(sectionID: "vegetables", offset: 0)
        XCTAssertEqual(useCase.matchingBrowsedProducts(query: "  ПОМІДОР ").map(\.externalId), ["tomato"])
        let catalog = try await useCase.executeCatalog(query: "помідор")
        let unified = try await useCase.execute(query: "помідор")
        XCTAssertEqual(catalog.map(\.externalId), ["tomato"])
        XCTAssertEqual(unified.map(\.externalId), ["tomato"])
        XCTAssertTrue(useCase.matchingBrowsedProducts(query: "яблуко").isEmpty)
    }

    func testSearchRanksExactThenPrefixThenWordMatchStably() {
        let names = ["Салат із помідором", "Помідор чері", "  ПОМІДОР ", "Свіжий помідор", "Помідор жовтий", "Яблуко"]
        let products = names.enumerated().map { Self.product(id: "rank-\($0.offset)", name: $0.element, kind: .product) }
        XCTAssertEqual(SearchFoodProductsUseCase.ranked(products, query: "помідор").map(\.externalId),
                       ["rank-2", "rank-1", "rank-4", "rank-3", "rank-0", "rank-5"])
    }

    func testDefaultCatalogExactMatchWithoutPhotoAppearsBeforeAISuggestions() async throws {
        let ai = FakeAIFoodSearch()
        ai.catalog = ["vegetables": [Self.product(id: "tomato", name: "Помідор", kind: .ingredient,
                                               source: .spoonacular, imageURL: nil)]]
        ai.foods = [Self.product(id: "ai-tomato", name: "Помідор фарширований", kind: .recipe)]
        let model = makeSearchViewModel(ai: ai)
        let screen = FoodSearchViewController(viewModel: model)
        screen.loadViewIfNeeded()
        model.updateQuery("помідор")
        model.searchTapped()
        let shown = await waitUntil { !model.isSearching.value && !model.suggestedItems.value.isEmpty }
        XCTAssertTrue(shown)
        XCTAssertEqual(model.resultItems.value.first?.product.externalId, "tomato")
        let results = try XCTUnwrap(screen.value(forKey: "resultsSection") as? UIView)
        let suggestions = try XCTUnwrap(screen.value(forKey: "aiSection") as? UIView)
        let stack = try XCTUnwrap(results.superview as? UIStackView)
        XCTAssertLessThan(try XCTUnwrap(stack.arrangedSubviews.firstIndex(of: results)),
                          try XCTUnwrap(stack.arrangedSubviews.firstIndex(of: suggestions)))
        model.selectScope(.products)
        XCTAssertEqual(model.resultItems.value.first?.product.externalId, "tomato")
    }

    func testSearchShimmersRemainBelowEarlyResultInBothThemesWithoutReplacingItsRow() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let model = makeSearchViewModel(ai: FakeAIFoodSearch())
            let screen = FoodSearchViewController(viewModel: model)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            window.overrideUserInterfaceStyle = style
            window.rootViewController = screen
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            model.queryText.value = "Помідор"
            model.phase.value = .results
            model.isSearching.value = true
            let stack = try XCTUnwrap(screen.value(forKey: "resultsStackView") as? UIStackView)
            XCTAssertEqual(stack.arrangedSubviews.compactMap { $0 as? FoodSearchResultRowView }.filter(\.isSkeleton).count, 6)
            let product = Self.product(id: "tomato", name: "Помідор", kind: .ingredient, foodType: .product)
            model.resultItems.value = [FoodSearchItem(id: product.id, title: product.name, subtitle: "100 г · 18 ккал",
                                                     imageURL: nil, imageData: recipeNavigationPhoto(), product: product)]
            window.layoutIfNeeded()
            screen.view.layoutIfNeeded()
            let rows = stack.arrangedSubviews.compactMap { $0 as? FoodSearchResultRowView }
            XCTAssertEqual(rows.count, 4)
            let result = try XCTUnwrap(rows.first)
            XCTAssertEqual(result.itemID, product.id)
            XCTAssertFalse(result.isSkeleton)
            XCTAssertTrue(result.isUserInteractionEnabled)
            XCTAssertTrue(rows.dropFirst().allSatisfy { $0.isSkeleton && !$0.isUserInteractionEnabled })
            XCTAssertTrue(rows.allSatisfy { $0.bounds.height > 0 })
            let image = UIGraphicsImageRenderer(bounds: screen.view.bounds).image { screen.view.layer.render(in: $0.cgContext) }
            let attachment = XCTAttachment(image: image)
            attachment.name = "Partial search shimmer \(style == .dark ? "dark" : "light")"
            attachment.lifetime = .keepAlways
            add(attachment)
            model.isSearching.value = false
            XCTAssertEqual(stack.arrangedSubviews.count, 1)
            XCTAssertTrue(stack.arrangedSubviews.first === result, "Completing the search must leave the visible result intact")
            model.isSearching.value = true
            XCTAssertTrue(stack.arrangedSubviews.first === result)
            XCTAssertEqual(stack.arrangedSubviews.count, 4, "Further loading must append placeholders without replacing the result")
            model.clearQuery()
            XCTAssertFalse(stack.arrangedSubviews.contains { ($0 as? FoodSearchResultRowView)?.isSkeleton == true })
        }
    }

    func testSearchShimmersHandleAISuggestionsWithoutCatalogResultsAndStopOnEmptyCompletion() throws {
        let model = makeSearchViewModel(ai: FakeAIFoodSearch())
        let screen = FoodSearchViewController(viewModel: model)
        screen.loadViewIfNeeded()
        model.phase.value = .results
        model.isSearching.value = true
        let product = Self.product(id: "ai-tomato", name: "Помідоровий салат", kind: .recipe)
        model.suggestedItems.value = [FoodSearchItem(id: product.id, title: product.name, subtitle: "",
                                                    imageURL: nil, imageData: nil, product: product)]
        model.resultsTitleText.value = ""
        let section = try XCTUnwrap(screen.value(forKey: "resultsSection") as? UIView)
        let title = try XCTUnwrap(screen.value(forKey: "resultsTitleLabel") as? UILabel)
        let stack = try XCTUnwrap(screen.value(forKey: "resultsStackView") as? UIStackView)
        XCTAssertFalse(section.isHidden)
        XCTAssertFalse(title.isHidden)
        XCTAssertEqual(stack.arrangedSubviews.count, 3)
        model.isSearching.value = false
        XCTAssertTrue(section.isHidden)
        XCTAssertTrue(stack.arrangedSubviews.isEmpty)
        model.suggestedItems.value = []
        model.showsEmptyResults.value = true
        XCTAssertTrue(section.isHidden)
        XCTAssertFalse(try XCTUnwrap(screen.value(forKey: "emptySection") as? UIView).isHidden)
    }

    func testBreakfastSearchPublishesAISuggestedThenCatalog() async {
        let ai = FakeAIFoodSearch()
        ai.foods = [
            Self.product(id: "ai-a", name: "Пельмені зі свининою", kind: .recipe, protein: 27),
            Self.product(id: "ai-b", name: "Пельмені з куркою", kind: .recipe, protein: 31),
            Self.product(id: "ai-c", name: "Пельмені з грибами", kind: .recipe, protein: 18),
            Self.product(id: "off-1", name: "Пельмені Traditional", kind: .product, protein: 8)
        ]
        let viewModel = makeSearchViewModel(ai: ai)
        viewModel.updateQuery("пельмені")
        viewModel.searchTapped()
        let shown = await waitUntil {
            !viewModel.suggestedItems.value.isEmpty && !viewModel.resultItems.value.isEmpty
        }
        XCTAssertTrue(shown, "search should publish AI recipes and catalog products")
        XCTAssertEqual(viewModel.suggestedItems.value.map(\.product.externalId), ["ai-a", "ai-b", "ai-c"])
        XCTAssertEqual(viewModel.resultItems.value.map(\.product.externalId), ["off-1"])
        XCTAssertTrue(viewModel.suggestedItems.value.allSatisfy { $0.product.source == .openAI })
        XCTAssertTrue(viewModel.resultItems.value.allSatisfy { $0.product.source == .openFoodFacts })
    }

    func testSearchKeepsOpenFoodFactsWhenUnifiedReturnsSpoonacular() async {
        let ai = FakeAIFoodSearch()
        ai.foods = [
            Self.product(id: "ai-1", name: "Пельмені AI", kind: .recipe),
            Self.product(id: "991", name: "Pelmeni Mix", kind: .product, source: .spoonacular)
        ]
        let off = FakeOpenFoodFacts()
        off.products = [Self.product(id: "off-1", name: "Пельмені Рудь", kind: .product)]
        let viewModel = makeSearchViewModel(ai: ai, off: off)
        viewModel.updateQuery("пельмені")
        viewModel.searchTapped()
        let shown = await waitUntil {
            viewModel.isSearching.value == false
                && viewModel.suggestedItems.value.contains(where: { $0.product.externalId == "ai-1" })
                && viewModel.resultItems.value.contains(where: { $0.product.externalId == "off-1" })
                && viewModel.resultItems.value.contains(where: { $0.product.externalId == "991" })
        }
        XCTAssertTrue(shown, "catalog should keep Open Food Facts after Spoonacular arrives")
        XCTAssertEqual(viewModel.suggestedItems.value.map(\.product.externalId), ["ai-1"])
        XCTAssertEqual(viewModel.resultItems.value.map(\.product.externalId), ["off-1", "991"])
    }

    func testSearchKeepsProductsWithoutPhotosAndHidesUnillustratedRecipeSuggestions() async {
        let ai = FakeAIFoodSearch()
        ai.foods = [
            Self.product(id: "ai-photo", name: "Борщ", kind: .recipe),
            Self.product(id: "ai-plain", name: "Суп", kind: .recipe, includePhoto: false)
        ]
        let off = FakeOpenFoodFacts()
        off.products = [
            Self.product(id: "off-photo", name: "Йогурт", kind: .product),
            Self.product(id: "off-plain", name: "Кефір", kind: .product, includePhoto: false)
        ]
        let viewModel = makeSearchViewModel(ai: ai, off: off)
        viewModel.updateQuery("борщ")
        viewModel.searchTapped()
        let shown = await waitUntil {
            viewModel.isSearching.value == false
                && viewModel.suggestedItems.value.contains(where: { $0.product.externalId == "ai-photo" })
                && viewModel.resultItems.value.contains(where: { $0.product.externalId == "off-photo" })
        }
        XCTAssertTrue(shown)
        XCTAssertEqual(viewModel.suggestedItems.value.map(\.product.externalId), ["ai-photo"])
        XCTAssertEqual(viewModel.resultItems.value.map(\.product.externalId), ["off-photo", "off-plain"])
        XCTAssertFalse(viewModel.suggestedItems.value.contains(where: { $0.product.externalId == "ai-plain" }))
        XCTAssertTrue(viewModel.resultItems.value.contains(where: { $0.product.externalId == "off-plain" }))
    }

    func testSearchKeepsSpoonacularProductsWithPlaceholderPhotos() async {
        let ai = FakeAIFoodSearch()
        ai.foods = [
            Self.product(
                id: "991",
                name: "No Photo Mix",
                kind: .product,
                source: .spoonacular,
                imageURL: URL(string: "https://img.spoonacular.com/ingredients_100x100/no.png")
            ),
            Self.product(id: "off-1", name: "Yogurt", kind: .product, source: .openFoodFacts)
        ]
        let viewModel = makeSearchViewModel(ai: ai)
        viewModel.updateQuery("yogurt")
        viewModel.searchTapped()
        let shown = await waitUntil {
            viewModel.isSearching.value == false
                && viewModel.resultItems.value.contains(where: { $0.product.externalId == "off-1" })
        }
        XCTAssertTrue(shown)
        XCTAssertEqual(viewModel.resultItems.value.map(\.product.externalId), ["off-1", "991"])
        XCTAssertTrue(viewModel.resultItems.value.contains(where: { $0.product.externalId == "991" }))
    }

    func testEmptyQueryUsesDefaultCatalogWithoutOpenFoodFacts() async {
        let ai = FakeAIFoodSearch()
        ai.catalog = [
            "vegetablesGreens": [
                Self.product(id: "catalog.spinach", name: "Spinach", kind: .product, source: .catalog),
                Self.product(id: "catalog.broccoli", name: "Broccoli", kind: .product, source: .catalog),
                Self.product(id: "catalog.cucumber", name: "Cucumber", kind: .product, source: .catalog)
            ]
        ]
        let off = FakeOpenFoodFacts()
        off.products = [Self.product(id: "off-1", name: "Should not show", kind: .product)]
        let viewModel = makeSearchViewModel(ai: ai, off: off)
        viewModel.selectScope(.products)
        viewModel.viewDidLoad()
        let loaded = await waitUntil {
            !viewModel.isLoadingBrowse.value && viewModel.browseSections.value.contains(where: { $0.category == .vegetablesGreens })
        }
        XCTAssertTrue(loaded)
        XCTAssertEqual(viewModel.phase.value, .browse)
        XCTAssertEqual(viewModel.browseSections.value.map(\.category), [.vegetablesGreens])
        XCTAssertEqual(viewModel.browseSections.value.first?.items.map(\.title), ["Spinach", "Broccoli"])
        XCTAssertEqual(off.calls, 0)
    }

    func testCategoryCatalogUsesExpandedSectionList() async throws {
        let ai = FakeAIFoodSearch()
        ai.catalog = [
            "vegetablesGreens": [
                Self.product(id: "home-1", name: "Spinach", kind: .product, source: .catalog)
            ]
        ]
        ai.sectionCatalog = [
            "vegetablesGreens": [
                Self.product(id: "sec-1", name: "Tomato", kind: .ingredient, source: .spoonacular),
                Self.product(id: "sec-2", name: "Broccoli", kind: .ingredient, source: .spoonacular),
                Self.product(id: "sec-3", name: "Cucumber", kind: .ingredient, source: .spoonacular)
            ]
        ]
        let products = try await makeUseCase(ai: ai).executeCategoryCatalog(
            tag: "en:vegetables",
            query: "spinach",
            number: 120,
            sectionID: "vegetablesGreens"
        )
        XCTAssertEqual(products.map(\.externalId), ["sec-1", "sec-2", "sec-3"])
    }

    func testCategoryCatalogPageLoadsNextOffset() async {
        let ai = FakeAIFoodSearch()
        ai.sectionCatalog = [
            "vegetablesGreens": (1...25).map { index in
                Self.product(
                    id: "sec-\(index)",
                    name: "Item \(index)",
                    kind: .ingredient,
                    source: .spoonacular
                )
            }
        ]
        let useCase = makeUseCase(ai: ai)
        let first = await useCase.executeCategoryCatalogPage(
            sectionID: "vegetablesGreens",
            offset: 0,
            limit: 20
        )
        XCTAssertEqual(first.products.map(\.externalId), (1...20).map { "sec-\($0)" })
        XCTAssertEqual(first.nextOffset, 20)
        XCTAssertTrue(first.hasMore)
        let second = await useCase.executeCategoryCatalogPage(
            sectionID: "vegetablesGreens",
            offset: first.nextOffset,
            limit: 20
        )
        XCTAssertEqual(second.products.map(\.externalId), (21...25).map { "sec-\($0)" })
        XCTAssertEqual(second.nextOffset, 25)
        XCTAssertFalse(second.hasMore)
    }

    func testEmptyQueryUsesBrowsePhase() async {
        let off = FakeOpenFoodFacts()
        off.products = [Self.product(id: "spin-1", name: "Baby Spinach", kind: .product)]
        let viewModel = makeSearchViewModel(ai: FakeAIFoodSearch(), off: off)
        viewModel.viewDidLoad()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(viewModel.phase.value, .browse)
        XCTAssertTrue(viewModel.resultItems.value.isEmpty)
        XCTAssertTrue(viewModel.suggestedItems.value.isEmpty)
        XCTAssertEqual(viewModel.browseSections.value.map(\.category), [.preparedMeals, .products])
        XCTAssertFalse(viewModel.showsEmptyResults.value)
        XCTAssertEqual(off.calls, 0)
    }

    func testTypingKeepsBrowseWithoutSuggestions() async {
        let harness = TestHarness()
        try? harness.food.save(harness.foodEntry(name: "Greek Yogurt"))
        let viewModel = makeSearchViewModel(
            ai: FakeAIFoodSearch(),
            food: harness.food
        )
        viewModel.viewDidLoad()
        viewModel.updateQuery("Greek")
        XCTAssertEqual(viewModel.phase.value, .browse)
        XCTAssertTrue(viewModel.resultItems.value.isEmpty)
        XCTAssertTrue(viewModel.suggestedItems.value.isEmpty)
    }

    func testClearQueryRestoresBrowse() async {
        let viewModel = makeSearchViewModel(ai: FakeAIFoodSearch())
        viewModel.viewDidLoad()
        viewModel.updateQuery("пельмені")
        viewModel.searchTapped()
        _ = await waitUntil { viewModel.isSearching.value == false }
        viewModel.clearQuery()
        XCTAssertEqual(viewModel.phase.value, .browse)
        XCTAssertTrue(viewModel.resultItems.value.isEmpty)
        XCTAssertFalse(viewModel.showsEmptyResults.value)
    }

    func testCategoryCatalogPrefersDefaultCatalog() async {
        let ai = FakeAIFoodSearch()
        ai.catalog = [
            "vegetablesGreens": [
                Self.product(id: "catalog.spinach", name: "Spinach", kind: .product, source: .catalog),
                Self.product(id: "catalog.broccoli", name: "Broccoli", kind: .product, source: .catalog)
            ]
        ]
        let off = FakeOpenFoodFacts()
        off.products = [
            Self.product(id: "kale-1", name: "Kale, Tuscan", kind: .product)
        ]
        let viewModel = FoodSearchCategoryViewModel(
            category: .vegetablesGreens,
            mealType: .breakfast,
            date: Date(timeIntervalSince1970: 1),
            searchFoodProductsUseCase: makeUseCase(ai: ai, off: off),
            fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase(service: FakeSearchRecipeSections())
        )
        viewModel.viewDidLoad()
        let loaded = await waitUntil { viewModel.items.value.count == 2 }
        XCTAssertTrue(loaded)
        XCTAssertEqual(viewModel.items.value.map(\.title), ["Spinach", "Broccoli"])
        XCTAssertEqual(off.calls, 0)
    }

    func testCategoryShadowFadeStaysAtViewportEdgeDuringScroll() throws {
        let preview = (0..<20).map { index -> FoodSearchItem in
            let product = Self.product(id: "shadow-\(index)", name: "Готова страва \(index)", kind: .recipe)
            return FoodSearchItem(id: product.id, title: product.name, subtitle: "494 ккал",
                                  imageURL: nil, imageData: nil, product: product)
        }
        let model = FoodSearchCategoryViewModel(category: .preparedMeals, mealType: .breakfast,
            date: Date(), searchFoodProductsUseCase: makeUseCase(ai: FakeAIFoodSearch()),
            fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase(service: FakeSearchRecipeSections()),
            previewItems: preview)
        let screen = FoodSearchCategoryViewController(viewModel: model)
        screen.loadViewIfNeeded()
        screen.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        screen.view.layoutIfNeeded()
        let scroll = try XCTUnwrap(screen.value(forKey: "scrollView") as? UIScrollView)
        let mask = try XCTUnwrap(scroll.layer.mask as? CAGradientLayer)
        for offset in [CGFloat(0), 100, 350, -30] {
            scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
            screen.scrollViewDidScroll(scroll)
            XCTAssertEqual(mask.frame, scroll.bounds)
            let colors = try XCTUnwrap(mask.colors as? [CGColor])
            XCTAssertEqual(colors.first?.alpha, 0)
            XCTAssertEqual(colors.last?.alpha, 0)
        }
        scroll.setContentOffset(.zero, animated: false)
        for style in [UIUserInterfaceStyle.light, .dark] {
            screen.overrideUserInterfaceStyle = style
            screen.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: screen.view.bounds).image {
                screen.view.layer.render(in: $0.cgContext)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "Category shadow fade \(style == .dark ? "dark" : "light")"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testCategoryCatalogLoadsItems() async {
        let off = FakeOpenFoodFacts()
        off.products = [
            Self.product(id: "kale-1", name: "Kale, Tuscan", kind: .product),
            Self.product(id: "kale-2", name: "Baby Spinach", kind: .product)
        ]
        let viewModel = FoodSearchCategoryViewModel(
            category: .vegetablesGreens,
            mealType: .breakfast,
            date: Date(timeIntervalSince1970: 1),
            searchFoodProductsUseCase: makeUseCase(off: off),
            fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase(service: FakeSearchRecipeSections())
        )
        viewModel.viewDidLoad()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(viewModel.items.value.isEmpty)
        XCTAssertEqual(off.calls, 0)
        XCTAssertEqual(viewModel.titleText, L10n.tr("search.category.vegetablesGreens"))
    }

    func testEmptySearchShowsNoResultsState() async {
        let viewModel = makeSearchViewModel(ai: FakeAIFoodSearch())
        viewModel.updateQuery("zzzz-not-a-food")
        viewModel.searchTapped()
        let shown = await waitUntil {
            viewModel.isSearching.value == false && viewModel.showsEmptyResults.value
        }
        XCTAssertTrue(shown)
        XCTAssertTrue(viewModel.suggestedItems.value.isEmpty)
        XCTAssertTrue(viewModel.resultItems.value.isEmpty)
        XCTAssertEqual(viewModel.resultsTitleText.value, L10n.tr("search.results"))
    }

    func testGeneralCatalogIncludesRecipesAlongsideProductsAndIngredients() async throws {
        let spoon = FakeSpoonacular()
        var recipe = try await spoon.recipeDetails(id: "42")
        recipe.title = "Chicken soup"
        recipe.imageURL = URL(string: "https://example.com/soup.jpg")
        spoon.recipes = [recipe]
        spoon.ingredients = [Self.product(id: "42", name: "Chicken", kind: .ingredient, source: .spoonacular)]
        spoon.products = [Self.product(id: "43", name: "Packaged chicken", kind: .product, source: .spoonacular)]
        let products = try await makeUseCase(spoonacular: spoon).executeCatalog(query: "chicken", includeRecipes: true)
        XCTAssertEqual(Set(products.map(\.kind.rawValue)), ["recipe", "ingredient", "product"])
        XCTAssertEqual(products.count, 3)
    }

    func testGroceryCatalogDoesNotRequestRecipes() async throws {
        let spoon = FakeSpoonacular()
        _ = try await makeUseCase(spoonacular: spoon).executeCatalog(query: "chicken", includeRecipes: false)
        XCTAssertEqual(spoon.recipeSearchCalls, 0)
    }

    func testProductsScopeMatchesFigmaSectionsAndShowsTwoItemsEach() async {
        let ai = FakeAIFoodSearch()
        for category in FoodSearchCategory.productCategories {
            ai.catalog[category.rawValue] = (0..<8).map {
                Self.product(id: "\(category.rawValue)-\($0)", name: "Локалізована їжа \($0)", kind: .ingredient, source: .catalog)
            }
        }
        ai.catalog["preparedMeals"] = [Self.product(id: "extra", name: "Uncategorized meal", kind: .recipe)]
        let viewModel = makeSearchViewModel(ai: ai)
        viewModel.selectScope(.products)
        viewModel.viewDidLoad()
        let loaded = await waitUntil { !viewModel.isLoadingBrowse.value }
        XCTAssertTrue(loaded)
        XCTAssertEqual(viewModel.browseSections.value.map { $0.category.rawValue }, [
            "vegetablesGreens", "fruitsBerries", "meatPoultry", "fishSeafood", "dairyEggs", "grainsCereals", "beverages"
        ])
        for section in viewModel.browseSections.value {
            XCTAssertEqual(section.items.map(\.title), ["Локалізована їжа 0", "Локалізована їжа 1"])
        }
        XCTAssertTrue(ai.catalogPageOffsets.isEmpty)
    }

    func testCategoryLoadsAndLocalizesOnlyRequestedPages() async {
        let ai = FakeAIFoodSearch()
        ai.catalog["vegetablesGreens"] = (0..<45).map {
            Self.product(id: "veg-\($0)", name: "Овоч \($0)", kind: .ingredient, source: .spoonacular)
        }
        let search = makeSearchViewModel(ai: ai)
        search.selectScope(.products)
        search.viewDidLoad()
        _ = await waitUntil { !search.isLoadingBrowse.value }
        let preview = search.browseSections.value.first?.items ?? []
        let viewModel = FoodSearchCategoryViewModel(
            category: .vegetablesGreens, mealType: .lunch, date: Date(timeIntervalSince1970: 1),
            searchFoodProductsUseCase: makeUseCase(ai: ai), fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase(service: FakeSearchRecipeSections()), previewItems: preview
        )
        XCTAssertEqual(viewModel.items.value.count, 2)
        viewModel.viewDidLoad()
        _ = await waitUntil { !viewModel.isLoadingMore.value }
        XCTAssertEqual(viewModel.items.value.count, 20)
        XCTAssertEqual(ai.catalogPageOffsets, [0])
        viewModel.loadMoreIfNeeded()
        viewModel.loadMoreIfNeeded()
        _ = await waitUntil { !viewModel.isLoadingMore.value }
        XCTAssertEqual(viewModel.items.value.count, 40)
        XCTAssertEqual(ai.catalogPageOffsets, [0, 20])
        viewModel.loadMoreIfNeeded()
        _ = await waitUntil { !viewModel.isLoadingMore.value }
        XCTAssertEqual(viewModel.items.value.map(\.title), (0..<45).map { "Овоч \($0)" })
        viewModel.loadMoreIfNeeded()
        XCTAssertEqual(ai.catalogPageOffsets, [0, 20, 40])
    }

    func testCategoryRetriesFailedPageWithoutLosingExistingItems() async {
        let ai = FakeAIFoodSearch()
        ai.catalog["beverages"] = (0..<25).map {
            Self.product(id: "drink-\($0)", name: "Напій \($0)", kind: .ingredient, source: .spoonacular)
        }
        let viewModel = FoodSearchCategoryViewModel(
            category: .beverages, mealType: .lunch, date: Date(timeIntervalSince1970: 1),
            searchFoodProductsUseCase: makeUseCase(ai: ai),
            fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase(service: FakeSearchRecipeSections())
        )
        viewModel.viewDidLoad()
        _ = await waitUntil { !viewModel.isLoading.value }
        ai.catalogPageError = URLError(.timedOut)
        viewModel.loadMoreIfNeeded()
        _ = await waitUntil { !viewModel.isLoadingMore.value }
        XCTAssertEqual(viewModel.items.value.count, 20)
        XCTAssertTrue(viewModel.loadFailed.value)
        ai.catalogPageError = nil
        viewModel.retryLoading()
        _ = await waitUntil { !viewModel.isLoadingMore.value }
        XCTAssertEqual(viewModel.items.value.count, 25)
        XCTAssertEqual(ai.catalogPageOffsets, [0, 20, 20])
    }

    func testCategoryPageUsesServerCursorAndAcceptsEndOfCatalog() {
        let payload = Data("""
        {"offset":20,"nextOffset":40,"hasMore":true,"items":[
          {"externalId":"1","name":"Куряча грудка","kind":"ingredient","source":"spoonacular"}
        ]}
        """.utf8)
        let page = AIFoodSearchService.decodeCatalogPage(from: payload, id: "meatPoultry", offset: 20, locale: "uk")
        XCTAssertEqual(page.nextOffset, 40)
        XCTAssertEqual(page.products.first?.name, "Куряча грудка")
        XCTAssertTrue(page.hasMore)
        let end = AIFoodSearchService.decodeCatalogPage(
            from: Data("{\"offset\":40,\"nextOffset\":40,\"items\":[],\"hasMore\":false}".utf8),
            id: "meatPoultry", offset: 40, locale: "uk"
        )
        XCTAssertTrue(end.products.isEmpty)
        XCTAssertEqual(end.nextOffset, 40)
        XCTAssertFalse(end.hasMore)
    }

    func testBrowseRendersTwoRowsPerFigmaSectionAndOpensMatchingCategory() async throws {
        let url = try XCTUnwrap(Bundle(for: AIFoodSearchService.self).url(forResource: "food-search-catalog", withExtension: "json"))
        let ai = FakeAIFoodSearch()
        ai.catalog = AIFoodSearchService.decodeCatalog(from: try Data(contentsOf: url), locale: "uk")
        for style in [UIUserInterfaceStyle.light, .dark] {
            let viewModel = makeSearchViewModel(ai: ai)
            viewModel.selectScope(.products)
            let controller = FoodSearchViewController(viewModel: viewModel)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            window.overrideUserInterfaceStyle = style
            window.rootViewController = controller
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            _ = await waitUntil { !viewModel.isLoadingBrowse.value }
            controller.view.layoutIfNeeded()
            let sections = allViews(controller.view).compactMap { $0 as? FoodSearchCategorySectionView }
            XCTAssertEqual(sections.count, 7)
            var opened: FoodSearchCategory?
            viewModel.onOpenCategory = { opened = $0 }
            for (section, category) in zip(sections, FoodSearchCategory.productCategories) {
                section.layoutIfNeeded()
                let rows = allViews(section).compactMap { $0 as? FoodSearchResultRowView }
                XCTAssertEqual(rows.count, 2)
                XCTAssertTrue(rows.allSatisfy { $0.bounds.height > 0 })
                let button = try XCTUnwrap(allViews(section).compactMap { $0 as? UIButton }.first {
                    $0.title(for: .normal) == L10n.tr("search.seeMore")
                })
                button.sendActions(for: .touchUpInside)
                XCTAssertEqual(opened, category)
            }
            let scroll = try XCTUnwrap(allViews(controller.view).compactMap { $0 as? UIScrollView }.first)
            for position in ["top", "bottom"] {
                if position == "bottom" {
                    scroll.contentOffset.y = max(-scroll.adjustedContentInset.top,
                                                scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                    controller.view.layoutIfNeeded()
                    let last = try XCTUnwrap(sections.last)
                    XCTAssertLessThanOrEqual(last.convert(last.bounds, to: controller.view).maxY,
                                             scroll.convert(scroll.bounds, to: controller.view).maxY + 1)
                }
                let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { context in
                    controller.view.layer.render(in: context.cgContext)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "Food search \(style == .dark ? "dark" : "light") \(position)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testSharedBrowseRequestsOnlyVisiblePreviewsAndCachesScopeChanges() async {
        let ai = FakeAIFoodSearch()
        ai.catalog["preparedMeals"] = (0..<25).map { Self.product(id: "meal-\($0)", name: "Страва \($0)", kind: .recipe) }
        ai.catalog["products"] = (0..<25).map { Self.product(id: "food-\($0)", name: "Продукт \($0)", kind: .ingredient) }
        ai.catalog["dairyEggs"] = ai.catalog["products"]
        let search = makeSearchViewModel(ai: ai)
        search.viewDidLoad()
        _ = await waitUntil { !search.isLoadingBrowse.value }
        XCTAssertEqual(search.scope.value, .all)
        XCTAssertEqual(search.browseSections.value.map(\.category), [.preparedMeals, .products])
        XCTAssertEqual(search.browseSections.value.map { $0.items.count }, [2, 2])
        XCTAssertEqual(Set(ai.catalogPageRequests.map(\.id)), ["preparedMeals", "products"])
        XCTAssertEqual(ai.catalogPageRequests.map(\.limit), [2, 2])
        XCTAssertEqual(ai.defaultCatalogCalls, 0)
        search.selectScope(.meals)
        XCTAssertEqual(search.browseSections.value.map(\.category), FoodSearchCategory.mealCategories)
        search.selectScope(.products)
        _ = await waitUntil { !search.isLoadingBrowse.value }
        XCTAssertEqual(search.browseSections.value.map(\.category), [.dairyEggs])
        search.selectScope(.all)
        search.selectScope(.products)
        XCTAssertEqual(ai.defaultCatalogCalls, 1)
        XCTAssertEqual(ai.catalogPageRequests.count, 2)
    }

    func testMealsScopeShowsRecentThenRecipesAllSectionsWithTwoRecipesEach() async throws {
        let service = FakeSearchRecipeSections()
        let useCase = FetchRecipeBrowseSectionsUseCase(service: service)
        let ai = FakeAIFoodSearch()
        let harness = TestHarness()
        var recent = harness.foodEntry(name: "Плов", date: Date(timeIntervalSince1970: 30))
        recent.catalogKind = .recipe
        try harness.food.save(recent)
        let search = makeSearchViewModel(ai: ai, food: harness.food, recipeSections: useCase)
        search.viewDidLoad()
        XCTAssertTrue(service.pageRequests.isEmpty)
        search.selectScope(.meals)
        let loaded = await waitUntil { !search.isLoadingBrowse.value }
        XCTAssertTrue(loaded)
        let sections = search.browseSections.value
        XCTAssertEqual(sections.map(\.category), [.recent] + FoodSearchCategory.mealCategories)
        XCTAssertEqual(sections.first?.items.first?.id, recent.id)
        XCTAssertEqual(FoodSearchCategory.mealCategories.compactMap(\.recipeSection), RecipeBrowseSectionKind.catalogSections)
        XCTAssertEqual(sections.dropFirst().map { $0.items.count }, Array(repeating: 2, count: 9))
        for section in sections.dropFirst() {
            let kind = try XCTUnwrap(section.category.recipeSection)
            XCTAssertEqual(section.category.titleKey, kind.titleKey)
            XCTAssertEqual(section.items.map(\.title), service.sections.first { $0.id == kind }?.recipes.prefix(2).map(\.title))
            XCTAssertTrue(section.items.allSatisfy { $0.product.kind == .recipe && $0.product.amount == 250 })
        }
        XCTAssertEqual(service.pageRequests.count, 9)
        XCTAssertTrue(service.pageRequests.allSatisfy { $0.offset == 0 && $0.limit == 2 })
        XCTAssertLessThanOrEqual(service.maximumActiveRequests, 3)
        XCTAssertEqual(service.sectionsRequests, 0)
        XCTAssertFalse(ai.catalogPageRequests.contains { RecipeBrowseSectionKind(rawValue: $0.id) != nil })
        search.selectScope(.all)
        search.selectScope(.meals)
        XCTAssertEqual(service.pageRequests.count, 9)
        XCTAssertFalse(search.isLoadingBrowse.value)
    }

    func testMealsScopeReusesRecipesAllCacheWithoutRequestingHiddenRecipes() async {
        let service = FakeSearchRecipeSections()
        let sharedUseCase = FetchRecipeBrowseSectionsUseCase(service: service)
        let recipesAll = await sharedUseCase.execute()
        let search = makeSearchViewModel(ai: FakeAIFoodSearch(), recipeSections: sharedUseCase)
        search.selectScope(.meals)
        let loaded = await waitUntil { !search.isLoadingBrowse.value }
        XCTAssertTrue(loaded)
        XCTAssertEqual(search.browseSections.value.map { $0.items.map(\.product.externalId) },
                       recipesAll.map { Array($0.recipes.prefix(2)).compactMap(\.externalId) })
        XCTAssertEqual(service.sectionsRequests, 1)
        XCTAssertTrue(service.pageRequests.isEmpty)
    }

    func testMealSectionMorePaginatesAndKeepsTheRecipeDestinationAndLoggingContext() async throws {
        let service = FakeSearchRecipeSections()
        let useCase = FetchRecipeBrowseSectionsUseCase(service: service)
        let search = makeSearchViewModel(ai: FakeAIFoodSearch(), recipeSections: useCase)
        search.selectScope(.meals)
        _ = await waitUntil { !search.isLoadingBrowse.value }
        let section = try XCTUnwrap(search.browseSections.value.first { $0.category == .healthyBreakfast })
        var opened: FoodSearchCategory?
        search.onOpenCategory = { opened = $0 }
        search.seeMoreTapped(section.category)
        XCTAssertEqual(opened, .healthyBreakfast)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let more = FoodSearchCategoryViewModel(category: section.category, mealType: .breakfast, date: date,
            searchFoodProductsUseCase: makeUseCase(), fetchRecipeBrowseSectionsUseCase: useCase, previewItems: section.items)
        XCTAssertEqual(more.items.value.count, 2)
        more.viewDidLoad()
        _ = await waitUntil { !more.isLoadingMore.value }
        XCTAssertEqual(more.items.value.count, 20)
        more.loadMoreIfNeeded()
        more.loadMoreIfNeeded()
        _ = await waitUntil { !more.isLoadingMore.value }
        XCTAssertEqual(more.items.value.count, 25)
        XCTAssertEqual(service.pageRequests.filter { $0.id == .healthyBreakfast }.map(\.offset), [0, 0, 20])
        XCTAssertEqual(service.pageRequests.filter { $0.id == .healthyBreakfast }.map(\.limit), [2, 20, 20])
        var selected: ProductDetailsDraft?
        more.onOpenDetails = { selected = $0 }
        more.selectItem(id: try XCTUnwrap(more.items.value.last).id)
        XCTAssertEqual(selected?.catalogKind, .recipe)
        XCTAssertEqual(selected?.mealType, .breakfast)
        XCTAssertEqual(selected?.date, date)
        XCTAssertEqual(selected?.portionGrams, 250)
        XCTAssertEqual(selected?.name, more.items.value.last?.title)
        more.loadMoreIfNeeded()
        XCTAssertEqual(service.pageRequests.filter { $0.id == .healthyBreakfast }.count, 3)
    }

    func testMealSectionFailureCanRetryWithoutReloadingOtherSections() async {
        let service = FakeSearchRecipeSections()
        service.failingSections = [.asian]
        let search = makeSearchViewModel(ai: FakeAIFoodSearch(),
            recipeSections: FetchRecipeBrowseSectionsUseCase(service: service))
        search.selectScope(.meals)
        _ = await waitUntil { !search.isLoadingBrowse.value }
        XCTAssertEqual(search.browseSections.value.filter(\.loadFailed).map(\.category), [.asian])
        XCTAssertEqual(search.browseSections.value.filter { !$0.loadFailed }.count, 8)
        let otherRequests = service.pageRequests.filter { $0.id != .asian }.count
        service.failingSections = []
        search.retryBrowse(.asian)
        _ = await waitUntil { !search.isLoadingBrowse.value }
        XCTAssertFalse(search.browseSections.value.contains(where: \.loadFailed))
        XCTAssertEqual(search.browseSections.value.last?.items.count, 2)
        XCTAssertEqual(service.pageRequests.filter { $0.id != .asian }.count, otherRequests)
        XCTAssertEqual(service.pageRequests.filter { $0.id == .asian }.count, 3)
    }

    func testRecipeSectionTemporaryFailureRetriesAndSharesSuccessfulPage() async {
        let service = FakeSearchRecipeSections()
        service.failuresRemaining = 1
        let useCase = FetchRecipeBrowseSectionsUseCase(service: service)
        async let first = useCase.recipesPage(in: .italian, offset: 0, limit: 2)
        async let second = useCase.recipesPage(in: .italian, offset: 0, limit: 2)
        let pages = await [first, second]
        XCTAssertTrue(pages.allSatisfy { !$0.isRetryableFailure && $0.recipes.count == 2 })
        XCTAssertEqual(service.pageRequests.count, 2)
        _ = await useCase.recipesPage(in: .italian, offset: 0, limit: 2)
        XCTAssertEqual(service.pageRequests.count, 2)
        let invalid = RecipeSectionsService.decodePage(from: Data("{\"error\":\"unavailable\"}".utf8), offset: 20)
        XCTAssertTrue(invalid.isRetryableFailure)
        XCTAssertEqual(invalid.nextOffset, 20)
    }

    func testRecentFoodsDeduplicateByKindAndUseCurrentMealAndDate() async throws {
        let harness = TestHarness()
        var product = harness.foodEntry(name: "Бульйон", mealType: .dinner, date: Date(timeIntervalSince1970: 30))
        product.catalogKind = .ingredient
        product.foodType = .dish
        var meal = harness.foodEntry(name: "Бульйон", mealType: .lunch, date: Date(timeIntervalSince1970: 20))
        meal.catalogKind = .recipe
        meal.imageData = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).pngData { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        var older = harness.foodEntry(name: "Бульйон", mealType: .lunch, date: Date(timeIntervalSince1970: 10))
        older.catalogKind = .recipe
        try harness.food.save(product)
        try harness.food.save(meal)
        try harness.food.save(older)
        let search = makeSearchViewModel(ai: FakeAIFoodSearch(), food: harness.food)
        search.viewDidLoad()
        let recent = try XCTUnwrap(search.browseSections.value.first)
        XCTAssertEqual(recent.category, .recent)
        XCTAssertEqual(recent.items.map(\.id), [product.id, meal.id])
        XCTAssertFalse(recent.showsMore)
        search.selectScope(.meals)
        // Both the generic broth nutrition record and the recipe are prepared dishes.
        XCTAssertEqual(search.browseSections.value.first?.items.map(\.id), [product.id, meal.id])
        var draft: ProductDetailsDraft?
        search.onOpenDetails = { draft = $0 }
        search.selectItem(id: meal.id)
        XCTAssertEqual(draft?.date, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(draft?.mealType, .breakfast)
        XCTAssertEqual(draft?.catalogKind, .recipe)
        XCTAssertEqual(draft?.imageData, meal.imageData)
    }

    func testScopeFiltersSearchWithoutClearingQueryOrLosingOtherKinds() async {
        let ai = FakeAIFoodSearch()
        ai.foods = [Self.product(id: "same", name: "Курячий бульйон", kind: .recipe, source: .spoonacular),
                    Self.product(id: "same", name: "Курятина", kind: .ingredient, source: .spoonacular),
                    Self.product(id: "packaged", name: "Куряча грудка", kind: .product)]
        let search = makeSearchViewModel(ai: ai)
        search.updateQuery("курка")
        search.searchTapped()
        search.selectScope(.meals)
        _ = await waitUntil { !search.isSearching.value }
        XCTAssertEqual(search.resultItems.value.map(\.product.kind), [.recipe])
        search.selectScope(.products)
        XCTAssertEqual(Set(search.resultItems.value.map(\.product.kind)), [.product, .ingredient])
        search.selectScope(.all)
        XCTAssertEqual(search.resultItems.value.count, 3)
        XCTAssertEqual(search.queryText.value, "курка")
        XCTAssertEqual(search.phase.value, .results)
    }

    func testPreparedMealsMorePagesAndRetryPreservePreviewAndKind() async {
        let ai = FakeAIFoodSearch()
        ai.catalog["preparedMeals"] = (0..<25).map { Self.product(id: "meal-\($0)", name: "Страва \($0)", kind: .recipe) }
        let search = makeSearchViewModel(ai: ai)
        search.viewDidLoad()
        _ = await waitUntil { !search.isLoadingBrowse.value }
        let more = FoodSearchCategoryViewModel(category: .preparedMeals, mealType: .lunch, date: Date(timeIntervalSince1970: 1), searchFoodProductsUseCase: makeUseCase(ai: ai), fetchRecipeBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase(service: FakeSearchRecipeSections()), previewItems: search.browseSections.value.first?.items ?? [])
        more.viewDidLoad()
        _ = await waitUntil { !more.isLoadingMore.value }
        XCTAssertEqual(more.items.value.count, 20)
        ai.catalogPageError = URLError(.timedOut)
        more.loadMoreIfNeeded()
        _ = await waitUntil { !more.isLoadingMore.value }
        XCTAssertTrue(more.loadFailed.value)
        ai.catalogPageError = nil
        more.retryLoading()
        _ = await waitUntil { !more.isLoadingMore.value }
        XCTAssertEqual(more.items.value.count, 25)
        XCTAssertTrue(more.items.value.allSatisfy { $0.product.kind == .recipe })
        XCTAssertEqual(ai.catalogPageRequests.filter { $0.limit == 20 }.map(\.id), Array(repeating: "preparedMeals", count: 3))
    }

    func testPantryRetainsProductOnlyBrowseAndNoScopeControl() async {
        let ai = FakeAIFoodSearch()
        let search = makeSearchViewModel(ai: ai, includeRecipes: false)
        search.viewDidLoad()
        search.selectScope(.all)
        _ = await waitUntil { !search.isLoadingBrowse.value }
        XCTAssertFalse(search.showsScopeControl)
        XCTAssertEqual(search.scope.value, .products)
        XCTAssertEqual(ai.defaultCatalogCalls, 1)
        XCTAssertTrue(ai.catalogPageRequests.isEmpty)
    }

    func testSharedScreenReusesExistingRowsAndSegmentInBothThemes() async throws {
        let ai = FakeAIFoodSearch()
        ai.catalog["preparedMeals"] = [Self.product(id: "pilaf", name: "Плов з куркою", kind: .recipe), Self.product(id: "borscht", name: "Борщ український", kind: .recipe)]
        ai.catalog["products"] = [Self.product(id: "yogurt", name: "Йогурт грецький", kind: .product), Self.product(id: "chicken", name: "Куряча грудка", kind: .ingredient)]
        let harness = TestHarness()
        var recent = harness.foodEntry(name: "Банан", date: Date(timeIntervalSince1970: 30))
        recent.catalogKind = .product
        try harness.food.save(recent)
        var recentMeal = harness.foodEntry(name: "Плов з куркою", date: Date(timeIntervalSince1970: 20))
        recentMeal.catalogKind = .recipe
        try harness.food.save(recentMeal)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let search = makeSearchViewModel(ai: ai, food: harness.food)
            let controller = FoodSearchViewController(viewModel: search)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            window.overrideUserInterfaceStyle = style
            window.rootViewController = controller
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            _ = await waitUntil { !search.isLoadingBrowse.value }
            controller.view.layoutIfNeeded()
            let sections = allViews(controller.view).compactMap { $0 as? FoodSearchCategorySectionView }
            XCTAssertEqual(sections.count, 3)
            XCTAssertEqual(sections.map { allViews($0).compactMap { $0 as? FoodSearchResultRowView }.count }, [2, 2, 2])
            let segment = try XCTUnwrap(allViews(controller.view).compactMap { $0 as? RecipeHubSegmentControl }.first)
            let labels = allViews(segment).compactMap { ($0 as? UILabel)?.text }
            XCTAssertEqual(labels, FoodSearchScope.allCases.map { L10n.tr($0.titleKey) })
            XCTAssertGreaterThan(segment.bounds.height, 0)
            var opened: FoodSearchCategory?
            search.onOpenCategory = { opened = $0 }
            let more = try XCTUnwrap(allViews(sections[1]).compactMap { $0 as? UIButton }.first { $0.title(for: .normal) == L10n.tr("search.seeMore") })
            more.sendActions(for: .touchUpInside)
            XCTAssertEqual(opened, .preparedMeals)
            let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { controller.view.layer.render(in: $0.cgContext) }
            let attachment = XCTAttachment(image: image)
            attachment.name = "Shared food search \(style == .dark ? "dark" : "light")"
            attachment.lifetime = .keepAlways
            add(attachment)
            segment.selectSegment(at: 2)
            XCTAssertEqual(search.scope.value, .meals)
            XCTAssertEqual(search.browseSections.value.map(\.category), [.recent] + FoodSearchCategory.mealCategories)
            _ = await waitUntil { !search.isLoadingBrowse.value }
            controller.view.layoutIfNeeded()
            let mealSections = allViews(controller.view).compactMap { $0 as? FoodSearchCategorySectionView }
            XCTAssertEqual(mealSections.count, 10)
            XCTAssertEqual(mealSections.dropFirst().map { allViews($0).compactMap { $0 as? FoodSearchResultRowView }.count }, Array(repeating: 2, count: 9))
            let mealLabels = allViews(controller.view).compactMap { ($0 as? UILabel)?.text }
            for kind in RecipeBrowseSectionKind.catalogSections { XCTAssertTrue(mealLabels.contains(L10n.tr(kind.titleKey))) }
            let mealsImage = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { controller.view.layer.render(in: $0.cgContext) }
            let mealsAttachment = XCTAttachment(image: mealsImage)
            mealsAttachment.name = "Meals recipe sections \(style == .dark ? "dark" : "light")"
            mealsAttachment.lifetime = .keepAlways
            add(mealsAttachment)
            segment.selectSegment(at: 0)
            XCTAssertEqual(search.scope.value, .all)
        }
        let recipesSegment = RecipeHubSegmentControl()
        XCTAssertTrue(allViews(recipesSegment).compactMap { ($0 as? UILabel)?.text }.contains(L10n.tr("recipes.tab.saved")))
        var selected: RecipeHubTab?
        recipesSegment.onSelect = { selected = $0 }
        recipesSegment.selectSegment(at: 1)
        XCTAssertEqual(selected, .saved)
        recipesSegment.accessibilityIncrement()
        XCTAssertEqual(selected, .mealPlans)
        recipesSegment.accessibilityDecrement()
        XCTAssertEqual(selected, .saved)
    }

    func testPreparedMealFailureKeepsRetryInsetAndRecoversWithoutHidingProducts() async throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let ai = FakeAIFoodSearch()
            ai.failingCatalogSectionIDs = ["preparedMeals"]
            ai.catalog["preparedMeals"] = [Self.product(id: "meal-1", name: "Рататуй", kind: .recipe),
                                            Self.product(id: "meal-2", name: "Омлет", kind: .recipe)]
            ai.catalog["products"] = [Self.product(id: "food-1", name: "Помідор", kind: .ingredient)]
            let search = makeSearchViewModel(ai: ai)
            let controller = FoodSearchViewController(viewModel: search)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            window.overrideUserInterfaceStyle = style
            window.rootViewController = controller
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            _ = await waitUntil { !search.isLoadingBrowse.value }
            controller.view.layoutIfNeeded()
            let sections = allViews(controller.view).compactMap { $0 as? FoodSearchCategorySectionView }
            XCTAssertEqual(sections.count, 2)
            XCTAssertTrue(search.browseSections.value[0].loadFailed)
            XCTAssertEqual(search.browseSections.value[1].items.first?.title, "Помідор")
            let empty = try XCTUnwrap(allViews(sections[0]).compactMap { $0 as? EmptyScreenView }.first)
            let button = try XCTUnwrap(allViews(empty).compactMap { $0 as? UIButton }.first { !$0.isHidden })
            let frame = button.convert(button.bounds, to: empty)
            XCTAssertGreaterThanOrEqual(empty.bounds.height - frame.maxY, CGFloat.adaptHeight(16) - 1)
            XCTAssertGreaterThan(frame.height, 40)
            let screenshot = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { controller.view.layer.render(in: $0.cgContext) }
            let attachment = XCTAttachment(image: screenshot)
            attachment.name = "Food catalog retry inset \(style == .dark ? "dark" : "light")"
            attachment.lifetime = .keepAlways
            add(attachment)
            ai.failingCatalogSectionIDs = []
            button.sendActions(for: .touchUpInside)
            _ = await waitUntil { !search.isLoadingBrowse.value }
            XCTAssertFalse(search.browseSections.value[0].loadFailed)
            XCTAssertEqual(search.browseSections.value[0].items.map(\.title), ["Рататуй", "Омлет"])
            XCTAssertEqual(ai.catalogPageRequests.filter { $0.id == "preparedMeals" }.count, 2)
            XCTAssertEqual(ai.catalogPageRequests.filter { $0.id == "products" }.count, 1)
        }
    }

    func testSemanticFoodTypeRoutesUnrelatedDishesAcrossProviderNamespaces() throws {
        let nav = FoodSearchNavigationSpy()
        nav.modalPresentationStyle = .fullScreen
        let coordinator = FoodLoggingCoordinator(navigationController: nav,
            container: DIContainer(coreDataStack: CoreDataStack(inMemory: true)))
        for (name, kind) in [("Шакшука", FoodProductKind.ingredient), ("Сирники", .product), ("Paella", .ingredient), ("помідорний суп", .ingredient)] {
            let dish = Self.product(id: "6159", name: name, kind: kind, source: .catalog, foodType: .dish)
            let draft = ProductDetailsMath.draft(from: dish, imageData: nil, mealType: .lunch, date: Date())
            coordinator.openProductDetails(draft)
            XCTAssertTrue(nav.pushed.last is RecipeDetailViewController, name)
            XCTAssertTrue(FoodSearchScope.meals.includes(dish), name)
            XCTAssertFalse(FoodSearchScope.products.includes(dish), name)
            XCTAssertEqual(draft.catalogKind, kind)
            XCTAssertEqual(draft.toFoodEntry().asRecipe().catalogFoodID, "6159")
        }
        for name in ["Помідор", "Суха суміш для супу", "Packaged tomato soup", "Eggplant"] {
            let product = Self.product(id: "42", name: name, kind: .ingredient, foodType: .product)
            coordinator.openProductDetails(ProductDetailsMath.draft(from: product, imageData: nil, mealType: .lunch, date: Date()))
            XCTAssertTrue(nav.pushed.last is ProductDetailsViewController, name)
            XCTAssertTrue(FoodSearchScope.products.includes(product))
        }
    }

    func testCatalogMergeKeepsSameNumericIDsFromDifferentProviders() {
        let first = Self.product(id: "42", name: "Сир", kind: .product, source: .openFoodFacts)
        let second = Self.product(id: "42", name: "Молоко", kind: .product, source: .spoonacular)
        XCTAssertEqual(SearchFoodProductsUseCase.mergeCatalog(primary: [first], extras: [second]).count, 2)
    }

    func testUnknownFoodClassificationIsCachedAndPreservesProviderIdentity() async throws {
        let ai = FakeAIFoodSearch()
        ai.classifiedTypes = ["6159": .dish, "81": .product]
        let useCase = makeUseCase(ai: ai)
        var unknown = Self.product(id: "6159", name: "Шакшука", kind: .ingredient, source: .spoonacular)
        unknown.foodType = nil
        var ingredient = Self.product(id: "81", name: "Перець", kind: .ingredient, source: .spoonacular)
        ingredient.foodType = nil
        let resolved = try await useCase.classifyFoods([unknown, ingredient])
        XCTAssertEqual(resolved.map(\.foodType), [.dish, .product])
        XCTAssertEqual(resolved.map(\.id), [unknown.id, ingredient.id])
        XCTAssertEqual(resolved.map(\.kind), [.ingredient, .ingredient])
        XCTAssertEqual(resolved.map(\.externalId), ["6159", "81"])
        _ = try await useCase.classifyFoods([unknown, ingredient])
        XCTAssertEqual(ai.classificationCalls, 1)
    }

    func testUnknownClassificationFailureDoesNotBecomeProductAndCanRetry() async throws {
        let ai = FakeAIFoodSearch()
        let useCase = makeUseCase(ai: ai)
        var unknown = Self.product(id: "42", name: "Сирники", kind: .ingredient, source: .catalog)
        unknown.foodType = nil
        XCTAssertFalse(FoodSearchScope.products.includes(unknown))
        XCTAssertFalse(FoodSearchScope.meals.includes(unknown))
        do {
            _ = try await useCase.classifyFoods([unknown])
            XCTFail("Unclassified food must remain retryable")
        } catch { }
        ai.classifiedTypes["42"] = .dish
        let resolved = try await useCase.classifyFoods([unknown])
        XCTAssertEqual(resolved.first?.foodType, .dish)
        XCTAssertEqual(ai.classificationCalls, 2)
    }

    func testLegacyDiaryClassificationKeepsFoodLookupNamespaceAndLoggingDate() async throws {
        let ai = FakeAIFoodSearch()
        ai.classifiedTypes["77"] = .dish
        var entry = TestHarness().foodEntry(name: "Паелья", mealType: .dinner, date: Date(timeIntervalSince1970: 77))
        entry.source = "catalog"
        entry.catalogExternalId = "77"
        entry.catalogKind = nil
        entry.foodType = nil
        let draft = try await makeUseCase(ai: ai).classifiedDraft(ProductDetailsMath.draft(from: entry))
        XCTAssertEqual(draft.foodType, .dish)
        XCTAssertEqual(draft.catalogKind, .ingredient)
        XCTAssertEqual(draft.toFoodEntry().asRecipe().externalId, "ingredient:77")
        XCTAssertEqual(draft.date, entry.date)
        XCTAssertEqual(draft.mealType, .dinner)
    }

    func testPreparedSoupResolvesCompleteRecipeAndPublishesAllTabsBeforeLogging() async throws {
        let harness = TestHarness()
        let catalog = FakeSpoonacular()
        let soup = Self.product(id: "6159", name: "Помідорний суп", kind: .ingredient, source: .spoonacular, foodType: .dish)
        var original = ProductDetailsMath.draft(from: soup, imageData: recipeNavigationPhoto(), mealType: .dinner,
                                               date: Date(timeIntervalSince1970: 1700000000))
        original.fiber = 999
        let full = completeTomatoSoup()
        catalog.recipes = [full]
        catalog.detailedRecipe = full
        let model = makeRecipeDetailViewModel(draft: original, harness: harness, spoonacular: catalog)
        let screen = RecipeDetailViewController(viewModel: model)
        screen.loadViewIfNeeded()
        let resolved = await waitUntil { !model.isResolvingPreparedDish && !model.isDetailsLoading.value }
        XCTAssertTrue(resolved)
        XCTAssertEqual(catalog.ingredientDetailsCalls, 0)
        XCTAssertEqual(catalog.recipeDetailsCalls, 1)
        XCTAssertEqual(model.recipe.externalId, "9001")
        XCTAssertEqual(model.recipe.calories, 320)
        XCTAssertFalse(model.ingredients.value.isEmpty)
        XCTAssertEqual(model.steps.value, full.steps)
        for tab in [RecipeDetailTab.nutrition, .ingredients, .instructions] {
            model.selectTab(tab)
            let key = tab == .nutrition ? "nutritionSection" : tab == .ingredients ? "ingredientsSection" : "instructionsSection"
            XCTAssertFalse(try XCTUnwrap(screen.value(forKey: key) as? UIView).isHidden)
        }
        var added: ProductDetailsDraft?
        model.onAddToDiary = { added = $0 }
        model.addToDiaryTapped()
        let logged = await waitUntil { added != nil }
        XCTAssertTrue(logged)
        XCTAssertEqual(added?.calories, 320)
        XCTAssertEqual(added?.catalogKind, .recipe)
        XCTAssertEqual(added?.catalogExternalId, "9001")
        XCTAssertEqual(added?.date, original.date)
        XCTAssertEqual(added?.mealType, .dinner)
        XCTAssertNil(added?.imageData, "Do not mix the generic ingredient photo with a different recipe")
        XCTAssertNotEqual(added?.fiber, 999)
    }

    func testPreparedSoupFailureIsReportedAndRetryLoadsACompleteRecipe() async {
        let harness = TestHarness()
        let catalog = FakeSpoonacular()
        let soup = Self.product(id: "6159", name: "Помідорний суп", kind: .ingredient, source: .spoonacular, foodType: .dish)
        let original = ProductDetailsMath.draft(from: soup, imageData: nil, mealType: .lunch, date: Date())
        let model = makeRecipeDetailViewModel(draft: original, harness: harness, spoonacular: catalog)
        var failures = 0
        var logged = false
        model.onDetailsUnavailable = { failures += 1 }
        model.onAddToDiary = { _ in logged = true }
        model.addToDiaryTapped()
        let failed = await waitUntil { failures > 0 }
        XCTAssertTrue(failed)
        XCTAssertFalse(logged)
        XCTAssertTrue(model.isResolvingPreparedDish)
        catalog.recipes = [completeTomatoSoup()]
        catalog.detailedRecipe = completeTomatoSoup()
        model.retryDetails()
        let resolved = await waitUntil { !model.isResolvingPreparedDish }
        XCTAssertTrue(resolved)
        XCTAssertFalse(model.ingredients.value.isEmpty)
        XCTAssertFalse(model.steps.value.isEmpty)
    }

    func testPreparedSoupAIFallbackHasItsOwnIdentityAndCompleteNutrition() async throws {
        let ai = FakeAIFoodSearch()
        var generated = Self.product(id: "6159", name: "Помідорний суп", kind: .recipe)
        generated.calories = 280
        generated.protein = 8
        generated.carbs = 35
        generated.fats = 12
        generated.ingredients = ["Помідори 200 г", "Вода 100 мл"]
        generated.steps = ["Зваріть овочі та подрібніть блендером."]
        ai.detailsProduct = generated
        let useCase = SearchRecipesUseCase(spoonacularService: FakeSpoonacular(), aiFoodSearchService: ai)
        let original = Recipe(id: UUID(), externalId: "ingredient:6159", title: "Помідорний суп",
                              calories: 66, ingredients: [], steps: [], origin: .spoonacular)
        let result = try await useCase.details(for: original)
        XCTAssertTrue(SearchRecipesUseCase.hasCompleteDetails(result))
        XCTAssertEqual(result.calories, 280)
        XCTAssertEqual(result.origin, .openAI)
        XCTAssertTrue(result.externalId?.hasPrefix("ai-") == true)
        XCTAssertNil(result.ingredientCatalogID)
    }

    func testPreparedDishesResolveAcrossProductAndIngredientNamespacesWithoutNameSubstring() async throws {
        for (name, namespace, matchedTitle) in [("Шакшука", "ingredient", "Shakshouka"), ("Сирники", "product", "Ukrainian cottage cheese pancakes"), ("Помідорний суп", "ingredient", "Кремовий томатний суп")] {
            let ai = FakeAIFoodSearch()
            ai.matchedRecipeID = "9001"
            let catalog = FakeSpoonacular()
            var full = completeTomatoSoup()
            full.title = matchedTitle
            catalog.recipes = [full]
            catalog.detailedRecipe = full
            let useCase = SearchRecipesUseCase(spoonacularService: catalog, aiFoodSearchService: ai)
            let original = Recipe(id: UUID(), externalId: "\(namespace):88", title: name,
                                  calories: 10, ingredients: [], steps: [], origin: .catalog)
            let resolved = try await useCase.details(for: original)
            XCTAssertEqual(resolved.title, matchedTitle)
            XCTAssertEqual(resolved.externalId, "9001")
            XCTAssertTrue(SearchRecipesUseCase.hasCompleteDetails(resolved))
            XCTAssertEqual(catalog.ingredientDetailsCalls, 0)
            XCTAssertEqual(catalog.recipeDetailsCalls, 1)
            XCTAssertEqual(ai.matchingCalls, 1)
        }
    }

    func testNearNameRecipeWithoutSemanticMatchCannotReplaceSelectedDish() async {
        let ai = FakeAIFoodSearch()
        let catalog = FakeSpoonacular()
        var unrelated = completeTomatoSoup()
        unrelated.title = "Tomato soup cupcakes"
        catalog.recipes = [unrelated]
        catalog.detailedRecipe = unrelated
        let original = Recipe(id: UUID(), externalId: "ingredient:88", title: "Tomato soup",
                              calories: 10, ingredients: [], steps: [], origin: .spoonacular)
        do {
            _ = try await SearchRecipesUseCase(spoonacularService: catalog, aiFoodSearchService: ai).details(for: original)
            XCTFail("The similar title is not evidence of the same dish")
        } catch { }
        XCTAssertEqual(ai.matchingCalls, 1)
    }

    func testIncompleteRecipesFromEveryOriginBlockLoggingAndSavingUntilRetrySucceeds() async {
        for origin in [FoodProductSource.spoonacular, .openAI, .catalog] {
            for missing in ["protein", "carbs", "fats", "ingredients", "steps"] {
                let harness = TestHarness()
                let ai = FakeAIFoodSearch()
                let catalog = FakeSpoonacular()
                var recipe = completeTomatoSoup()
                recipe.origin = origin
                if origin != .spoonacular { recipe.externalId = "local-\(missing)" }
                switch missing {
                case "protein": recipe.protein = nil
                case "carbs": recipe.carbs = nil
                case "fats": recipe.fats = nil
                case "ingredients": recipe.ingredients = []
                default: recipe.steps = []
                }
                catalog.detailedRecipe = recipe
                let model = RecipeDetailViewModel(recipe: recipe,
                    searchRecipesUseCase: SearchRecipesUseCase(spoonacularService: catalog, aiFoodSearchService: ai),
                    recipeRepository: harness.recipes, aiAssistantService: AIAssistantService(),
                    fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(foodEntryRepository: harness.food,
                        waterEntryRepository: harness.water, userGoalsRepository: harness.goals, workoutEntryRepository: harness.workout))
                var logged = false
                var failures = 0
                model.onAddToDiary = { _ in logged = true }
                model.onDetailsUnavailable = { failures += 1 }
                model.addToDiaryTapped()
                _ = await waitUntil { failures > 0 }
                XCTAssertFalse(logged, "\(origin):\(missing)")
                XCTAssertFalse(model.isDetailsReady.value)
                XCTAssertTrue(model.nutritionRows.value.isEmpty)
                model.saveTapped()
                _ = await waitUntil { failures > 1 }
                XCTAssertFalse(model.isSaved.value)
                let full = completeTomatoSoup()
                catalog.detailedRecipe = full
                var generated = FoodProduct(recipe: full)
                generated.source = .openAI
                ai.detailsProduct = generated
                model.retryDetails()
                let recovered = await waitUntil { model.isDetailsReady.value }
                XCTAssertTrue(recovered, "\(origin):\(missing)")
                XCTAssertFalse(model.ingredients.value.isEmpty)
                XCTAssertFalse(model.steps.value.isEmpty)
            }
        }
    }

    private func completeTomatoSoup() -> Recipe {
        Recipe(id: UUID(), externalId: "9001", title: "Помідорний суп", servings: 1,
               calories: 320, protein: 10, carbs: 40, fats: 12,
               ingredients: [RecipeIngredient(id: "tomato", name: "Помідори", amount: 200, unit: "г")],
               steps: ["Відваріть помідори.", "Подрібніть блендером."], origin: .spoonacular, weightGrams: 350)
    }

    func testDirectFoodDetailsRoutesDishToTabbedRecipeAndProductToProduct() throws {
        let nav = FoodSearchNavigationSpy()
        nav.modalPresentationStyle = .fullScreen
        let coordinator = FoodLoggingCoordinator(navigationController: nav,
            container: DIContainer(coreDataStack: CoreDataStack(inMemory: true)))
        for kind in [FoodProductKind.recipe, .ingredient, .product] {
            let product = Self.product(id: "ai-complete", name: "Food", kind: kind, protein: 12, source: .openAI)
            var draft = ProductDetailsMath.draft(from: product, imageData: nil, mealType: .dinner, date: Date())
            draft.recipeSteps = ["Cook"]
            draft.ingredients = [FoodIngredient(name: "Milk", grams: 100)]
            var added: ProductDetailsDraft?
            coordinator.openProductDetails(draft, onAdd: { added = $0 })
            if kind == .recipe {
                let screen = try XCTUnwrap(nav.pushed.last as? RecipeDetailViewController)
                let model: RecipeDetailViewModel = try reflectedViewModel(screen)
                screen.loadViewIfNeeded()
                for tab in [RecipeDetailTab.nutrition, .ingredients, .instructions] {
                    model.selectTab(tab)
                    let key = tab == .nutrition ? "nutritionSection" : tab == .ingredients ? "ingredientsSection" : "instructionsSection"
                    XCTAssertFalse(try XCTUnwrap(screen.value(forKey: key) as? UIView).isHidden)
                }
                model.saveTapped()
                XCTAssertTrue(model.savedAlertVisible.value)
                let save = try XCTUnwrap(screen.value(forKey: "saveButton") as? UIButton)
                XCTAssertEqual(save.title(for: .normal), L10n.tr("common.saved"))
                model.dismissSavedAlert()
                XCTAssertFalse(model.savedAlertVisible.value)
                model.onAddToDiary?(draft)
                XCTAssertEqual(added?.mealType, .dinner)
            } else {
                XCTAssertTrue(nav.pushed.last is ProductDetailsViewController)
            }
        }
    }

    func testSearchRoutesRecipesAndProductsToTheirOwnDetailScreens() throws {
        let nav = FoodSearchNavigationSpy()
        nav.modalPresentationStyle = .fullScreen
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        let coordinator = FoodLoggingCoordinator(navigationController: nav, container: container)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        coordinator.openFoodSearch(mealType: .breakfast, date: date)
        let search = try XCTUnwrap(nav.pushed.last as? FoodSearchViewController)
        let model: FoodSearchViewModel = try reflectedViewModel(search)
        for (kind, source) in [(FoodProductKind.recipe, FoodProductSource.spoonacular),
                               (.recipe, .openAI), (.product, .spoonacular), (.ingredient, .spoonacular)] {
            let product = Self.product(id: "633754", name: "Рататуй", kind: kind, source: source)
            let draft = ProductDetailsMath.draft(from: product, imageData: nil, mealType: .breakfast, date: date)
            model.onOpenDetails?(draft)
            if kind == .recipe {
                let detail = try XCTUnwrap(nav.pushed.last as? RecipeDetailViewController)
                let recipeModel: RecipeDetailViewModel = try reflectedViewModel(detail)
                XCTAssertEqual(recipeModel.recipe.externalId, product.externalId)
                XCTAssertEqual(recipeModel.recipe.title, product.name)
                XCTAssertEqual(recipeModel.recipe.imageURL, product.imageURL)
                XCTAssertEqual(recipeModel.recipe.origin, source)
                XCTAssertTrue(recipeModel.showsAddToDiary)
            } else {
                XCTAssertTrue(nav.pushed.last is ProductDetailsViewController)
            }
        }
    }

    func testAProductAddedToThePantryStaysOnTheProductScreenAndSaves() throws {
        let nav = FoodSearchNavigationSpy()
        nav.modalPresentationStyle = .fullScreen
        let coordinator = FoodLoggingCoordinator(
            navigationController: nav,
            container: DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        )
        // A pantry hit can classify as a dish; routing it to the recipe page left the button dead,
        // because that page waits for full recipe details a pantry product never has.
        let product = Self.product(id: "633754", name: "Рататуй", kind: .recipe, source: .spoonacular)
        let draft = ProductDetailsMath.draft(from: product, imageData: nil, mealType: .snacks, date: Date())
        var added: ProductDetailsDraft?
        coordinator.openProductDetails(
            draft,
            addButtonTitle: "Додати до комори",
            routesDishesToRecipe: false,
            onAdd: { added = $0 }
        )

        let details = try XCTUnwrap(nav.pushed.last as? ProductDetailsViewController)
        let model: ProductDetailsViewModel = try reflectedViewModel(details)
        XCTAssertEqual(model.addButtonTitle.value, "Додати до комори")
        model.addToDiaryTapped()
        XCTAssertEqual(added?.name, product.name, "The button hands the product over to the pantry")
    }

    func testMoreRowSelectionRoutesPreparedMealsAndProductsCorrectly() throws {
        let nav = FoodSearchNavigationSpy()
        nav.modalPresentationStyle = .fullScreen
        let coordinator = FoodLoggingCoordinator(navigationController: nav,
            container: DIContainer(coreDataStack: CoreDataStack(inMemory: true)))
        for (category, kind) in [(FoodSearchCategory.preparedMeals, FoodProductKind.recipe), (.healthyBreakfast, .recipe), (.products, .product)] {
            let product = Self.product(id: "633754", name: "Рататуй", kind: kind, source: .spoonacular)
            let item = FoodSearchItem(id: product.id, title: product.name, subtitle: "",
                                     imageURL: product.imageURL, imageData: nil, product: product)
            coordinator.openFoodSearchCategory(category, mealType: .dinner, date: Date(), previewItems: [item])
            let screen = try XCTUnwrap(nav.pushed.last as? FoodSearchCategoryViewController)
            let model: FoodSearchCategoryViewModel = try reflectedViewModel(screen)
            model.selectItem(id: item.id)
            XCTAssertEqual(nav.pushed.last is RecipeDetailViewController, kind == .recipe)
            XCTAssertEqual(nav.pushed.last is ProductDetailsViewController, kind != .recipe)
        }
    }

    func testRecipeNutritionUsesWholeServingRatherThanHundredGrams() throws {
        let harness = TestHarness()
        let goals = UserGoals(calorieTarget: 2184, proteinTarget: 100, carbsTarget: 250, fatsTarget: 70, fiberTarget: 28, sugarTarget: 50, sodiumTarget: 2300, waterTargetMilliliters: 2000)
        try harness.goals.save(goals)
        var product = Self.product(id: "ai-ratatouille", name: "Рататуй", kind: .recipe, protein: 32, includePhoto: false)
        product.amount = 1705
        product.unit = "g"
        product.calories = 1029
        product.ingredients = ["Помідори 1000 г", "Кабачок 705 г"]
        product.steps = ["Тушкувати овочі"]
        let draft = ProductDetailsMath.draft(from: product, imageData: recipeNavigationPhoto(), mealType: .dinner, date: Date())
        let model = makeRecipeDetailViewModel(draft: draft, harness: harness)
        model.viewDidLoad()
        XCTAssertEqual(model.calorieSharePercentText.value, "47%")
        XCTAssertEqual(model.calorieShareProgress.value, 1029 / 2184, accuracy: 0.001)
        XCTAssertEqual(model.nutritionRows.value.first?.value, ProductDetailsMath.formatCalories(1029))
        XCTAssertEqual(model.nutritionRows.value.first?.dailyValue, ProductDetailsMath.formatDailyValue(1029 / 2000 * 100))
        XCTAssertEqual(model.nutritionRows.value.dropFirst().first?.value, ProductDetailsMath.formatGrams(draft.protein))
    }

    func testSearchRecipeDetailsKeepBrothVolumePhotoAndLoggingContext() async throws {
        let harness = TestHarness()
        var product = Self.product(id: "ai-broth", name: "Курячий бульйон", kind: .recipe, protein: 10, includePhoto: false)
        product.amount = 250
        product.unit = "ml"
        product.ingredients = ["Вода 250 мл", "Курка 50 г"]
        product.steps = ["Зварити бульйон"]
        let draft = ProductDetailsMath.draft(from: product, imageData: recipeNavigationPhoto(),
                                            mealType: .dinner, date: Date(timeIntervalSince1970: 1_700_000_000))
        let model = makeRecipeDetailViewModel(draft: draft, harness: harness)
        let screen = RecipeDetailViewController(viewModel: model)
        screen.loadViewIfNeeded()
        XCTAssertNotNil(model.heroImage.value)
        XCTAssertTrue(model.subtitleText.value.contains(ProductDetailsMath.formatPortion(grams: nil, milliliters: 250)))
        let buttons = allViews(screen.view).compactMap { $0 as? UIButton }
        for key in ["recipes.details.nutrition", "product.details.ingredients", "recipes.details.instructions"] {
            XCTAssertTrue(buttons.contains { $0.currentTitle == L10n.tr(key) || $0.configuration?.title == L10n.tr(key) }, key)
        }
        var added: ProductDetailsDraft?
        model.onAddToDiary = { added = $0 }
        model.addToDiaryTapped()
        let completed = await waitUntil { added != nil }
        XCTAssertTrue(completed)
        let result = try XCTUnwrap(added)
        XCTAssertEqual(result.mealType, .dinner)
        XCTAssertEqual(result.date, draft.date)
        XCTAssertEqual(result.portionMilliliters, 250)
        XCTAssertNil(result.portionGrams)
        XCTAssertEqual(result.imageData, draft.imageData)
        XCTAssertEqual(result.catalogKind, .recipe)
        XCTAssertEqual(result.catalogExternalId, draft.catalogExternalId)
    }

    func testSearchRecipeAddWaitsForDetailsAndRetainsSelectedDateAndMeal() async throws {
        let harness = TestHarness()
        let spoonacular = FakeSpoonacular()
        spoonacular.recipeDetailsDelayNanoseconds = 100_000_000
        spoonacular.detailedRecipe = Recipe(id: UUID(), externalId: "633754", title: "Ratatouille",
            servings: 4, calories: 520, protein: 18, carbs: 60, fats: 20,
            ingredients: [RecipeIngredient(id: "tomato", name: "Помідор", amount: 100, unit: "g")],
            steps: ["Запекти овочі"], origin: .spoonacular, weightGrams: 300)
        let product = Self.product(id: "633754", name: "Рататуй", kind: .recipe, source: .spoonacular)
        var draft = ProductDetailsMath.draft(from: product, imageData: recipeNavigationPhoto(),
            mealType: .breakfast, date: Date(timeIntervalSince1970: 1_700_000_000))
        draft.logDates = [draft.date, draft.date.addingTimeInterval(86_400)]
        let model = makeRecipeDetailViewModel(draft: draft, harness: harness, spoonacular: spoonacular)
        model.viewDidLoad()
        let started = await waitUntil { spoonacular.recipeDetailsCalls == 1 }
        XCTAssertTrue(started)
        var added: ProductDetailsDraft?
        model.onAddToDiary = { added = $0 }
        model.addToDiaryTapped()
        let completed = await waitUntil { added != nil }
        XCTAssertTrue(completed)
        let result = try XCTUnwrap(added)
        XCTAssertEqual(spoonacular.recipeDetailsCalls, 1)
        XCTAssertEqual(result.name, "Рататуй")
        XCTAssertEqual(result.calories, 520)
        XCTAssertEqual(result.portionGrams, 300)
        XCTAssertEqual(result.servings, 1)
        XCTAssertEqual(result.recipeSteps, ["Запекти овочі"])
        XCTAssertEqual(result.mealType, .breakfast)
        XCTAssertEqual(result.date, draft.date)
        XCTAssertEqual(result.logDates, draft.logDates)
        XCTAssertEqual(result.imageData, draft.imageData)
    }

    private func reflectedViewModel<T>(_ controller: UIViewController) throws -> T {
        try XCTUnwrap(Mirror(reflecting: controller).children.first { $0.label == "viewModel" }?.value as? T)
    }

    private func makeRecipeDetailViewModel(
        draft: ProductDetailsDraft,
        harness: TestHarness,
        spoonacular: FakeSpoonacular = FakeSpoonacular()
    ) -> RecipeDetailViewModel {
        let ai = FakeAIFoodSearch()
        ai.matchedRecipeID = "9001"
        return RecipeDetailViewModel(recipe: draft.toFoodEntry().asRecipe(),
            searchRecipesUseCase: SearchRecipesUseCase(spoonacularService: spoonacular, aiFoodSearchService: ai),
            recipeRepository: harness.recipes, aiAssistantService: AIAssistantService(),
            fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(foodEntryRepository: harness.food,
                waterEntryRepository: harness.water, userGoalsRepository: harness.goals, workoutEntryRepository: harness.workout),
            loggingContext: draft)
    }

    private func recipeNavigationPhoto() -> Data? {
        UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }.pngData()
    }

    func testFirstCatalogFailureRecoversAutomaticallyWithoutShowingError() async {
        var attempts: [String: Int] = [:]
        CatalogHTTPProtocol.handler = { request in
            let section = request.url!.lastPathComponent
            attempts[section, default: 0] += 1
            if section == "preparedMeals", attempts[section] == 1 {
                return (503, ["Retry-After": "0"], Data("{}".utf8))
            }
            return (200, [:], Self.catalogHTTPPage(kind: section == "preparedMeals" ? "recipe" : "product"))
        }
        let search = makeSearchViewModel(ai: makeCatalogHTTPService())
        var displayedFailure = false
        search.browseSections.bind { sections in displayedFailure = displayedFailure || sections.contains(where: \.loadFailed) }
        search.viewDidLoad()
        _ = await waitUntil { !search.isLoadingBrowse.value }
        XCTAssertFalse(displayedFailure)
        XCTAssertEqual(search.browseSections.value.first?.items.first?.title, "Рататуй")
        XCTAssertEqual(attempts["preparedMeals"], 2)
        XCTAssertEqual(attempts["products"], 1)
    }

    func testCatalogRetriesNetworkInterruptionAndServerFailureThenCachesSuccess() async throws {
        var calls = 0
        CatalogHTTPProtocol.handler = { _ in
            calls += 1
            if calls == 1 { throw URLError(.networkConnectionLost) }
            if calls == 2 { return (520, [:], Data()) }
            return (200, ["Cache-Control": "public, max-age=600"], Self.catalogHTTPPage())
        }
        let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0)
        let service = makeCatalogHTTPService(cache: cache)
        let page = try await service.fetchCatalogSectionPage(id: "preparedMeals", offset: 0, limit: 2)
        XCTAssertEqual(page.products.first?.name, "Рататуй")
        XCTAssertEqual(calls, 3)
        let reopened = makeCatalogHTTPService(cache: cache)
        let cached = try await reopened.fetchCatalogSectionPage(id: "preparedMeals", offset: 0, limit: 2)
        XCTAssertEqual(cached.products.first?.name, "Рататуй")
        XCTAssertEqual(calls, 3)
        _ = try await reopened.fetchCatalogSectionPage(id: "preparedMeals", offset: 2, limit: 2)
        XCTAssertEqual(calls, 4)
    }

    func testCatalogUsesLastSuccessfulPageWhenRefreshTemporarilyFails() async throws {
        var calls = 0
        CatalogHTTPProtocol.handler = { _ in
            calls += 1
            if calls == 1 { return (200, ["Cache-Control": "max-age=0"], Self.catalogHTTPPage()) }
            return (503, ["Retry-After": "0"], Data())
        }
        let service = makeCatalogHTTPService()
        _ = try await service.fetchCatalogSectionPage(id: "preparedMeals", offset: 0, limit: 2)
        let fallback = try await service.fetchCatalogSectionPage(id: "preparedMeals", offset: 0, limit: 2)
        XCTAssertEqual(fallback.products.first?.name, "Рататуй")
        XCTAssertEqual(calls, 4)
    }

    func testCatalogDoesNotRetryPermanentHTTPFailuresOrReturnStaleDataForThem() async throws {
        for status in [401, 403, 404] {
            var calls = 0
            CatalogHTTPProtocol.handler = { _ in
                calls += 1
                if calls == 1 { return (200, ["Cache-Control": "max-age=0"], Self.catalogHTTPPage()) }
                return (status, [:], Data())
            }
            let service = makeCatalogHTTPService()
            _ = try await service.fetchCatalogSectionPage(id: "preparedMeals", offset: 0, limit: 2)
            do {
                _ = try await service.fetchCatalogSectionPage(id: "preparedMeals", offset: 0, limit: 2)
                XCTFail("Expected HTTP \(status) failure")
            } catch {
                XCTAssertEqual(calls, 2)
            }
        }
    }

    func testCatalogRetryIsBoundedAndDoesNotCacheFailedPayloads() async throws {
        var calls = 0
        CatalogHTTPProtocol.handler = { _ in
            calls += 1
            return (503, ["Retry-After": "0"], Data("{\"error\":\"unavailable\"}".utf8))
        }
        let service = makeCatalogHTTPService()
        do {
            _ = try await service.fetchCatalogSectionPage(id: "preparedMeals", offset: 0, limit: 2)
            XCTFail("Expected retry exhaustion")
        } catch {
            XCTAssertEqual(calls, 3)
        }
        CatalogHTTPProtocol.handler = { _ in
            calls += 1
            return (200, [:], Self.catalogHTTPPage())
        }
        let recovered = try await service.fetchCatalogSectionPage(id: "preparedMeals", offset: 0, limit: 2)
        XCTAssertEqual(recovered.products.count, 1)
        XCTAssertEqual(calls, 4)
    }

    func testCatalogDoesNotTreatInvalidSuccessPayloadAsAnEmptyPage() async throws {
        var calls = 0
        CatalogHTTPProtocol.handler = { _ in
            calls += 1
            if calls == 1 { return (200, [:], Data("<html>gateway error</html>".utf8)) }
            return (200, [:], Self.catalogHTTPPage())
        }
        let page = try await makeCatalogHTTPService().fetchCatalogSectionPage(id: "preparedMeals", offset: 0, limit: 2)
        XCTAssertEqual(page.products.count, 1)
        XCTAssertEqual(calls, 2)
    }

    func testCatalogCancellationStopsRetries() async {
        var calls = 0
        CatalogHTTPProtocol.handler = { _ in
            calls += 1
            throw URLError(.cancelled)
        }
        do {
            _ = try await makeCatalogHTTPService().fetchCatalogSectionPage(id: "preparedMeals", offset: 0, limit: 2)
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
            XCTAssertEqual(calls, 1)
        }
    }

    private func makeCatalogHTTPService(cache: URLCache? = nil) -> AIFoodSearchService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CatalogHTTPProtocol.self]
        let session = URLSession(configuration: config)
        addTeardownBlock {
            session.invalidateAndCancel()
            CatalogHTTPProtocol.handler = nil
        }
        return AIFoodSearchService(session: session,
            catalogCache: cache ?? URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0),
            catalogRetryDelayNanoseconds: 0)
    }

    private static func catalogHTTPPage(kind: String = "recipe") -> Data {
        Data("""
        {"items":[{"externalId":"633754","title":"Рататуй","kind":"\(kind)","source":"spoonacular","imageURL":"https://img.spoonacular.com/recipes/633754-312x231.jpg"}],"nextOffset":2,"hasMore":true}
        """.utf8)
    }

    private func allViews(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(allViews)
    }

    private func makeUseCase(
        ai: AIFoodSearching = FakeAIFoodSearch(),
        off: FakeOpenFoodFacts = FakeOpenFoodFacts(),
        text: FakeTextAnalysis = FakeTextAnalysis(),
        spoonacular: FakeSpoonacular = FakeSpoonacular()
    ) -> SearchFoodProductsUseCase {
        SearchFoodProductsUseCase(
            spoonacularService: spoonacular,
            aiFoodSearchService: ai,
            openFoodFactsService: off,
            textFoodAnalysisService: text
        )
    }

    private func makePantryItem(name: String) -> PantryItem {
        let now = Date()
        return PantryItem(
            id: UUID(),
            name: name,
            quantityText: "",
            amount: nil,
            unit: nil,
            useBy: nil,
            imageURL: nil,
            imageData: nil,
            createdAt: now,
            updatedAt: now
        )
    }

    private func makeSearchViewModel(
        ai: AIFoodSearching,
        off: FakeOpenFoodFacts = FakeOpenFoodFacts(),
        food: FoodEntryRepository? = nil,
        recipeSections: FetchRecipeBrowseSectionsUseCase? = nil,
        includeRecipes: Bool = true
    ) -> FoodSearchViewModel {
        return FoodSearchViewModel(
            mealType: .breakfast,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            searchFoodProductsUseCase: makeUseCase(ai: ai, off: off),
            fetchRecipeBrowseSectionsUseCase: recipeSections ?? FetchRecipeBrowseSectionsUseCase(service: FakeSearchRecipeSections()),
            fetchSavedFoodsUseCase: FetchSavedFoodsUseCase(
                foodEntryRepository: food ?? FoodEntryRepository(coreDataStack: CoreDataStack(inMemory: true))
            ),
            voiceRecorder: FakeVoiceRecorder(),
            transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase(
                voiceFoodTranscriptionService: FakeVoiceTranscription()
            ),
            includeRecipes: includeRecipes
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return condition()
    }

    private static func product(
        id: String,
        name: String,
        kind: FoodProductKind,
        protein: Double? = nil,
        source: FoodProductSource? = nil,
        imageURL: URL? = nil,
        includePhoto: Bool = true,
        foodType: FoodType? = nil
    ) -> FoodProduct {
        FoodProduct(
            id: UUID(),
            externalId: id,
            name: name,
            brand: nil,
            kind: kind,
            imageURL: includePhoto ? (imageURL ?? URL(string: "https://example.com/\(id).jpg")) : nil,
            calories: 200,
            protein: protein,
            carbs: 20,
            fats: 8,
            amount: 100,
            unit: "g",
            source: source ?? (id.hasPrefix("ai-") ? .openAI : .openFoodFacts),
            foodType: foodType ?? (kind == .recipe ? .dish : .product)
        )
    }

    private static let recipeSectionsFixture = """
    {
      "version": 1,
      "locale": "uk-UA",
      "sections": [
        {
          "id": "healthyBreakfast",
          "recipes": [
            {
              "source": "spoonacular",
              "kind": "recipe",
              "externalId": "11",
              "title": "Oatmeal",
              "calories": 320,
              "cookTimeMinutes": 10,
              "imageURL": "https://img.spoonacular.com/recipes/oatmeal.jpg"
            }
          ]
        },
        {
          "id": "unknownSection",
          "recipes": [
            {
              "source": "spoonacular",
              "kind": "recipe",
              "title": "Skip me",
              "imageURL": "https://img.spoonacular.com/recipes/skip.jpg"
            }
          ]
        },
        {
          "id": "localCuisine",
          "recipes": [
            {
              "source": "tavily",
              "kind": "recipe",
              "title": "Borscht",
              "imageURL": "https://img.spoonacular.com/recipes/borscht.jpg"
            }
          ]
        }
      ]
    }
    """

    private static let duplicateCuisineSectionsFixture = """
    {
      "version": 1,
      "locale": "uk-UA",
      "sections": [
        {
          "id": "greek",
          "recipes": [
            {
              "source": "spoonacular",
              "kind": "recipe",
              "externalId": "21",
              "title": "Gyro",
              "calories": 470,
              "cookTimeMinutes": 24,
              "imageURL": "https://img.spoonacular.com/recipes/gyro.jpg"
            }
          ]
        },
        {
          "id": "asian",
          "recipes": [
            {
              "source": "spoonacular",
              "kind": "recipe",
              "externalId": "22",
              "title": "Pad Thai",
              "calories": 440,
              "cookTimeMinutes": 22,
              "imageURL": "https://img.spoonacular.com/recipes/padthai.jpg"
            }
          ]
        },
        {
          "id": "greek",
          "recipes": [
            {
              "source": "spoonacular",
              "kind": "recipe",
              "externalId": "23",
              "title": "Spanakopita",
              "calories": 350,
              "cookTimeMinutes": 40,
              "imageURL": "https://img.spoonacular.com/recipes/spanakopita.jpg"
            }
          ]
        },
        {
          "id": "asian",
          "recipes": [
            {
              "source": "spoonacular",
              "kind": "recipe",
              "externalId": "24",
              "title": "Ramen",
              "calories": 420,
              "cookTimeMinutes": 28,
              "imageURL": "https://img.spoonacular.com/recipes/ramen.jpg"
            }
          ]
        }
      ]
    }
    """

    private static let bilingualCatalogFixture = """
    {
      "version": 1,
      "sections": [
        {
          "id": "vegetablesGreens",
          "items": [
            {
              "id": "catalog.spinach",
              "name": { "en": "Spinach", "uk": "Шпинат" },
              "serving": { "en": "1 cup (30 g)", "uk": "1 чашка (30 г)" },
              "calories": 7,
              "protein": 0.9,
              "carbs": 1.1,
              "fats": 0.1,
              "amount": 30,
              "unit": "g",
              "imageURL": "https://upload.wikimedia.org/wikipedia/commons/3/37/Spinacia_oleracea_Spinazie_bloeiend.jpg"
            }
          ]
        }
      ]
    }
    """

    private static let catalogFixture = """
    {
      "version": 1,
      "sections": [
        {
          "id": "vegetablesGreens",
          "items": [
            {
              "source": "catalog",
              "kind": "product",
              "externalId": "catalog.spinach",
              "name": "Spinach",
              "summary": "1 cup (30 g)",
              "calories": 7,
              "protein": 0.9,
              "carbs": 1.1,
              "fats": 0.1,
              "amount": 30,
              "unit": "g"
            }
          ]
        }
      ]
    }
    """

    private static let spoonacularCatalogFixture = """
    {
      "version": 2,
      "source": "spoonacular",
      "sections": [
        {
          "id": "vegetablesGreens",
          "items": [
            {
              "source": "spoonacular",
              "kind": "ingredient",
              "externalId": "1145",
              "name": "broccoli",
              "title": "broccoli",
              "amount": 100,
              "unit": "g",
              "imageURL": "https://img.spoonacular.com/ingredients_250x250/broccoli.jpg"
            }
          ]
        }
      ]
    }
    """

    private static let pelmeniFixture = """
    {
      "items": [
        {
          "source": "ai",
          "kind": "recipe",
          "externalId": "ai-1",
          "title": "Домашні пельмені зі свининою та яловичиною",
          "name": "Домашні пельмені зі свининою та яловичиною",
          "calories": 520,
          "protein": 27,
          "carbs": 55,
          "fats": 22,
          "fiber": 3,
          "sugar": 5,
          "sodium": 780,
          "amount": 1,
          "unit": "serving",
          "serving": "1 порція (180 г)",
          "steps": ["Замісити тісто", "Зліпити пельмені", "Варити 8 хвилин"],
          "imageURL": "https://assistant.chatte.workers.dev/v1/generated-images/1"
        },
        {
          "source": "ai",
          "kind": "recipe",
          "externalId": "ai-2",
          "title": "Пельмені з куркою",
          "calories": 410
        },
        {
          "source": "ai",
          "kind": "recipe",
          "externalId": "ai-3",
          "title": "Пельмені з грибами",
          "calories": 450
        },
        {
          "source": "openfoodfacts",
          "kind": "product",
          "externalId": "4820196522652",
          "title": "Пельмені",
          "name": "Пельмені",
          "calories": 237,
          "protein": 9.7,
          "amount": 100,
          "unit": "g",
          "imageURL": ""
        }
      ]
    }
    """

    private static let detailsFixture = """
    {
      "item": {
        "source": "tavily",
        "kind": "recipe",
        "externalId": "tavily-1",
        "title": "Greek yogurt",
        "name": "Greek yogurt",
        "calories": 90,
        "protein": 16,
        "carbs": 7,
        "fats": 0,
        "fiber": 2,
        "sugar": 8,
        "sodium": 120,
        "amount": 1,
        "unit": "serving",
        "serving": "1 cup (227 g)",
        "ingredients": ["Greek yogurt 227 g", "honey 10 g"],
        "steps": ["Spoon yogurt into a bowl", "Drizzle honey"],
        "imageURL": "https://img.spoonacular.com/recipes/yogurt.jpg"
      }
    }
    """
}

@MainActor
private final class FakeSearchRecipeSections: RecipeSectionsFetching {
    var sections = RecipeBrowseSectionKind.catalogSections.map { kind in
        RecipeBrowseSection(id: kind, recipes: (0..<25).map { index in
            Recipe(id: UUID(), externalId: "\(kind.rawValue)-\(index)",
                   title: "\(L10n.tr(kind.titleKey)) \(index + 1)", imageURL: URL(string: "https://example.com/recipe.jpg"),
                   servings: 1, calories: 200, protein: 10, carbs: 20, fats: 8,
                   ingredients: [], steps: [], origin: .spoonacular, weightGrams: 250)
        })
    }
    var pageRequests: [(id: RecipeBrowseSectionKind, offset: Int, limit: Int)] = []
    var sectionsRequests = 0
    var failingSections = Set<RecipeBrowseSectionKind>()
    var failuresRemaining = 0
    var activeRequests = 0
    var maximumActiveRequests = 0

    func fetchSections(locale: String) async throws -> [RecipeBrowseSection] {
        sectionsRequests += 1
        return sections.map { RecipeBrowseSection(id: $0.id, recipes: Array($0.recipes.prefix(8))) }
    }

    func fetchSectionPage(id: RecipeBrowseSectionKind, locale: String, offset: Int, limit: Int) async throws -> RecipeSectionPage {
        pageRequests.append((id, offset, limit))
        activeRequests += 1
        maximumActiveRequests = max(maximumActiveRequests, activeRequests)
        defer { activeRequests -= 1 }
        try await Task.sleep(nanoseconds: 10_000_000)
        if failingSections.contains(id) { throw URLError(.timedOut) }
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw URLError(.networkConnectionLost)
        }
        let all = sections.first { $0.id == id }?.recipes ?? []
        let page = Array(all.dropFirst(offset).prefix(limit))
        return RecipeSectionPage(recipes: page, nextOffset: offset + page.count, hasMore: offset + page.count < all.count)
    }
}

private final class FakeAIFoodSearch: AIFoodSearching {
    var classifiedTypes: [String: FoodType] = [:]
    var classificationCalls = 0
    var matchedRecipeID: String?
    var matchingCalls = 0
    var foods: [FoodProduct] = []
    var recipes: [Recipe] = []
    var catalog: [String: [FoodProduct]] = [:]
    var sectionCatalog: [String: [FoodProduct]] = [:]
    var detailsProduct: FoodProduct?
    var error: Error?
    var searchRecipeCalls = 0
    var catalogPageOffsets: [Int] = []
    var catalogPageRequests: [(id: String, limit: Int)] = []
    var defaultCatalogCalls = 0
    var catalogPageError: Error?
    var failingCatalogSectionIDs = Set<String>()

    func classifyFoods(_ products: [FoodProduct]) async throws -> [FoodProduct] {
        classificationCalls += 1
        return try products.map { product in
            guard let type = classifiedTypes[product.externalId] ?? product.resolvedFoodType else {
                throw URLError(.cannotLoadFromNetwork)
            }
            var resolved = product
            resolved.foodType = type
            return resolved
        }
    }

    func matchingRecipe(title: String, candidates: [Recipe]) async throws -> Recipe? {
        matchingCalls += 1
        return candidates.first { $0.externalId == matchedRecipeID }
    }

    func searchFoods(query: String) async throws -> [FoodProduct] {
        if let error { throw error }
        return foods
    }

    func searchRecipes(query: String) async throws -> [Recipe] {
        if let error { throw error }
        searchRecipeCalls += 1
        return recipes
    }

    func fetchDefaultCatalog() async throws -> [String: [FoodProduct]] {
        defaultCatalogCalls += 1
        return catalog
    }

    func fetchCatalogSection(id: String) async throws -> [FoodProduct] {
        try await fetchCatalogSectionPage(id: id, offset: 0, limit: 120).products
    }

    func fetchCatalogSectionPage(id: String, offset: Int, limit: Int) async throws -> FoodSearchCatalogPage {
        catalogPageOffsets.append(offset)
        catalogPageRequests.append((id, limit))
        if let catalogPageError { throw catalogPageError }
        if failingCatalogSectionIDs.contains(id) { throw URLError(.cannotLoadFromNetwork) }
        let all = sectionCatalog[id] ?? catalog[id] ?? []
        let slice = Array(all.dropFirst(max(0, offset)).prefix(max(0, limit)))
        return FoodSearchCatalogPage(
            products: slice,
            nextOffset: offset + slice.count,
            hasMore: offset + slice.count < all.count
        )
    }

    func enrichDetails(
        title: String,
        imageURL: URL?,
        source: String,
        kind: String
    ) async throws -> FoodProduct? {
        detailsProduct
    }
}

private final class FakeOpenFoodFacts: OpenFoodFactsSearching {
    var products: [FoodProduct] = []
    var calls = 0

    func searchProducts(query: String, number: Int) async throws -> [FoodProduct] {
        calls += 1
        return products
    }

    func searchCategory(tag: String, number: Int) async throws -> [FoodProduct] {
        try await searchProducts(query: tag, number: number)
    }

    func lookup(barcode: String) async throws -> BarcodeProduct {
        throw BarcodeLookupError.notFound
    }
}

private final class FakeSpoonacular: SpoonacularServiceProtocol {
    var recipes: [Recipe] = []
    var recipeSearchCalls = 0
    var recipeDetailsCalls = 0
    var ingredientDetailsCalls = 0
    var recipeDetailsDelayNanoseconds: UInt64 = 0
    var detailedRecipe: Recipe?
    var ingredients: [FoodProduct] = []
    var products: [FoodProduct] = []

    func searchRecipes(query: String, maxCalories: Int?, number: Int) async throws -> [Recipe] {
        recipeSearchCalls += 1
        return recipes
    }

    func recipeDetails(id: String) async throws -> Recipe {
        recipeDetailsCalls += 1
        if recipeDetailsDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: recipeDetailsDelayNanoseconds)
        }
        if let detailedRecipe { return detailedRecipe }
        return Recipe(
            id: UUID(),
            externalId: id,
            title: "Recipe",
            summary: nil,
            imageURL: nil,
            readyInMinutes: nil,
            servings: 1,
            calories: 100,
            protein: 10,
            carbs: 10,
            fats: 4,
            ingredients: [],
            steps: [],
            sourceName: nil
        )
    }

    func searchIngredients(query: String, number: Int) async throws -> [FoodProduct] { ingredients }

    func ingredientDetails(id: String, amount: Double, unit: String) async throws -> FoodProduct {
        ingredientDetailsCalls += 1
        return FoodProduct(
            id: UUID(),
            externalId: id,
            name: "Ingredient",
            brand: nil,
            kind: .ingredient,
            imageURL: nil,
            calories: 100,
            protein: 1,
            carbs: 1,
            fats: 1,
            amount: amount,
            unit: unit
        )
    }

    func searchProducts(query: String, number: Int) async throws -> [FoodProduct] { products }

    func productDetails(id: String) async throws -> FoodProduct {
        FoodProduct(
            id: UUID(),
            externalId: id,
            name: "Product",
            brand: nil,
            kind: .product,
            imageURL: nil,
            calories: 100,
            protein: 1,
            carbs: 1,
            fats: 1,
            amount: 100,
            unit: "g",
            source: .spoonacular
        )
    }

    func productByBarcode(_ barcode: String) async throws -> BarcodeProduct {
        BarcodeProduct(
            id: UUID(),
            barcode: barcode,
            name: "Barcode",
            brand: nil,
            quantityLabel: nil,
            servingSizeLabel: nil,
            imageURL: nil,
            caloriesPer100g: 100,
            proteinPer100g: 1,
            carbsPer100g: 1,
            fatsPer100g: 1,
            caloriesPerServing: nil,
            proteinPerServing: nil,
            carbsPerServing: nil,
            fatsPerServing: nil,
            source: .openFoodFacts
        )
    }
}

private final class FakeTextAnalysis: TextFoodAnalysisServiceProtocol {
    var analysis: FoodPhotoAnalysis?

    func analyze(
        text: String,
        mealType: MealType,
        userContext: AIAssistantUserContext?
    ) async throws -> FoodPhotoAnalysis {
        if let analysis { return analysis }
        throw FoodPhotoAnalysisError.invalidResponse
    }
}

private final class FakeVoiceRecorder: VoiceFoodAudioRecording {
    var isRecording = false
    var onPartialTranscript: ((String) -> Void)?
    var onUtteranceFinal: (() -> Void)?
    func requestPermission() async -> Bool { false }
    func startRecording() throws {}
    func stopRecording() throws -> Data { Data() }
    func cancelRecording() {}
    func normalizedPower() -> CGFloat { 0 }
}

private final class FakeVoiceTranscription: VoiceFoodTranscriptionServiceProtocol {
    func transcribe(audioData: Data, mimeType: String) async throws -> VoiceFoodTranscription {
        VoiceFoodTranscription(text: "", language: nil, model: nil)
    }

    func analyze(
        audioData: Data,
        mimeType: String,
        mealType: MealType,
        userContext: AIAssistantUserContext?
    ) async throws -> VoiceFoodAnalysis {
        VoiceFoodAnalysis(
            transcription: "",
            transcriptionLanguage: nil,
            analysis: FoodPhotoAnalysis(
                name: "",
                mealType: mealType,
                calories: 0,
                protein: 0,
                carbs: 0,
                fats: 0,
                fiber: 0,
                sugar: 0,
                sodium: 0,
                portionGrams: nil,
                portionMilliliters: nil,
                confidence: 0,
                notes: "",
                assistantMessage: ""
            )
        )
    }
}

private final class FoodSearchNavigationSpy: UINavigationController {
    var pushed: [UIViewController] = []

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        pushed.append(viewController)
    }
}

private final class CatalogHTTPProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: String], Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (status, headers, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
