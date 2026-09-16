#if DEBUG
import Foundation
import UIKit

enum QADataSeeder {
    private static let idsKey = "bity.qa.seeded.ids"

    static func apply(container: DIContainer, kind: QASeedKind) throws {
        try cleanup(container: container)
        guard kind != .none else { return }
        try completeOnboarding(container: container)
        applySettings(container: container)
        if kind == .filled {
            try seedFilled(container: container)
        }
    }

    static func cleanup(container: DIContainer) throws {
        let stored = seededIDs()
        for id in stored.recipes {
            try? container.recipeRepository.delete(id: id)
        }
        for id in stored.plans {
            try? container.mealPlanRepository.delete(id: id)
        }
        if !stored.pantry.isEmpty {
            try? container.deletePantryItemsUseCase.execute(ids: stored.pantry)
        }
        for id in stored.foods {
            try? container.foodEntryRepository.delete(id: id)
        }
        for id in stored.weights {
            try? container.weightEntryRepository.delete(id: id)
        }
        for id in stored.workouts {
            try? container.workoutEntryRepository.delete(id: id)
        }
        for id in stored.waters {
            try? container.waterEntryRepository.delete(id: id)
        }
        let photos = (try? container.progressPhotoRepository.fetchAll()) ?? []
        for photo in photos where stored.photos.contains(photo.id) {
            try? container.deleteProgressPhotoUseCase.execute(photo)
        }
        UserDefaults.standard.removeObject(forKey: idsKey)
    }

    private static func completeOnboarding(container: DIContainer) throws {
        var profile = try container.userProfileRepository.fetchProfile()
        profile.sex = .female
        profile.age = 28
        profile.heightCm = 168
        profile.weightKg = 62
        profile.targetWeightKg = 58
        profile.activityLevel = .moderate
        profile.goalType = .lose
        _ = try container.completeOnboardingUseCase.execute(profile: profile)
    }

    private static func applySettings(container: DIContainer) {
        var settings = container.appSettingsStore.settings
        settings.hasSeenAppRating = true
        settings.hasSeenAIIntro = true
        if let theme = QALaunchConfiguration.theme {
            settings.appearanceMode = theme
        }
        container.appSettingsStore.settings = settings
        AppAppearance.apply(settings.appearanceMode)
    }

    private static func seedFilled(container: DIContainer) throws {
        var record = SeededIDs()
        let saved = Array(QACatalog.recipes.prefix(4))
        for recipe in saved {
            try container.recipeRepository.save(recipe)
            record.recipes.append(recipe.id)
        }

        let plan = MealPlan(
            id: QACatalog.uuid("meal-plan"),
            title: "High-Protein Week",
            weeks: 1,
            imageURL: saved.first?.imageURL,
            recipes: Array(QACatalog.recipes.prefix(7)),
            createdAt: Date()
        )
        try container.mealPlanRepository.save(plan)
        record.plans.append(plan.id)

        let pantryNames = [
            ("Eggs", "12 pcs"),
            ("Greek Yogurt", "500 g"),
            ("Spinach", "200 g"),
            ("Chicken Breast", "400 g"),
            ("Olive Oil", "250 ml")
        ]
        for (index, pair) in pantryNames.enumerated() {
            let now = Date()
            let item = PantryItem(
                id: QACatalog.uuid("pantry-\(index)"),
                name: pair.0,
                quantityText: pair.1,
                amount: nil,
                unit: nil,
                useBy: Calendar.current.date(byAdding: .day, value: 5 + index, to: now),
                imageURL: QACatalog.imageURL(id: "pantry-\(index)", color: UIColor(red: 0.85, green: 0.9, blue: 0.7, alpha: 1)),
                imageData: QACatalog.jpeg(color: UIColor(red: 0.85, green: 0.9, blue: 0.7, alpha: 1), size: CGSize(width: 120, height: 120)),
                createdAt: now,
                updatedAt: now
            )
            try container.savePantryItemUseCase.execute(item)
            record.pantry.append(item.id)
        }

        let calendar = Calendar.current
        for dayOffset in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let calories = 1600 + Double((dayOffset * 37) % 400)
            let food = FoodEntry(
                id: QACatalog.uuid("food-\(dayOffset)"),
                name: "QA Bowl",
                mealType: .lunch,
                calories: calories,
                protein: 90,
                carbs: 140,
                fats: 45,
                fiber: 22,
                sugar: 18,
                sodium: 900,
                date: date,
                portionGrams: 350,
                source: QACatalog.sourceKey,
                isEaten: true
            )
            try container.foodEntryRepository.save(food)
            record.foods.append(food.id)

            let water = WaterEntry(
                id: QACatalog.uuid("water-\(dayOffset)"),
                amountMilliliters: 1800,
                date: date,
                source: QACatalog.sourceKey
            )
            try container.waterEntryRepository.save(water)
            record.waters.append(water.id)

            if dayOffset % 2 == 0 {
                let workout = WorkoutEntry(
                    id: QACatalog.uuid("workout-\(dayOffset)"),
                    name: "Strength",
                    durationMinutes: 40,
                    caloriesBurned: 280,
                    date: date,
                    source: QACatalog.sourceKey
                )
                try container.workoutEntryRepository.save(workout)
                record.workouts.append(workout.id)
            }

            let weight = WeightEntry(
                id: QACatalog.uuid("weight-\(dayOffset)"),
                weightKilograms: 62 - Double(dayOffset) * 0.08,
                date: date,
                source: QACatalog.sourceKey
            )
            try container.weightEntryRepository.save(weight)
            record.weights.append(weight.id)
        }

        let photoDates = [0, 7, 14]
        for (index, offset) in photoDates.enumerated() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            let front = try container.saveProgressPhotoUseCase.execute(
                imageData: QACatalog.jpeg(
                    color: UIColor(white: 0.82 - CGFloat(index) * 0.08, alpha: 1),
                    size: CGSize(width: 330, height: 384)
                ),
                kind: index == photoDates.count - 1 ? .baseline : .progress,
                pose: .front,
                date: date,
                awardsXP: false
            )
            record.photos.append(front.id)
            let side = try container.saveProgressPhotoUseCase.execute(
                imageData: QACatalog.jpeg(
                    color: UIColor(white: 0.74 - CGFloat(index) * 0.08, alpha: 1),
                    size: CGSize(width: 330, height: 384)
                ),
                kind: index == photoDates.count - 1 ? .baseline : .progress,
                pose: .side,
                date: date,
                awardsXP: false
            )
            record.photos.append(side.id)
        }

        save(record)
    }

    private struct SeededIDs: Codable {
        var recipes: [UUID] = []
        var plans: [UUID] = []
        var pantry: [UUID] = []
        var foods: [UUID] = []
        var weights: [UUID] = []
        var workouts: [UUID] = []
        var waters: [UUID] = []
        var photos: [UUID] = []
    }

    private static func seededIDs() -> SeededIDs {
        guard let data = UserDefaults.standard.data(forKey: idsKey),
              let decoded = try? JSONDecoder().decode(SeededIDs.self, from: data) else {
            return SeededIDs()
        }
        return decoded
    }

    private static func save(_ ids: SeededIDs) {
        if let data = try? JSONEncoder().encode(ids) {
            UserDefaults.standard.set(data, forKey: idsKey)
        }
    }
}
#endif
