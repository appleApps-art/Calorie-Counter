import CoreData
import XCTest
@testable import Calorie_Counter

final class FoodTypeDataTests: XCTestCase {
    func testSemanticTypeDoesNotDependOnDishWordsOrCatalogNamespace() {
        for name in ["помідорний суп", "Хачапурі", "김밥", "tomato", "soupless"] {
            let item = product(name: name)
            XCTAssertNil(item.resolvedFoodType, name)
            XCTAssertFalse(draft(item).toFoodEntry().opensAsRecipe, name)
            var classified = item
            classified.foodType = .dish
            XCTAssertTrue(draft(classified).toFoodEntry().opensAsRecipe, name)
        }
        var generic = product(name: "Хачапурі")
        generic.kind = .product
        generic.source = .catalog
        XCTAssertNil(generic.resolvedFoodType)
        generic.source = .spoonacular
        XCTAssertEqual(generic.resolvedFoodType, .product)
        generic.foodType = .dish
        XCTAssertEqual(generic.resolvedFoodType, .dish)
        generic.foodType = .product
        generic.steps = ["Composition metadata must not override an explicit product type"]
        XCTAssertEqual(generic.resolvedFoodType, .product)
    }

    func testNamespaceAndTypeSurviveDishDraftEntryRecipeRoundTripAndNutritionMerge() {
        for kind in [FoodProductKind.ingredient, .product] {
            var item = product(name: "Хачапурі")
            item.kind = kind
            item.foodType = .dish
            var details = item
            details.foodType = nil
            details.calories = 400
            let merged = item.mergingNutrition(from: details)
            XCTAssertEqual(merged.foodType, .dish)
            let entry = draft(merged).toFoodEntry().scaled(toGrams: 200)
            XCTAssertEqual(entry.foodType, .dish)
            let recipe = entry.asRecipe()
            XCTAssertEqual(recipe.catalogFoodKind, kind)
            XCTAssertEqual(recipe.catalogFoodID, item.externalId)
            XCTAssertEqual(recipe.foodType, .dish)
            let restored = ProductDetailsMath.draft(from: recipe)
            XCTAssertEqual(restored.catalogKind, kind)
            XCTAssertEqual(restored.catalogExternalId, item.externalId)
            XCTAssertEqual(restored.foodType, .dish)
            let catalog = FoodProduct(recipe: recipe)
            XCTAssertEqual(catalog.kind, kind)
            XCTAssertEqual(catalog.externalId, item.externalId)
            XCTAssertEqual(catalog.foodType, .dish)
        }
    }

    func testLegacyDishNeverTreatsUnqualifiedNumericFoodIDAsRecipeID() {
        var entry = draft(product(name: "Хачапурі")).toFoodEntry()
        entry.catalogKind = nil
        entry.foodType = .dish
        let recipe = entry.asRecipe()
        XCTAssertEqual(recipe.externalId, "product:123")
        XCTAssertEqual(recipe.catalogFoodID, "123")
        XCTAssertFalse(SearchRecipesUseCase.hasCatalogRecipeIdentity(recipe))
        entry.catalogExternalId = nil
        XCTAssertTrue(entry.asRecipe().externalId?.hasPrefix("product:diary-") == true)
        entry.ingredientLines = ["Борошно 100 г", "Сир 30 г"]
        entry.recipeSteps = ["Замісити тісто й запекти з сиром."]
        XCTAssertTrue(entry.asRecipe().externalId?.hasPrefix("diary-") == true)
        XCTAssertNil(entry.asRecipe().catalogFoodID)
        entry.catalogKind = .recipe
        entry.catalogExternalId = "456"
        XCTAssertEqual(entry.asRecipe().externalId, "456")
        XCTAssertTrue(SearchRecipesUseCase.hasCatalogRecipeIdentity(entry.asRecipe()))
    }

    @MainActor
    func testFoodTypePersistsThroughDiarySavedRecipesAndMealPlan() throws {
        let stack = CoreDataStack(inMemory: true)
        let foods = FoodEntryRepository(coreDataStack: stack)
        let recipes = RecipeRepository(coreDataStack: stack)
        var item = product(name: "Деруни")
        item.foodType = .dish
        let entry = draft(item).toFoodEntry()
        try foods.save(entry)
        stack.viewContext.reset()
        let stored = try XCTUnwrap(foods.fetchEntry(id: entry.id))
        XCTAssertEqual(stored.foodType, .dish)
        XCTAssertEqual(stored.catalogKind, .ingredient)
        XCTAssertEqual(stored.catalogExternalId, item.externalId)
        try recipes.save(stored.asRecipe())
        stack.viewContext.reset()
        let saved = try XCTUnwrap(recipes.fetchSaved().first)
        XCTAssertEqual(saved.foodType, .dish)
        XCTAssertEqual(saved.catalogFoodKind, .ingredient)
        XCTAssertEqual(saved.catalogFoodID, item.externalId)
        let plan = MealPlan(id: UUID(), title: "Week", weeks: 1, imageURL: nil, recipes: [saved], createdAt: Date())
        let object = CDMealPlan(context: stack.viewContext)
        MealPlanMapper.apply(plan, to: object)
        XCTAssertEqual(MealPlanMapper.map(object)?.recipes.first?.foodType, .dish)
        XCTAssertEqual(MealPlanMapper.map(object)?.recipes.first?.catalogFoodID, item.externalId)
    }

