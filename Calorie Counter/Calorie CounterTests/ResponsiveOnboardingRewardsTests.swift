import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class ResponsiveOnboardingRewardsTests: XCTestCase {
    private let sizes = [
        CGSize(width: 375, height: 667), CGSize(width: 402, height: 874),
        CGSize(width: 440, height: 956), CGSize(width: 768, height: 1024),
        CGSize(width: 320, height: 600)
    ]
    private var window: UIWindow?
    private var hostedSizeConstraints: [NSLayoutConstraint] = []

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    func testOnboardingContentFitsWidthAndCanScrollToItsActions() throws {
        let screens: [(String, () -> UIViewController)] = [
            ("welcome", { WelcomeViewController() }),
            ("goal", { OnboardingOptionsViewController.goal() }),
            ("activity", { OnboardingOptionsViewController.activity() }),
            ("sex", { OnboardingOptionsViewController.sex() }),
            ("age", { OnboardingAgeViewController() }),
            ("body", { OnboardingBodyViewController() }),
            ("health", { OnboardingHealthViewController() }),
            ("rating", { AppRatingViewController() })
        ]
        // The option screens keep their heading and button in place and scroll only the choices.
        let sectionScrollScreens = ["goal", "activity", "sex"]
        for size in sizes {
            for (name, make) in screens {
                let controller = make()
                host(controller, size: size)
                if sectionScrollScreens.contains(name) {
                    try assertOnlyTheChoicesScroll(in: controller, name: name, size: size)
                    continue
                }
                let scroll = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIScrollView }
                    .first { $0.accessibilityIdentifier == "flow.scroll" }, name)
                let content = try XCTUnwrap(scroll.subviews.first { $0.accessibilityIdentifier == "flow.scroll.content" })
                XCTAssertEqual(content.bounds.width, scroll.bounds.width, accuracy: 1, name)
                XCTAssertLessThanOrEqual(controller.view.safeAreaLayoutGuide.layoutFrame.width, size.width + 1, name)
                XCTAssertLessThanOrEqual(content.bounds.width, min(size.width, 640) + 1, name)
                XCTAssertGreaterThanOrEqual(content.bounds.height, scroll.bounds.height - 1, name)
                assertReadableLabels(in: content, context: "\(name) \(size)")
                let actions = descendants(content).compactMap { $0 as? UIButton }.filter { $0.configuration?.title != nil }
                XCTAssertFalse(actions.isEmpty, name)
                for action in actions {
                    let frame = action.convert(action.bounds, to: content)
                    XCTAssertLessThanOrEqual(frame.maxY, content.bounds.maxY + 1, name)
                    XCTAssertGreaterThanOrEqual(frame.minX, -1, name)
                    XCTAssertLessThanOrEqual(frame.maxX, content.bounds.maxX + 1, name)
                }
                if ["welcome", "activity"].contains(name) { capture(controller.view, name: "\(name)-\(Int(size.width))") }
            }
        }
    }

    private func assertOnlyTheChoicesScroll(
        in controller: UIViewController,
        name: String,
        size: CGSize
    ) throws {
        let view = controller.view!
        XCTAssertNil(
            descendants(view).compactMap { $0 as? UIScrollView }.first { $0.accessibilityIdentifier == "flow.scroll" },
            "\(name) must not put the whole screen in a scroll view"
        )
        let scroll = try XCTUnwrap(
            descendants(view).compactMap { $0 as? UIScrollView }
                .first { $0.accessibilityIdentifier == "flow.section.scroll" },
            name
        )
        XCTAssertLessThanOrEqual(scroll.convert(scroll.bounds, to: view).maxY, view.bounds.maxY + 1, name)
        assertReadableLabels(in: view, context: "\(name) \(size)")
        let actions = descendants(view).compactMap { $0 as? UIButton }.filter { $0.configuration?.title != nil }
        XCTAssertFalse(actions.isEmpty, name)
        for action in actions {
            let frame = action.convert(action.bounds, to: view)
            XCTAssertFalse(action.isDescendant(of: scroll), "\(name): the button stays out of the scrolling list")
            XCTAssertLessThanOrEqual(frame.maxY, view.bounds.maxY + 1, name)
            XCTAssertGreaterThanOrEqual(frame.minX, -1, name)
            XCTAssertLessThanOrEqual(frame.maxX, view.bounds.maxX + 1, name)
        }
        let choices = descendants(view).compactMap { $0 as? OnboardingOptionCardView }
        for choice in choices {
            let fits = choice.systemLayoutSizeFitting(
                CGSize(width: choice.bounds.width, height: 0),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height
            XCTAssertEqual(
                choice.bounds.height, fits, accuracy: 1,
                "\(name): a choice card is the size of its text, not of the spare space"
            )
        }
    }

    func testLargeTextOptionsKeepEveryChoiceReadable() throws {
        let controller = OnboardingOptionsViewController.activity()
        host(controller, size: CGSize(width: 320, height: 600), category: .accessibilityLarge)
        let choices = descendants(controller.view).compactMap { $0 as? OnboardingOptionCardView }
        XCTAssertEqual(choices.count, 4)
        choices.forEach { assertReadableLabels(in: $0, context: "large text activity choice") }
        let choiceLabels = choices.flatMap(descendants).compactMap { $0 as? AdaptiveLabel }
        XCTAssertGreaterThan(choiceLabels.map { $0.font.pointSize }.max() ?? 0, 22, "Larger Text must actually enlarge the choice text")
        let scroll = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIScrollView }.first)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        capture(controller.view, name: "activity-accessibility-large-320")
    }

    func testRewardDetailKeepsContentAboveActionsAtEverySize() throws {
        for size in sizes {
            let controller = RewardDetailViewController(progress: BadgeProgress(badge: .mealTrackerMaster, current: 3, goal: 7))
            host(controller, size: size)
            let content = try XCTUnwrap(descendants(controller.view).first { $0.accessibilityIdentifier == "flow.scroll.content" })
            assertReadableLabels(in: content, context: "reward detail \(size)")
            let card = try XCTUnwrap(descendants(content).compactMap { $0 as? RewardProgressCardView }.first)
            let actions = descendants(content).compactMap { $0 as? UIButton }.filter { $0.configuration?.title != nil }
            let cardBottom = card.convert(card.bounds, to: content).maxY
            for action in actions {
                XCTAssertGreaterThanOrEqual(action.convert(action.bounds, to: content).minY, cardBottom, "Reward actions overlap its progress card")
            }
            capture(controller.view, name: "reward-detail-\(Int(size.width))")
        }
    }

    func testRewardsGridReflowsWhenTheSameScreenBecomesNarrower() throws {
        let harness = TestHarness()
        let repository = RewardsRepository(coreDataStack: harness.stack)
        let viewModel = RewardsViewModel(fetchRewardsScreenUseCase: FetchRewardsScreenUseCase(
            evaluateStreakUseCase: EvaluateStreakUseCase(foodEntryRepository: harness.food, rewardsRepository: repository),
            evaluateBadgesUseCase: EvaluateBadgesUseCase(
                rewardsRepository: repository, foodEntryRepository: harness.food, waterEntryRepository: harness.water,
                weightEntryRepository: harness.weight, workoutEntryRepository: harness.workout,
                progressPhotoRepository: harness.photos, userGoalsRepository: harness.goals
            ), rewardsRepository: repository
        ))
        let controller = RewardsViewController(viewModel: viewModel)
        host(controller, size: CGSize(width: 768, height: 1024))
        let wide = badgeRows(in: controller.view)
        XCTAssertGreaterThan(wide.first?.arrangedSubviews.count ?? 0, 3)
        resize(controller, to: CGSize(width: 320, height: 600))
        let narrow = badgeRows(in: controller.view)
        XCTAssertGreaterThan(narrow.count, wide.count)
        XCTAssertEqual(narrow.flatMap(\.arrangedSubviews).compactMap { $0 as? RewardBadgeView }.count, RewardBadge.allCases.count)
        assertReadableLabels(in: controller.view, context: "narrow rewards grid")
        capture(controller.view, name: "rewards-resized-320")
    }

    private func host(_ controller: UIViewController, size: CGSize, category: UIContentSizeCategory = .large) {
        let animationsEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsEnabled) }
        window?.isHidden = true
        let host = UIViewController()
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        window.overrideUserInterfaceStyle = .light
        host.addChild(controller)
        host.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: category), forChild: controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(controller.view)
        hostedSizeConstraints = [
            controller.view.widthAnchor.constraint(equalToConstant: size.width),
            controller.view.heightAnchor.constraint(equalToConstant: size.height)
        ]
        NSLayoutConstraint.activate(hostedSizeConstraints + [
            controller.view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            controller.view.topAnchor.constraint(equalTo: host.view.topAnchor)
        ])
        controller.didMove(toParent: host)
        controller.beginAppearanceTransition(true, animated: false)
        window.makeKeyAndVisible()
        self.window = window
        resize(controller, to: size)
        controller.endAppearanceTransition()
        controller.view.layoutIfNeeded()
    }

    private func resize(_ controller: UIViewController, to size: CGSize) {
        hostedSizeConstraints[0].constant = size.width
        hostedSizeConstraints[1].constant = size.height
        for _ in 0..<3 {
            controller.view.superview?.setNeedsLayout()
            controller.view.superview?.layoutIfNeeded()
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
        XCTAssertEqual(controller.view.bounds.width, size.width, accuracy: 0.5, "Layout host must enforce the requested device width")
        XCTAssertEqual(controller.view.bounds.height, size.height, accuracy: 0.5, "Layout host must enforce the requested device height")
    }

    private func badgeRows(in view: UIView) -> [UIStackView] {
        descendants(view).compactMap { $0 as? UIStackView }
            .filter { $0.arrangedSubviews.contains { $0 is RewardBadgeView } }
    }

    private func assertReadableLabels(in view: UIView, context: String) {
        for label in descendants(view).compactMap({ $0 as? AdaptiveLabel }) {
            guard !isHidden(label), let text = label.text, !text.isEmpty else { continue }
            let frame = label.convert(label.bounds, to: view)
            XCTAssertGreaterThanOrEqual(frame.minX, -1, "\(context): \(text)")
            XCTAssertLessThanOrEqual(frame.maxX, view.bounds.width + 1, "\(context): \(text)")
            guard label.numberOfLines == 0 else { continue }
            let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height
            XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed, "\(context): clipped \(text)")
        }
    }

    private func isHidden(_ view: UIView) -> Bool {
        if view.isHidden { return true }
        return view.superview.map(isHidden) ?? false
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(descendants)
    }

    private func capture(_ view: UIView, name: String) {
        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
