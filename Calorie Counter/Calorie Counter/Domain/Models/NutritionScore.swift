import Foundation

enum NutritionGrade: String, Equatable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"
}

enum FoodNutritionBadge: String, Equatable, CaseIterable {
    case highProtein
    case lowCarb
    case highFiber
    case lowSugar
    case balanced

    var title: String {
        switch self {
        case .highProtein: return L10n.tr("nutrition.badge.highProtein")
        case .lowCarb: return L10n.tr("nutrition.badge.lowCarb")
        case .highFiber: return L10n.tr("nutrition.badge.highFiber")
        case .lowSugar: return L10n.tr("nutrition.badge.lowSugar")
        case .balanced: return L10n.tr("nutrition.badge.balanced")
        }
    }
}

struct DailyValuePercents: Equatable {
    var protein: Double
    var fat: Double
    var carbs: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
}

struct FoodNutritionFacts: Equatable {
    var score: Int
    var grade: NutritionGrade
    var summary: String
    var badges: [FoodNutritionBadge]
    var dailyValue: DailyValuePercents
}

enum NutritionFactsCalculator {
    static let proteinDV = 50.0
    static let fatDV = 78.0
    static let carbsDV = 275.0
    static let fiberDV = 28.0
    static let sugarDV = 50.0
    static let sodiumDV = 2300.0

    static func facts(
        calories: Double,
        protein: Double,
        carbs: Double,
        fats: Double,
        fiber: Double,
        sugar: Double,
        sodium: Double
    ) -> FoodNutritionFacts {
        let dv = DailyValuePercents(
            protein: percent(protein, of: proteinDV),
            fat: percent(fats, of: fatDV),
            carbs: percent(carbs, of: carbsDV),
            fiber: percent(fiber, of: fiberDV),
            sugar: percent(sugar, of: sugarDV),
            sodium: percent(sodium, of: sodiumDV)
        )

        var score = 70.0
        if calories > 0 {
            score += min(20, (protein * 4 / calories) * 80)
        }
        score += min(15, fiber * 1.5)
        score -= min(20, sugar * 0.35)
        score -= min(15, sodium / 150)
        if calories > 700 {
            score -= 8
        }
        let clamped = Int(min(100, max(0, score.rounded())))
        let grade = grade(for: clamped)
        return FoodNutritionFacts(
            score: clamped,
            grade: grade,
            summary: summary(for: grade),
            badges: badges(calories: calories, protein: protein, carbs: carbs, fats: fats, fiber: fiber, sugar: sugar),
            dailyValue: dv
        )
    }

    static func facts(for entry: FoodEntry) -> FoodNutritionFacts {
        facts(
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fats: entry.fats,
            fiber: entry.fiber,
            sugar: entry.sugar,
            sodium: entry.sodium
        )
    }

    private static func percent(_ value: Double, of daily: Double) -> Double {
        guard daily > 0 else { return 0 }
        return (value / daily) * 100
    }

    private static func grade(for score: Int) -> NutritionGrade {
        switch score {
        case 85...100: return .a
        case 70..<85: return .b
        case 55..<70: return .c
        case 40..<55: return .d
        default: return .e
        }
    }

    private static func summary(for grade: NutritionGrade) -> String {
        switch grade {
        case .a: return L10n.tr("nutrition.grade.a")
        case .b: return L10n.tr("nutrition.grade.b")
        case .c: return L10n.tr("nutrition.grade.c")
        case .d: return L10n.tr("nutrition.grade.d")
        case .e: return L10n.tr("nutrition.grade.e")
        }
    }

    private static func badges(
        calories: Double,
        protein: Double,
        carbs: Double,
        fats: Double,
        fiber: Double,
        sugar: Double
    ) -> [FoodNutritionBadge] {
        var result: [FoodNutritionBadge] = []
        let proteinShare = calories > 0 ? (protein * 4) / calories : 0
        let carbShare = calories > 0 ? (carbs * 4) / calories : 0
        let fatShare = calories > 0 ? (fats * 9) / calories : 0
        if protein >= 20 || proteinShare >= 0.25 {
            result.append(.highProtein)
        }
        if carbs <= 20 || carbShare <= 0.2 {
            result.append(.lowCarb)
        }
        if fiber >= 5 {
            result.append(.highFiber)
        }
        if sugar <= 8 {
            result.append(.lowSugar)
        }
        if proteinShare >= 0.2 && carbShare >= 0.2 && fatShare >= 0.2 && proteinShare <= 0.45 && carbShare <= 0.55 {
            result.append(.balanced)
        }
        return result
    }
}
