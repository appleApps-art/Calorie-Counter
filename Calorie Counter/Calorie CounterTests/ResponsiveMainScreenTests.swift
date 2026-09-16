import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class ResponsiveMainScreenTests: XCTestCase {
    private let sizes = [
        CGSize(width: 375, height: 667), CGSize(width: 440, height: 956),
        CGSize(width: 834, height: 1210), CGSize(width: 320, height: 600)
    ]
    private var window: UIWindow?
    private var hostedSizeConstraints: [NSLayoutConstraint] = []

    override func tearDown() {
        window?.isHidden = true
        window = nil
        hostedSizeConstraints = []
        super.tearDown()
    }

    func testMainScreenNibColumnsStayCenteredAndFitEveryViewport() throws {
        // Load the actual screen nibs without starting their repositories, subscriptions, or network work.
        let screens = ["HomeViewController", "SettingsViewController", "AIAssistantViewController", "RecipesViewController"]
        for name in screens {
            let owner = ResponsiveNibOutletOwner()
            let objects = UINib(nibName: name, bundle: Bundle(for: HomeViewController.self)).instantiate(withOwner: owner, options: nil)
            let root = try XCTUnwrap(objects.compactMap { $0 as? UIView }.first, name)
            let controller = BaseViewController(nibName: name)
            controller.view = root
            let column = try XCTUnwrap(root.subviews.compactMap { $0 as? UIScrollView }.max { $0.bounds.height < $1.bounds.height }, name)
            let readable = try XCTUnwrap(root.constraints.first {
                $0.firstAttribute == .width && $0.relation == .lessThanOrEqual && $0.constant == 760
            }?.firstItem as? UIView, "\(name): readable container must unarchive as a real view")
            XCTAssertFalse(readable.isUserInteractionEnabled)
            host(controller, size: sizes[0])
            for size in sizes {
                resize(controller, to: size)
                assertReadableColumn(column, in: root, context: "\(name) \(size)")
                assertReadableColumn(readable, in: root, context: "\(name) readable container \(size)")
            }
        }
    }

    func testHomeDiaryCardsRemainReadableAndWithinTheScrollContent() throws {
        let harness = TestHarness()
        try harness.food.save(harness.foodEntry(name: "Курка з кіноа, запеченими овочами та йогуртовим соусом", mealType: .lunch))
        let controller = HomeViewController(viewModel: harness.homeViewModel())
        host(controller, size: sizes[0])
        for size in sizes {
            resize(controller, to: size)
            let scroll = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIScrollView }.first)
            assertReadableColumn(scroll, in: controller.view, context: "Home \(size)")
            XCTAssertLessThanOrEqual(scroll.contentSize.width, scroll.bounds.width + 1, "Home must scroll vertically without sideways drift")
            let cards = descendants(controller.view).compactMap { $0 as? MealCardView }
            XCTAssertEqual(cards.count, 4)
            for card in cards {
                let frame = card.convert(card.bounds, to: scroll)
                XCTAssertEqual(frame.midX, scroll.bounds.midX, accuracy: 1, "Diary card must remain centered")
                XCTAssertEqual(card.bounds.width, min(scroll.bounds.width - 32, 680), accuracy: 1)
                XCTAssertGreaterThan(card.bounds.height, 40)
                XCTAssertLessThanOrEqual(frame.maxY, scroll.contentSize.height + 1, "Diary content must remain reachable by scrolling")
                assertLabelBounds(in: card, context: "Home diary \(size)")
            }
            if size.height <= 667 {
                XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height, "A short Home screen must scroll to its lower content")
            }
        }
    }

    func testRecipeCardsTruncateTitlesAfterTwoLinesWithoutOverlappingPhoto() throws {
        for size in sizes {
            let (controller, cards) = makeRecipeGrid()
            host(controller, size: size)
            XCTAssertEqual(cards.count, 3)
            for card in cards { try assertRecipeCard(card, context: "Recipe card \(size)") }
            let firstFrame = cards[0].convert(cards[0].bounds, to: controller.view)
            let secondFrame = cards[1].convert(cards[1].bounds, to: controller.view)
            XCTAssertEqual(firstFrame.width, secondFrame.width, accuracy: 1)
            XCTAssertLessThan(firstFrame.maxX, secondFrame.minX)
            XCTAssertEqual(cards[0].bounds.height, cards[1].bounds.height, accuracy: 1, "Short and long titles share an aligned card row")
        }
    }

    func testRecipeCardGridRecomputesHeightWhenTheSameViewResizes() throws {
        let (controller, cards) = makeRecipeGrid()
        let tablet = CGSize(width: 834, height: 1210)
        host(controller, size: tablet)
        let originalHeights = cards.map { $0.bounds.height }
        let originalWidths = cards.map { $0.bounds.width }
        resize(controller, to: CGSize(width: 320, height: 600))
        for (index, card) in cards.enumerated() {
            XCTAssertLessThan(card.bounds.width, originalWidths[index])
            XCTAssertLessThan(card.bounds.height, originalHeights[index], "Card geometry should adapt to the resized canvas")
            try assertRecipeCard(card, context: "Recipe card resized to 320")
        }
        resize(controller, to: tablet)
        for (index, card) in cards.enumerated() {
            XCTAssertEqual(card.bounds.height, originalHeights[index], accuracy: 1, "Repeated resize must restore the original height")
            XCTAssertEqual(card.bounds.width, originalWidths[index], accuracy: 1)
            try assertRecipeCard(card, context: "Recipe card restored to iPad")
        }
    }

    func testAssistantLongMessageFitsItsColumnAtEveryViewport() throws {
        let harness = TestHarness()
        let service = ResponsiveNoRequestAssistantService()
        let text = "Можу запропонувати поживний обід із куркою, кіноа та сезонними овочами. Підкажіть, будь ласка, скільки часу у вас є на приготування і чи є продукти, яких ви уникаєте?"
        for size in sizes {
            let model = AIAssistantViewModel(aiAssistantService: service, fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                foodEntryRepository: harness.food, waterEntryRepository: harness.water,
                userGoalsRepository: harness.goals, workoutEntryRepository: harness.workout
            ))
            model.messages.value = [AIChatItem(kind: .assistant(text))]
            let controller = AIAssistantViewController(viewModel: model)
            host(controller, size: size)
            let table = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UITableView }.first)
            assertReadableColumn(table, in: controller.view, context: "AI \(size)")
            XCTAssertEqual(table.numberOfRows(inSection: 0), 1)
            let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)))
            let label = try XCTUnwrap(descendants(cell).compactMap { $0 as? UILabel }.first { $0.text == text })
            XCTAssertEqual(label.numberOfLines, 0)
            let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height
            XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed, "Assistant response must show all its lines at \(size)")
            assertLabelBounds(in: cell.contentView, context: "AI message \(size)")
        }
        XCTAssertEqual(service.requestCount, 0, "Layout fixtures must not make AI requests")
    }

    private func makeRecipeGrid() -> (UIViewController, [RecipeCardView]) {
        let controller = BaseViewController(nibName: "")
        controller.view = UIView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(stack)
        let guide = controller.view.makeReadableContentGuide()
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16)
        ])
        let titles = ["Кіноа з куркою\nта овочами", "Омлет", "Запечена риба\nз гарніром"]
        RecipeCardGrid.appendCards(to: stack, count: titles.count) { index, card in
            card.configure(Recipe(
                id: UUID(), externalId: nil, title: titles[index], summary: nil, imageURL: nil,
                readyInMinutes: 20, servings: 1, calories: 420, protein: 34, carbs: 42, fats: 13,
                ingredients: [], steps: [], sourceName: nil
            ))
        }
        return (controller, descendants(stack).compactMap { $0 as? RecipeCardView })
    }

    private func assertRecipeCard(_ card: RecipeCardView, context: String) throws {
        let title = try XCTUnwrap(descendants(card).compactMap { $0 as? UILabel }.first { $0.accessibilityIdentifier == "recipeCard.title" }, context)
        let photo = try XCTUnwrap(descendants(card).compactMap { $0 as? UIImageView }.max { $0.bounds.height < $1.bounds.height }, context)
        let titleFrame = title.convert(title.bounds, to: card)
        let photoFrame = photo.convert(photo.bounds, to: card)
        XCTAssertEqual(title.numberOfLines, 2)
        XCTAssertEqual(title.lineBreakMode, .byTruncatingTail)
        XCTAssertGreaterThanOrEqual(title.bounds.height, 42, "\(context): title needs its full line height")
        XCTAssertGreaterThan(titleFrame.minY, photoFrame.maxY, "\(context): title overlaps the photo")
        XCTAssertLessThanOrEqual(titleFrame.maxY, card.bounds.height + 1, "\(context): title escapes the card")
        XCTAssertGreaterThanOrEqual(titleFrame.minX, 0)
        XCTAssertLessThanOrEqual(titleFrame.maxX, card.bounds.width + 1)
        XCTAssertFalse(title.adjustsFontSizeToFitWidth, "Card titles must retain readable type instead of shrinking")
        XCTAssertEqual(card.bounds.height, card.intrinsicContentSize.height, accuracy: 1, context)
    }

    private func assertReadableColumn(_ column: UIView, in root: UIView, context: String) {
        let frame = column.convert(column.bounds, to: root)
        let safe = root.safeAreaLayoutGuide.layoutFrame
        XCTAssertGreaterThan(frame.width, 0, context)
        XCTAssertEqual(frame.width, min(safe.width, 760), accuracy: 1, context)
        XCTAssertEqual(frame.midX, safe.midX, accuracy: 1, context)
        XCTAssertGreaterThanOrEqual(frame.minX, safe.minX - 1, context)
        XCTAssertLessThanOrEqual(frame.maxX, safe.maxX + 1, context)
    }

    private func assertLabelBounds(in view: UIView, context: String) {
        for label in descendants(view).compactMap({ $0 as? UILabel }) {
            guard !isHidden(label), let text = label.text, !text.isEmpty else { continue }
            let frame = label.convert(label.bounds, to: view)
            XCTAssertGreaterThanOrEqual(frame.minX, -1, "\(context): \(text)")
            XCTAssertLessThanOrEqual(frame.maxX, view.bounds.width + 1, "\(context): \(text)")
            if label.numberOfLines == 0 {
                let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height
                XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed, "\(context): clipped \(text)")
            }
        }
    }

    private func host(_ controller: UIViewController, size: CGSize) {
        let animationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsEnabled) }
        window?.isHidden = true
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.overrideUserInterfaceStyle = .light
        host.addChild(controller)
        host.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: .large), forChild: controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(controller.view)
        // A window can adopt the simulator's screen size; required child dimensions make the tested canvas explicit.
        hostedSizeConstraints = [
            controller.view.widthAnchor.constraint(equalToConstant: size.width),
            controller.view.heightAnchor.constraint(equalToConstant: size.height)
        ]
        NSLayoutConstraint.activate(hostedSizeConstraints + [
            controller.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            controller.view.topAnchor.constraint(equalTo: host.view.topAnchor)
        ])
        controller.didMove(toParent: host)
        window.makeKeyAndVisible()
        self.window = window
        resize(controller, to: size)
    }

    private func resize(_ controller: UIViewController, to size: CGSize) {
        hostedSizeConstraints[0].constant = size.width
        hostedSizeConstraints[1].constant = size.height
        for _ in 0..<4 {
            controller.view.superview?.setNeedsLayout()
            controller.view.superview?.layoutIfNeeded()
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
        XCTAssertEqual(controller.view.bounds.width, size.width, accuracy: 0.5)
        XCTAssertEqual(controller.view.bounds.height, size.height, accuracy: 0.5)
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
    private func isHidden(_ view: UIView) -> Bool { view.isHidden || (view.superview.map(isHidden) ?? false) }
}

private final class ResponsiveNibOutletOwner: NSObject {
    private var outlets: [String: Any] = [:]
    override func setValue(_ value: Any?, forUndefinedKey key: String) { outlets[key] = value }
}

private final class ResponsiveNoRequestAssistantService: AIAssistantServiceProtocol {
    private(set) var requestCount = 0
    func chat(_ request: AIAssistantChatRequest) async throws -> AIAssistantChatResponse {
        requestCount += 1
        throw NSError(domain: "ResponsiveLayoutUnexpectedRequest", code: 1)
    }
}
