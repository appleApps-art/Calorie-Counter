import CoreData
import XCTest
@testable import Calorie_Counter

@MainActor
final class PersistenceTests: XCTestCase {
    func testFoodWaterWeightWorkoutProfileRoundTrip() throws {
        let harness = TestHarness()
        let food = harness.foodEntry(
            name: "Greek yogurt",
            source: "photo",
            healthSampleID: "abc"
        )
        try harness.food.save(food)
        try harness.water.save(
            WaterEntry(
                id: UUID(),
                amountMilliliters: 500,
                date: Date(),
                source: HealthSyncSource.healthKit,
                healthSampleID: "w1"
            )
        )
        try harness.weight.save(
            WeightEntry(id: UUID(), weightKilograms: 72.25, date: Date(), source: "manual")
        )
        try harness.workout.save(
            WorkoutEntry(
                id: UUID(),
                name: "HIIT",
                durationMinutes: 18,
                caloriesBurned: 190,
                date: Date(),
                source: HealthSyncSource.healthKit,
                healthSampleID: "wo1"
            )
        )
        var profile = try harness.profile.fetchProfile()
        profile.sex = .other
        profile.age = 33
        try harness.profile.save(profile)

        XCTAssertEqual(try harness.food.fetchEntry(id: food.id)?.source, "photo")
        XCTAssertEqual(try harness.food.fetchEntry(id: food.id)?.healthSampleID, "abc")
        XCTAssertEqual(try harness.water.fetchEntries(for: Date()).first?.healthSampleID, "w1")
        XCTAssertEqual(try harness.weight.fetchEntries().first?.weightKilograms, 72.25)
        XCTAssertEqual(try harness.workout.fetchEntries().first?.source, HealthSyncSource.healthKit)
        XCTAssertEqual(try harness.profile.fetchProfile().sex, .other)
        XCTAssertEqual(try harness.profile.fetchProfile().age, 33)
    }

    func testUpdatingFoodKeepsSameID() throws {
        let harness = TestHarness()
        var entry = harness.foodEntry(calories: 100)
        try harness.food.save(entry)
        entry = FoodEntry(
            id: entry.id,
            name: "Updated",
            mealType: .lunch,
            calories: 250,
            protein: entry.protein,
            carbs: entry.carbs,
            fats: entry.fats,
            fiber: entry.fiber,
            sugar: entry.sugar,
            sodium: entry.sodium,
            date: entry.date
        )
        try harness.food.save(entry)
        let all = try harness.food.fetchEntries(for: Date())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].name, "Updated")
        XCTAssertEqual(all[0].calories, 250)
    }

    func testFoodRecipePayloadRoundTrip() throws {
        let harness = TestHarness()
        let food = FoodEntry(
            id: UUID(),
            name: "Борщ",
            mealType: .snacks,
            calories: 180,
            protein: 8,
            carbs: 22,
            fats: 6,
            fiber: 4,
            sugar: 6,
            sodium: 400,
            date: Date(),
            portionGrams: 300,
            source: "text",
            ingredientLines: ["буряк 150g", "капуста 80g"],
            recipeSteps: ["Нарізати овочі", "Варити 40 хвилин"],
            catalogExternalId: "ai-borscht",
            catalogKind: .recipe
        )
        try harness.food.save(food)
        let loaded = try harness.food.fetchEntry(id: food.id)
        XCTAssertEqual(loaded?.ingredientLines, food.ingredientLines)
        XCTAssertEqual(loaded?.recipeSteps, food.recipeSteps)
        XCTAssertEqual(loaded?.catalogExternalId, "ai-borscht")
        XCTAssertEqual(loaded?.catalogKind, .recipe)
        XCTAssertEqual(loaded?.opensAsRecipe, true)
    }

    func testDeleteMissingIDsDoesNotThrow() throws {
        let harness = TestHarness()
        let missing = UUID()
        XCTAssertNoThrow(try harness.food.delete(id: missing))
        XCTAssertNoThrow(try harness.water.delete(id: missing))
        XCTAssertNoThrow(try harness.weight.delete(id: missing))
        XCTAssertNoThrow(try harness.workout.delete(id: missing))
    }

    func testGoalsDefaultInsertedOnFirstFetch() throws {
        let harness = TestHarness()
        XCTAssertEqual(try harness.goals.fetchGoals(), .default)
    }

    func testExistingSQLiteStoreMigratesWhenOptionalHealthFieldsAdded() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("bity-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let storeURL = folder.appendingPathComponent("CalorieCounter.sqlite")

        let legacy = legacyModel()
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: legacy)
        try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL
        )
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let food = NSEntityDescription.insertNewObject(forEntityName: "CDFoodEntry", into: context)
        food.setValue(UUID(), forKey: "id")
        food.setValue("Legacy oats", forKey: "name")
        food.setValue("breakfast", forKey: "mealType")
        food.setValue(Date(), forKey: "date")
        food.setValue(300.0, forKey: "calories")
        food.setValue(10.0, forKey: "protein")
        food.setValue(40.0, forKey: "carbs")
        food.setValue(5.0, forKey: "fats")
        food.setValue(3.0, forKey: "fiber")
        food.setValue(1.0, forKey: "sugar")
        food.setValue(20.0, forKey: "sodium")
        try context.save()
        try coordinator.remove(coordinator.persistentStores[0])

        guard
            let modelURL = Bundle(for: CoreDataStack.self)
                .url(forResource: "CalorieCounter", withExtension: "momd"),
            let current = NSManagedObjectModel(contentsOf: modelURL)
        else {
            XCTFail("Current Core Data model missing from app bundle")
            return
        }

        let container = NSPersistentContainer(name: "CalorieCounter", managedObjectModel: current)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]

        let loaded = expectation(description: "store load")
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 5)
        XCTAssertNil(loadError, "Adding optional Health fields should lightweight-migrate existing stores")
        let migrated = NSFetchRequest<NSManagedObject>(entityName: "CDFoodEntry")
        let rows = try container.viewContext.fetch(migrated)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.value(forKey: "name") as? String, "Legacy oats")
        XCTAssertNil(rows.first?.value(forKey: "healthSampleID"))
        XCTAssertNil(rows.first?.value(forKey: "source"))
    }

    private func legacyModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            entity(
                "CDFoodEntry",
                attributes: [
                    ("id", .UUIDAttributeType, false),
                    ("name", .stringAttributeType, false),
                    ("mealType", .stringAttributeType, false),
                    ("date", .dateAttributeType, false),
                    ("calories", .doubleAttributeType, false),
                    ("protein", .doubleAttributeType, false),
                    ("carbs", .doubleAttributeType, false),
                    ("fats", .doubleAttributeType, false),
                    ("fiber", .doubleAttributeType, false),
                    ("sugar", .doubleAttributeType, false),
                    ("sodium", .doubleAttributeType, false),
                    ("notes", .stringAttributeType, true),
                    ("portionGrams", .doubleAttributeType, true),
                    ("portionMilliliters", .doubleAttributeType, true),
                ]
            )
        ]
        return model
    }

    private func entity(
        _ name: String,
        attributes: [(String, NSAttributeType, Bool)]
    ) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = name
        entity.properties = attributes.map { name, type, optional in
            let attribute = NSAttributeDescription()
            attribute.name = name
            attribute.attributeType = type
            attribute.isOptional = optional
            return attribute
        }
        return entity
    }
}
