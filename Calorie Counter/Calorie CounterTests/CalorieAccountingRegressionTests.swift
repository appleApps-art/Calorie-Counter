import CoreData
import XCTest
@testable import Calorie_Counter

@MainActor
final class CalorieAccountingRegressionTests: XCTestCase {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)!
        return result
    }
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func profile(weight: Double = 100) -> UserProfile {
        var result = UserProfile.empty
        result.sex = .male
        result.age = 30
        result.heightCm = 180
        result.weightKg = weight
        result.activityLevel = .moderate
        result.goalType = .lose
        return result
    }

    func testMacroTargetsFitCalorieBudgetAcrossProfiles() throws {
        let calculator = CalculateNutritionPlanUseCase()
        for sex in BiologicalSex.allCases {
            for goal in GoalType.allCases {
                for activity in ActivityLevel.allCases {
                    for weight in [40.0, 80, 100, 160] {
                        var p = profile(weight: weight)
                        p.sex = sex
                        p.age = 60
                        p.heightCm = 150
                        p.goalType = goal
                        p.activityLevel = activity
                        let goals = try XCTUnwrap(calculator.execute(profile: p)?.goals)
                        let energy = goals.proteinTarget * 4 + goals.carbsTarget * 4 + goals.fatsTarget * 9
                        XCTAssertLessThanOrEqual(energy, goals.calorieTarget)
                        XCTAssertLessThan(goals.calorieTarget - energy, 4)
                        XCTAssertGreaterThanOrEqual(goals.carbsTarget, 0)
                    }
                }
            }
        }
    }

    func testInvalidWeightCannotProduceNutritionPlan() {
        for weight in [Double.nan, .infinity, -1, 0] {
            XCTAssertNil(CalculateNutritionPlanUseCase().execute(profile: profile(weight: weight)))
        }
    }

    func testWeightUpdateRecalculatesGoalsAndPreservesManualGoals() throws {
        let h = TestHarness()
        try h.profile.save(profile())
        let refresh = RefreshNutritionGoalsUseCase(profileRepository: h.profile, goalsRepository: h.goals, settingsStore: h.settings)
        try refresh.execute()
        XCTAssertEqual(try h.goals.fetchGoals().calorieTarget, 2569)
        try refresh.applyLatestWeight(WeightEntry(id: UUID(), weightKilograms: 80, date: now))
        XCTAssertEqual(try h.profile.fetchProfile().weightKg, 80)
        XCTAssertEqual(try h.goals.fetchGoals().calorieTarget, 2259)
        let custom = UserGoals.default
        try SaveUserGoalsUseCase(userGoalsRepository: h.goals, appSettingsStore: h.settings).execute(custom)
        try refresh.applyLatestWeight(WeightEntry(id: UUID(), weightKilograms: 75, date: now))
        XCTAssertEqual(try h.profile.fetchProfile().weightKg, 75)
        XCTAssertEqual(try h.goals.fetchGoals(), custom)
        XCTAssertFalse(h.settings.settings.automaticallyAdjustNutritionGoals)
    }

    func testLogWeightWiringOnlyUsesNewestMeasurement() throws {
        let container = DIContainer(coreDataStack: CoreDataStack(inMemory: true))
        // Isolate global preferences while exercising production wiring.
        let old = container.appSettingsStore.settings
        defer { container.appSettingsStore.settings = old }
        container.appSettingsStore.settings = .default
        try container.userProfileRepository.save(profile())
        _ = try container.logWeightUseCase.execute(weightKilograms: 80, date: now, syncToHealth: false, awardXP: false)
        _ = try container.logWeightUseCase.execute(weightKilograms: 100, date: now.addingTimeInterval(-86400), syncToHealth: false, awardXP: false)
        XCTAssertEqual(try container.userProfileRepository.fetchProfile().weightKg, 80)
        XCTAssertEqual(try container.fetchDailyDiaryUseCase.execute(for: now).goals.calorieTarget, 2259)
    }

    func testLegacyManualGoalsSurviveFirstRefreshAndProfileEdits() throws {
        let h = TestHarness()
        h.settings.settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertFalse(h.settings.settings.nutritionGoalModeResolved)
        try h.profile.save(profile())
        try h.goals.save(.default)
        let refresh = RefreshNutritionGoalsUseCase(profileRepository: h.profile, goalsRepository: h.goals, settingsStore: h.settings)
        try refresh.execute()
        XCTAssertFalse(h.settings.settings.automaticallyAdjustNutritionGoals)
        XCTAssertEqual(try h.goals.fetchGoals(), .default)
        _ = try UpdateProfileAndGoalsUseCase(userProfileRepository: h.profile, userGoalsRepository: h.goals, appSettingsStore: h.settings).execute(profile(weight: 80))
        XCTAssertEqual(try h.goals.fetchGoals(), .default)
    }

    func testExplicitGoalSelectionReplacesManualTargetsAndKeepsNewPlanOnRefresh() throws {
        for legacy in [false, true] {
            let h = TestHarness()
            try h.profile.save(profile())
            try SaveUserGoalsUseCase(userGoalsRepository: h.goals, appSettingsStore: h.settings).execute(.default)
            if legacy { h.settings.settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8)) }
            let update = UpdateProfileAndGoalsUseCase(userProfileRepository: h.profile, userGoalsRepository: h.goals, appSettingsStore: h.settings)
            for goal in [GoalType.maintain, .gain, .lose] {
                var next = profile()
                next.goalType = goal
                let expected = try XCTUnwrap(CalculateNutritionPlanUseCase().execute(profile: next)?.goals)
                _ = try update.execute(next, applyNutritionGoal: true)
                XCTAssertEqual(try h.profile.fetchProfile().goalType, goal)
                XCTAssertEqual(try h.goals.fetchGoals(), expected)
                XCTAssertTrue(h.settings.settings.automaticallyAdjustNutritionGoals)
                try RefreshNutritionGoalsUseCase(profileRepository: h.profile, goalsRepository: h.goals, settingsStore: h.settings).execute()
                XCTAssertEqual(try h.goals.fetchGoals(), expected)
            }
        }
    }

    func testIncompleteProfileDoesNotSilentlyApplyGoalSelection() throws {
        let h = TestHarness()
        try h.profile.save(profile())
        let update = UpdateProfileAndGoalsUseCase(userProfileRepository: h.profile, userGoalsRepository: h.goals, appSettingsStore: h.settings)
        XCTAssertThrowsError(try update.execute(.empty, applyNutritionGoal: true))
        XCTAssertEqual(try h.profile.fetchProfile().goalType, .lose)
    }

    func testLegacyCalculatedPlanIsRecognizedAndMacroBudgetRepaired() throws {
        let h = TestHarness()
        h.settings.settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        var p = profile()
        p.sex = .female
        p.age = 60
        p.heightCm = 150
        p.activityLevel = .sedentary
        try h.profile.save(p)
        let plan = try XCTUnwrap(CalculateNutritionPlanUseCase().execute(profile: p))
        let oldGoals = UserGoals(calorieTarget: plan.goals.calorieTarget, proteinTarget: 200, carbsTarget: 0, fatsTarget: 80, fiberTarget: plan.goals.fiberTarget, sugarTarget: plan.goals.sugarTarget, sodiumTarget: plan.goals.sodiumTarget, waterTargetMilliliters: plan.goals.waterTargetMilliliters)
        try h.goals.save(oldGoals)
        try RefreshNutritionGoalsUseCase(profileRepository: h.profile, goalsRepository: h.goals, settingsStore: h.settings).execute()
        XCTAssertTrue(h.settings.settings.automaticallyAdjustNutritionGoals)
        XCTAssertEqual(try h.goals.fetchGoals(), plan.goals)
        XCTAssertNotEqual(plan.goals, oldGoals)
    }

    func testLegacyStaleAutomaticPlanRecognizedFromWeightHistory() throws {
        let h = TestHarness()
        h.settings.settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        try h.profile.save(profile(weight: 80))
        try h.weight.save(WeightEntry(id: UUID(), weightKilograms: 100, date: now))
        try h.goals.save(XCTUnwrap(CalculateNutritionPlanUseCase().execute(profile: profile())?.goals))
        try RefreshNutritionGoalsUseCase(profileRepository: h.profile, goalsRepository: h.goals, settingsStore: h.settings, weightRepository: h.weight).execute()
        XCTAssertTrue(h.settings.settings.automaticallyAdjustNutritionGoals)
        XCTAssertEqual(try h.goals.fetchGoals().calorieTarget, 2259)
    }

    func testHealthActiveEnergyIncludesImportedWorkoutsOnlyOnce() {
        let imported = workout(300, source: HealthSyncSource.healthKit)
        let local = workout(100)
        let health = HealthDailyActivity(date: now, activeEnergyKilocalories: 500, steps: 6000)
        XCTAssertEqual(ActivityEnergyCalculator.total(workouts: [imported, local], healthActivity: health), 600)
        XCTAssertEqual(ActivityEnergyCalculator.total(workouts: [imported, local], healthActivity: nil), 400)
        let summary = DailyDiarySummary(date: now, foodEntries: [], waterEntries: [], workouts: [imported, local], waterMilliliters: 0, goals: .default, healthActivity: health)
        XCTAssertEqual(summary.burnedCalories, 600)
        XCTAssertEqual(summary.remainingCalories, 2000, "Activity must not be added twice to a goal already based on TDEE")
    }

    func testDailyActivityPersistenceReconcilesCorrectionsAndRemovals() throws {
        let stack = CoreDataStack(inMemory: true)
        var notifications = 0
        let store = HealthDailyActivityRepository(coreDataStack: stack, onChange: { notifications += 1 })
        let day = Calendar.current.startOfDay(for: now)
        let end = day.addingTimeInterval(86400)
        let first = HealthDailyActivity(date: day, activeEnergyKilocalories: 500, steps: 6000)
        try store.replace([first], from: day, to: end)
        try store.replace([first], from: day, to: end)
        XCTAssertEqual(try store.fetch(from: day, to: end), [first])
        XCTAssertEqual(notifications, 1)
        let corrected = HealthDailyActivity(date: day, activeEnergyKilocalories: nil, steps: 4000)
        try store.replace([corrected], from: day, to: end)
        XCTAssertEqual(try store.fetch(from: day, to: end), [corrected])
        try store.replace([], from: day, to: end)
        XCTAssertTrue(try store.fetch(from: day, to: end).isEmpty)
        XCTAssertEqual(notifications, 3)
    }

    func testMeasuredDailyEnergyTakesPrecedenceOverWorkoutCrossingMidnight() {
        let imported = workout(300, source: HealthSyncSource.healthKit)
        let beforeMidnight = HealthDailyActivity(date: now, activeEnergyKilocalories: 100, steps: nil)
        let afterMidnight = HealthDailyActivity(date: now.addingTimeInterval(86400), activeEnergyKilocalories: 200, steps: nil)
        let firstDay = ActivityEnergyCalculator.total(workouts: [imported], healthActivity: beforeMidnight)
        let secondDay = ActivityEnergyCalculator.total(workouts: [], healthActivity: afterMidnight)
        XCTAssertEqual(firstDay + secondDay, 300)
        XCTAssertEqual(ActivityEnergyCalculator.total(workouts: [imported], healthActivity: HealthDailyActivity(date: now, activeEnergyKilocalories: 0, steps: nil)), 0)
    }

    func testLongPeriodChartsUseDailyAveragesAndStatsUseActualDays() {
        for period in ProgressChartPeriod.allCases {
            let days = (0..<period.dayCount).map { calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: now))! }
            let points = days.map { point(date: $0, protein: 10) }
            let workouts = days.map { WorkoutEntry(id: UUID(), name: "Walk", durationMinutes: 20, caloriesBurned: 100, date: $0) }
            let calories = ProgressChartMath.calorieColumns(points: points, period: period, now: now, calendar: calendar)
            XCTAssertTrue(calories.allSatisfy { $0.calories == 100 && $0.proteinKcal == 40 })
            let columns = ProgressChartMath.expenditureColumns(workouts: workouts, period: period, now: now, calendar: calendar)
            XCTAssertTrue(columns.allSatisfy { $0.value == 100 })
            let daily = ProgressChartMath.dailyExpenditure(workouts: workouts, period: period, now: now, calendar: calendar)
            XCTAssertEqual(daily.count, period.dayCount)
            XCTAssertEqual(daily.reduce(0) { $0 + $1.value }, Double(period.dayCount * 100))
            XCTAssertEqual(daily.map(\.value).max(), 100)
        }
    }

    func testPreviousWeekExcludesCurrentWeekAndFuturePoints() {
        let points = (-14...1).map { offset in
            point(date: calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!, protein: offset >= -6 ? 20 : 10)
        }
        let previousEnd = calendar.date(byAdding: .day, value: -7, to: now)!
        let previous = ProgressChartMath.slice(points, period: .week, now: previousEnd, calendar: calendar)
        XCTAssertEqual(previous.count, 7)
        XCTAssertTrue(previous.allSatisfy { $0.protein == 10 })
        XCTAssertTrue(ProgressChartMath.insightText(points: points, fiberTarget: 25, now: now, calendar: calendar)?.contains("100%") == true)
    }

    func testV2StoreMigratesRecipesAndChatsWithoutLosingData() throws {
        let bundle = Bundle(for: CoreDataStack.self)
        let modelURL = try XCTUnwrap(bundle.url(forResource: "CalorieCounter", withExtension: "momd"))
        let oldModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL.appendingPathComponent("CalorieCounterV2.mom")))
        let currentModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("migration.sqlite")
        let oldCoordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        let oldStore = try oldCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = oldCoordinator
        let recipe = NSManagedObject(entity: oldModel.entitiesByName["CDSavedRecipe"]!, insertInto: context)
        recipe.setValue(UUID(), forKey: "id")
        recipe.setValue(now, forKey: "updatedAt")
        recipe.setValue("Breakfast", forKey: "title")
        recipe.setValue(400.0, forKey: "calories")
        let chat = NSManagedObject(entity: oldModel.entitiesByName["CDChatMessage"]!, insertInto: context)
        let conversationID = UUID()
        chat.setValue(UUID(), forKey: "id")
        chat.setValue(conversationID, forKey: "conversationID")
        chat.setValue("user", forKey: "role")
        chat.setValue("Breakfast ideas", forKey: "content")
        chat.setValue(now, forKey: "createdAt")
        try context.save()
        context.reset()
        try oldCoordinator.remove(oldStore)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: currentModel)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        defer { try? coordinator.remove(store) }
        let migrated = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        migrated.persistentStoreCoordinator = coordinator
        let recipes = try migrated.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDSavedRecipe"))
        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes.first?.value(forKey: "calories") as? Double, 400)
        XCTAssertNil(recipes.first?.value(forKey: "weightGrams"))
        let chats = try migrated.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDChatMessage"))
        XCTAssertEqual(chats.first?.value(forKey: "conversationID") as? UUID, conversationID)
        recipes.first?.setValue(300.0, forKey: "weightGrams")
        let activity = NSManagedObject(entity: currentModel.entitiesByName["CDDailyHealthActivity"]!, insertInto: migrated)
        activity.setValue(now, forKey: "date")
        activity.setValue(500.0, forKey: "activeEnergyKilocalories")
        try migrated.save()
        XCTAssertEqual(try migrated.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "CDDailyHealthActivity")), 1)
    }

    private func workout(_ calories: Double, source: String? = nil) -> WorkoutEntry {
        WorkoutEntry(id: UUID(), name: "Walk", durationMinutes: 20, caloriesBurned: calories, date: now, source: source)
    }
    private func point(date: Date, protein: Double) -> DailyMacroPoint {
        DailyMacroPoint(date: date, calories: 100, protein: protein, carbs: 10, fats: 2, fiber: 25, waterMilliliters: 0)
    }
}