    @MainActor
    func testV3MigrationKeepsLegacyFoodUnresolvedAndPreservesData() throws {
        let bundleURL = try XCTUnwrap(Bundle(for: CoreDataStack.self).url(forResource: "CalorieCounter", withExtension: "momd"))
        let previous = try XCTUnwrap(NSManagedObjectModel(contentsOf: bundleURL.appendingPathComponent("CalorieCounterV3.mom")))
        let current = try XCTUnwrap(NSManagedObjectModel(contentsOf: bundleURL))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("legacy.sqlite")
        let old = NSPersistentStoreCoordinator(managedObjectModel: previous)
        let store = try old.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = old
        let object = NSEntityDescription.insertNewObject(forEntityName: "CDFoodEntry", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue("Хачапурі", forKey: "name")
        object.setValue("lunch", forKey: "mealType")
        object.setValue(Date(), forKey: "date")
        object.setValue("ingredient", forKey: "catalogKind")
        object.setValue("123", forKey: "catalogExternalId")
        object.setValue(250.0, forKey: "calories")
        try context.save()
        context.reset()
        try old.remove(store)
        let migrated = NSPersistentStoreCoordinator(managedObjectModel: current)
        _ = try migrated.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url,
            options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        let next = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        next.persistentStoreCoordinator = migrated
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDFoodEntry")
        let row = try XCTUnwrap(next.fetch(request).first)
        XCTAssertEqual(row.value(forKey: "name") as? String, "Хачапурі")
        XCTAssertEqual(row.value(forKey: "calories") as? Double, 250)
        XCTAssertEqual(row.value(forKey: "catalogExternalId") as? String, "123")
        XCTAssertNil(row.value(forKey: "foodType"))
        next.reset()
        for store in migrated.persistentStores { try migrated.remove(store) }
    }

    @MainActor
    func testMissingMacrosStayIncompleteThroughZeroDisplayConversionAndPersistence() throws {
        var item = product(name: "Хачапурі")
        item.protein = nil
        item.foodType = .dish
        let projected = draft(item)
        XCTAssertEqual(projected.protein, 0)
        XCTAssertEqual(projected.hasCompleteNutrition, false)
        let entry = projected.toFoodEntry()
        XCTAssertEqual(entry.hasCompleteNutrition, false)
        XCTAssertEqual(entry.asRecipe().hasCompleteNutrition, false)
        XCTAssertEqual(draft(FoodProduct(recipe: entry.asRecipe())).hasCompleteNutrition, false)
        let stack = CoreDataStack(inMemory: true)
        let foods = FoodEntryRepository(coreDataStack: stack)
        try foods.save(entry)
        stack.viewContext.reset()
        let stored = try XCTUnwrap(foods.fetchEntry(id: entry.id))
        XCTAssertEqual(stored.hasCompleteNutrition, false)
        let recipes = RecipeRepository(coreDataStack: stack)
        try recipes.save(stored.asRecipe())
        stack.viewContext.reset()
        XCTAssertEqual(try recipes.fetchSaved().first?.hasCompleteNutrition, false)
    }

    func testSearchAndRawProviderDecodersPreserveExplicitType() throws {
        let payload = Data(#"{"items":[{"externalId":"123","title":"Хачапурі","source":"spoonacular","kind":"ingredient","foodType":"dish"}]}"#.utf8)
        let mapped = try XCTUnwrap(AIFoodSearchService.decodeItems(from: payload).compactMap(AIFoodSearchService.mapFood).first)
        XCTAssertEqual(mapped.kind, .ingredient)
        XCTAssertEqual(mapped.foodType, .dish)
        let raw = Data(#"{"id":123,"name":"Хачапурі","foodType":"dish"}"#.utf8)
        let info = try JSONDecoder().decode(SpoonacularIngredientInformation.self, from: raw)
        XCTAssertEqual(SpoonacularMapper.mapIngredientInformation(info).foodType, .dish)
        let legacy = try JSONDecoder().decode(SpoonacularIngredientInformation.self, from: Data(#"{"id":123,"name":"Хачапурі"}"#.utf8))
        XCTAssertNil(SpoonacularMapper.mapIngredientInformation(legacy).resolvedFoodType)
    }

    func testProposalJSONPreservesTypeAndReadsLegacyUnknown() throws {
        let proposal = FoodLogProposal(name: "Хачапурі", mealType: .lunch, calories: 300, protein: 12, carbs: 40, fats: 10,
                                       source: "catalog", catalogExternalId: "123", catalogKind: .product, foodType: .dish)
        let decoded = try JSONDecoder().decode(FoodLogProposal.self, from: JSONEncoder().encode(proposal))
        XCTAssertEqual(decoded.foodType, .dish)
        XCTAssertTrue(decoded.toFoodEntry().opensAsRecipe)
        let legacy = try JSONDecoder().decode(FoodLogProposal.self, from: Data(#"{"name":"Хачапурі","mealType":"lunch","source":"catalog","catalogKind":"product"}"#.utf8))
        XCTAssertNil(legacy.foodType)
        XCTAssertNil(legacy.toFoodEntry().resolvedFoodType)
    }

    func testClassifierPreservesIdentityAndAcceptsOnlyCompleteResolvedResponse() async throws {
        let item = product(name: "Хачапурі")
        FoodTypeHTTPProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/food/classify")
            XCTAssertEqual(request.httpMethod, "POST")
            return (200, Data(#"{"items":[{"source":"spoonacular","kind":"ingredient","externalId":"123","foodType":"dish"}]}"#.utf8))
        }
        let classified = try await service().classifyFoods([item])
        XCTAssertEqual(classified.first?.id, item.id)
        XCTAssertEqual(classified.first?.externalId, item.externalId)
        XCTAssertEqual(classified.first?.kind, .ingredient)
        XCTAssertEqual(classified.first?.foodType, .dish)
    }

    func testClassifierRejectsMissingUnknownAndWrongIdentityInsteadOfProductFallback() async {
        let cases = [
            #"{"items":[]}"#,
            #"{"items":[{"source":"spoonacular","kind":"ingredient","externalId":"123"}]}"#,
            #"{"items":[{"source":"spoonacular","kind":"ingredient","externalId":"123","foodType":"unknown"}]}"#,
            #"{"items":[{"source":"spoonacular","kind":"recipe","externalId":"123","foodType":"dish"}]}"#
        ]
        for body in cases {
            FoodTypeHTTPProtocol.handler = { _ in (200, Data(body.utf8)) }
            do {
                _ = try await service().classifyFoods([product(name: "Хачапурі")])
                XCTFail("Invalid classification must remain retryable: \(body)")
            } catch { }
        }
    }

    func testSemanticRecipeMatchReturnsOnlyValidatedCandidateAndAllowsNoMatch() async throws {
        var item = product(name: "Рататуй")
        item.foodType = .dish
        var candidate = draft(item).toFoodEntry().asRecipe()
        candidate.externalId = "meal-123"
        FoodTypeHTTPProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/v1/food/match-recipe")
            return (200, Data(#"{"externalId":"meal-123"}"#.utf8))
        }
        let match = try await service().matchingRecipe(title: "Ratatouille", candidates: [candidate])
        XCTAssertEqual(match, candidate)
        FoodTypeHTTPProtocol.handler = { _ in (200, Data(#"{"externalId":null}"#.utf8)) }
        let unmatched = try await service().matchingRecipe(title: "Деруни", candidates: [candidate])
        XCTAssertNil(unmatched)
        for invalid in [#"{"externalId":"other"}"#, #"{}"#] {
            FoodTypeHTTPProtocol.handler = { _ in (200, Data(invalid.utf8)) }
            do {
                _ = try await service().matchingRecipe(title: "Деруни", candidates: [candidate])
                XCTFail("A recipe match must reference a provided full recipe")
            } catch { }
        }
    }

    private func product(name: String) -> FoodProduct {
        FoodProduct(id: UUID(), externalId: "123", name: name, brand: nil, kind: .ingredient, imageURL: nil,
                    calories: 200, protein: 10, carbs: 20, fats: 8, amount: 100, unit: "g", source: .spoonacular)
    }

    private func draft(_ product: FoodProduct) -> ProductDetailsDraft {
        ProductDetailsMath.draft(from: product, imageData: nil, mealType: .lunch, date: Date())
    }

    private func service() -> AIFoodSearchService {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FoodTypeHTTPProtocol.self]
        let session = URLSession(configuration: config)
        addTeardownBlock { session.invalidateAndCancel(); FoodTypeHTTPProtocol.handler = nil }
        return AIFoodSearchService(session: session)
    }
}

private final class FoodTypeHTTPProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let handler = try XCTUnwrap(Self.handler)
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() { }
}
