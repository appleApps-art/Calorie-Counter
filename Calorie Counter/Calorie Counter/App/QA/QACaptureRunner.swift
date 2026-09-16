#if DEBUG
import UIKit

enum QACaptureRunner {
    private static var didStart = false

    static var outputDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QA", isDirectory: true)
    }

    static func startIfNeeded(from tabBar: MainTabBarController) {
        guard QALaunchConfiguration.capture, !didStart else { return }
        didStart = true
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let routes = routes(for: QALaunchConfiguration.captureSet)
        try? FileManager.default.removeItem(at: outputDirectory.appendingPathComponent("DONE.txt"))
        writeJSON(["set": QALaunchConfiguration.captureSet, "routes": routes.map(\.rawValue)], name: "CAPTURE_PLAN")
        Task { @MainActor in
            var failures: [String] = []
            try? await Task.sleep(nanoseconds: 900_000_000)
            for route in routes {
                tabBar.qaResetStack()
                try? await Task.sleep(nanoseconds: 250_000_000)
                tabBar.qaPerform(route)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if !capture(name: route.rawValue, window: tabBar.view.window) { failures.append(route.rawValue) }
            }
            writeJSON(["set": QALaunchConfiguration.captureSet, "completed": routes.count - failures.count, "failed": failures], name: "CAPTURE_RESULT")
            let done = outputDirectory.appendingPathComponent("DONE.txt")
            try? (failures.isEmpty ? "ok" : "failed: \(failures.joined(separator: ", "))").data(using: .utf8)?.write(to: done)
        }
    }

    private static func routes(for set: String) -> [QARoute] {
        switch set {
        case "responsive":
            return routes(for: "uicheck") + responsiveRoutes
        case "missing":
            return responsiveRoutes
        case "empty":
            return [.recipesSavedEmpty, .recipesMealPlansEmpty, .pantry, .progress]
        case "freemium":
            return [.progress]
        case "settings":
            return [.settings, .settingsNutrition, .settingsWeight, .settingsTheme, .settingsNotifications, .settingsHealth]
        case "uicheck":
            return [
                .home,
                .recipesAll,
                .recipesSaved,
                .recipesMealPlans,
                .recipesSearch,
                .recipesSearchEmpty,
                .recipesFilters,
                .recipesSection,
                .recipesCreate,
                .recipesCreateRecipe,
                .recipesCreateCustom,
                .recipesCreateMealPlan,
                .pantry,
                .pantrySelect,
                .pantrySelected,
                .pantryDelete,
                .pantryAdd,
                .fridgeResult,
                .pantryEdit,
                .recipeDetail,
                .recipeDetailIngredients,
                .recipeDetailInstructions,
                .mealPlanPreview,
                .progress,
                .progressLog,
                .progressPhotos,
                .settings,
                .settingsNutrition,
                .settingsWeight,
                .settingsTheme,
                .settingsNotifications,
                .settingsHealth
            ]
        default:
            return [
                .recipesAll,
                .recipesSaved,
                .recipesMealPlans,
                .recipesSearch,
                .recipesSearchEmpty,
                .recipesFilters,
                .recipesSection,
                .pantry,
                .pantrySelect,
                .pantrySelected,
                .pantryDelete,
                .pantryAdd,
                .fridgeResult,
                .pantryEdit,
                .recipeDetail,
                .mealPlanPreview,
                .progress,
                .progressLog,
                .progressPhotos,
                .settings
            ]
        }
    }

    private static let responsiveRoutes: [QARoute] = [
        .aiIntro, .aiChat, .aiMealSuggestion, .aiFoodSwap, .aiMealLogged, .aiHistory,
        .foodSearch, .foodSearchResults, .productDetails, .addFoodEntry, .foodRecipe, .editMeal,
        .textFood, .voiceFood, .voiceFoodResult, .photoFood, .photoFoodResult, .barcodeScanner,
        .logWeight, .logWorkout, .rewards, .rewardDetail,
        .onboardingWelcome, .onboardingGoal, .onboardingSex, .onboardingActivity,
        .onboardingAge, .onboardingBody, .onboardingHealth, .onboardingPlan, .appRating
    ]

    private static func capture(name: String, window: UIWindow?) -> Bool {
        guard let window else { return false }
        window.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let url = outputDirectory.appendingPathComponent("\(name).png")
        guard let data = image.pngData(), (try? data.write(to: url)) != nil else { return false }
        writeJSON(layoutDiagnostics(name: name, window: window), name: name)
        return true
    }

    private static func writeJSON(_ object: [String: Any], name: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: outputDirectory.appendingPathComponent("\(name).json"))
    }

    private static func layoutDiagnostics(name: String, window: UIWindow) -> [String: Any] {
        var nodes: [[String: Any]] = []
        func rect(_ frame: CGRect) -> [String: Double] {
            ["x": Double(frame.minX), "y": Double(frame.minY), "width": Double(frame.width), "height": Double(frame.height)]
        }
        func visit(_ view: UIView, path: String, clippingRect: CGRect, insideScrollView: Bool) {
            guard !view.isHidden, view.alpha > 0.01, !view.bounds.isEmpty else { return }
            let frame = view.convert(view.bounds, to: window)
            guard frame.intersects(window.bounds) else { return }
            let className = String(describing: type(of: view))
            let scrolls = insideScrollView || view is UIScrollView
            let nextClip = view.clipsToBounds ? clippingRect.intersection(frame) : clippingRect
            var node: [String: Any] = [
                "path": path, "class": className, "frame": rect(frame), "bounds": rect(view.bounds),
                "insideScrollView": scrolls, "ambiguousLayout": view.hasAmbiguousLayout
            ]
            if let identifier = view.accessibilityIdentifier { node["identifier"] = identifier }
            if let label = view as? UILabel, let text = label.text, !text.isEmpty {
                node["text"] = String(text.prefix(240))
                node["fontSize"] = Double(label.font.pointSize)
                node["numberOfLines"] = label.numberOfLines
                node["allowsFontShrinking"] = label.adjustsFontSizeToFitWidth
                if label.numberOfLines == 0 {
                    let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: 10000))
                    node["multilineHeightShortfall"] = Double(max(0, needed.height - label.bounds.height))
                }
            }
            if let button = view as? UIButton { node["buttonTitle"] = button.title(for: .normal) ?? button.configuration?.title ?? "" }
            if let scroll = view as? UIScrollView {
                node["contentSize"] = ["width": Double(scroll.contentSize.width), "height": Double(scroll.contentSize.height)]
                node["contentOffset"] = ["x": Double(scroll.contentOffset.x), "y": Double(scroll.contentOffset.y)]
            }
            if view is UILabel || view is UIControl {
                node["horizontalWindowOverflow"] = frame.minX < window.bounds.minX - 1 || frame.maxX > window.bounds.maxX + 1
                let visible = clippingRect.intersection(frame)
                node["ancestorClipCandidate"] = visible.isNull || visible.width < frame.width - 1 || visible.height < frame.height - 1
            }
            nodes.append(node)
            for (index, child) in view.subviews.enumerated() {
                visit(child, path: "\(path)/\(index):\(String(describing: type(of: child)))", clippingRect: nextClip, insideScrollView: scrolls)
            }
        }
        visit(window, path: "window", clippingRect: window.bounds, insideScrollView: false)
        var controllers: [String] = []
        func collect(_ controller: UIViewController?) {
            guard let controller else { return }
            controllers.append(String(describing: type(of: controller)))
            if let navigation = controller as? UINavigationController { collect(navigation.topViewController) }
            else if let tab = controller as? UITabBarController { collect(tab.selectedViewController) }
            else { controller.children.forEach { collect($0) } }
            collect(controller.presentedViewController)
        }
        collect(window.rootViewController)
        let safe = window.safeAreaInsets
        return [
            "route": name, "viewport": rect(window.bounds), "scale": Double(window.screen.scale),
            "safeAreaInsets": ["top": Double(safe.top), "left": Double(safe.left), "bottom": Double(safe.bottom), "right": Double(safe.right)],
            "idiom": window.traitCollection.userInterfaceIdiom.rawValue,
            "contentSizeCategory": window.traitCollection.preferredContentSizeCategory.rawValue,
            "interfaceStyle": window.traitCollection.userInterfaceStyle.rawValue,
            "controllers": controllers, "visibleViews": nodes,
            "diagnosticNote": "Clip and overflow entries are candidates for visual review, including intentional scrolling. Barcode route renders camera chrome with appearance callbacks suppressed; hardware sessions are not exercised."
        ]
    }
}
#endif
