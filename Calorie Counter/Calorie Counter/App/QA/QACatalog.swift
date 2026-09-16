#if DEBUG
import UIKit

enum QACatalog {
    static let sourceKey = "qa"

    static func imageURL(id: String, color: UIColor) -> URL {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QAImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(id).jpg")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? jpeg(color: color).write(to: url)
        }
        return url
    }

    static func jpeg(color: UIColor, size: CGSize = CGSize(width: 360, height: 240)) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.82) ?? Data()
    }

    static func recipe(
        id: String,
        title: String,
        minutes: Int,
        calories: Double,
        protein: Double,
        carbs: Double,
        fats: Double,
        color: UIColor,
        ingredients: [String],
        tags: [String]
    ) -> Recipe {
        Recipe(
            id: uuid(id),
            externalId: "qa-\(id)",
            title: title,
            summary: tags.joined(separator: " · "),
            imageURL: imageURL(id: id, color: color),
            readyInMinutes: minutes,
            servings: 2,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fats: fats,
            ingredients: ingredients.enumerated().map { index, name in
                RecipeIngredient(
                    id: "\(id)-\(index)",
                    name: name,
                    amount: 80,
                    unit: "g",
                    originalText: "80 g \(name)"
                )
            },
            steps: [
                "Prep \(title.lowercased()).",
                "Cook for \(minutes) minutes.",
                "Serve warm."
            ],
            sourceName: "QA",
            origin: .catalog
        )
    }

    static var recipes: [Recipe] {
        [
            recipe(id: "quinoa", title: "Chicken Quinoa Bowl", minutes: 20, calories: 320, protein: 28, carbs: 32, fats: 9, color: UIColor(red: 0.93, green: 0.62, blue: 0.32, alpha: 1), ingredients: ["chicken", "quinoa", "avocado"], tags: ["healthy recipes", "chosen"]),
            recipe(id: "salmon", title: "Grilled Salmon", minutes: 18, calories: 410, protein: 34, carbs: 6, fats: 22, color: UIColor(red: 0.95, green: 0.45, blue: 0.38, alpha: 1), ingredients: ["salmon", "lemon", "dill"], tags: ["healthy recipes", "chosen"]),
            recipe(id: "smoothie", title: "Fruit Smoothie Bowl", minutes: 10, calories: 280, protein: 8, carbs: 48, fats: 6, color: UIColor(red: 0.98, green: 0.55, blue: 0.62, alpha: 1), ingredients: ["banana", "berries", "yogurt"], tags: ["healthy breakfast"]),
            recipe(id: "avocado", title: "Avocado Toast", minutes: 8, calories: 310, protein: 9, carbs: 28, fats: 18, color: UIColor(red: 0.45, green: 0.72, blue: 0.38, alpha: 1), ingredients: ["avocado", "bread", "egg"], tags: ["healthy breakfast"]),
            recipe(id: "herb-chicken", title: "Herb Roasted Chicken", minutes: 25, calories: 390, protein: 36, carbs: 12, fats: 16, color: UIColor(red: 0.86, green: 0.52, blue: 0.28, alpha: 1), ingredients: ["chicken", "herbs", "potato"], tags: ["quick lunch"]),
            recipe(id: "primavera", title: "Pasta Primavera", minutes: 22, calories: 450, protein: 16, carbs: 62, fats: 14, color: UIColor(red: 0.98, green: 0.82, blue: 0.38, alpha: 1), ingredients: ["pasta", "zucchini", "tomato"], tags: ["quick lunch"]),
            recipe(id: "steak", title: "Beef Steak & Veggies", minutes: 30, calories: 520, protein: 42, carbs: 18, fats: 28, color: UIColor(red: 0.72, green: 0.28, blue: 0.22, alpha: 1), ingredients: ["beef", "broccoli", "pepper"], tags: ["dinner", "main course"]),
            recipe(id: "peppers", title: "Stuffed Bell Peppers", minutes: 35, calories: 360, protein: 22, carbs: 34, fats: 12, color: UIColor(red: 0.92, green: 0.32, blue: 0.28, alpha: 1), ingredients: ["pepper", "rice", "beef"], tags: ["dinner", "main course"]),
            recipe(id: "tacos", title: "Fish Tacos", minutes: 20, calories: 340, protein: 24, carbs: 30, fats: 12, color: UIColor(red: 0.98, green: 0.72, blue: 0.28, alpha: 1), ingredients: ["fish", "tortilla", "cabbage"], tags: ["mexican"]),
            recipe(id: "burrito", title: "Chicken Burrito Bowl", minutes: 18, calories: 430, protein: 32, carbs: 46, fats: 12, color: UIColor(red: 0.86, green: 0.42, blue: 0.22, alpha: 1), ingredients: ["chicken", "rice", "beans"], tags: ["mexican"]),
            recipe(id: "pizza", title: "Margherita Pizza", minutes: 16, calories: 480, protein: 18, carbs: 58, fats: 16, color: UIColor(red: 0.92, green: 0.38, blue: 0.28, alpha: 1), ingredients: ["dough", "tomato", "mozzarella"], tags: ["italian"]),
            recipe(id: "risotto", title: "Mushroom Risotto", minutes: 32, calories: 410, protein: 12, carbs: 54, fats: 14, color: UIColor(red: 0.78, green: 0.62, blue: 0.42, alpha: 1), ingredients: ["rice", "mushroom", "parmesan"], tags: ["italian"]),
            recipe(id: "gyro", title: "Lamb Gyro", minutes: 24, calories: 470, protein: 28, carbs: 38, fats: 20, color: UIColor(red: 0.72, green: 0.52, blue: 0.32, alpha: 1), ingredients: ["lamb", "pita", "tzatziki"], tags: ["greek"]),
            recipe(id: "spanakopita", title: "Spanakopita", minutes: 40, calories: 350, protein: 14, carbs: 28, fats: 18, color: UIColor(red: 0.42, green: 0.62, blue: 0.32, alpha: 1), ingredients: ["spinach", "feta", "phyllo"], tags: ["greek"]),
            recipe(id: "padthai", title: "Pad Thai", minutes: 22, calories: 440, protein: 20, carbs: 58, fats: 14, color: UIColor(red: 0.96, green: 0.62, blue: 0.22, alpha: 1), ingredients: ["noodles", "shrimp", "peanut"], tags: ["asian"]),
            recipe(id: "ramen", title: "Miso Ramen", minutes: 28, calories: 420, protein: 18, carbs: 52, fats: 14, color: UIColor(red: 0.82, green: 0.48, blue: 0.22, alpha: 1), ingredients: ["noodles", "miso", "egg"], tags: ["asian"])
        ]
    }

    static func recipes(matching query: String) -> [Recipe] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return recipes }
        if needle.contains("zzzz") || needle.contains("noresult") { return [] }
        return recipes.filter { recipe in
            let haystack = ([recipe.title, recipe.summary ?? ""] + recipe.ingredients.map(\.name))
                .joined(separator: " ")
                .lowercased()
            return needle.split(separator: " ").contains { haystack.contains($0) }
        }
    }

    static func uuid(_ key: String) -> UUID {
        UUID(uuidString: String(format: "AAAAAAAA-0000-4000-8000-%012d", stableHash(key)))
            ?? UUID()
    }

    private static func stableHash(_ value: String) -> Int {
        abs(value.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }) % 1_000_000_000_000
    }
}
#endif
