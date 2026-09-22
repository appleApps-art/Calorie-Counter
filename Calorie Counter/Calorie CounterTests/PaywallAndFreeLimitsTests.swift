import UIKit
import UserNotifications
import XCTest
@testable import Calorie_Counter

@MainActor
final class PaywallAndFreeLimitsTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "bity-paywall-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        PremiumPrompt.featureAccess = nil
        PremiumPrompt.makeCoordinator = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Free tries

    func testEachScannerGetsOneFreeTryAndBityTwoAnswers() {
        let subscription = FakeSubscriptionService()
        let access = FeatureAccessController(subscriptionService: subscription, defaults: defaults)
        for scanner in [FreeUsageFeature.foodPhotoScan, .barcodeScan, .fridgeScan] {
            XCTAssertTrue(access.canUse(scanner))
            access.recordUse(of: scanner)
            XCTAssertFalse(access.canUse(scanner), "\(scanner) allows one free scan")
        }
        XCTAssertEqual(access.remainingFreeUses(of: .aiMessage), 2)
        access.recordUse(of: .aiMessage)
        XCTAssertTrue(access.canUse(.aiMessage))
        access.recordUse(of: .aiMessage)
        XCTAssertFalse(access.canUse(.aiMessage))
    }

    func testPremiumIsNeverCountedOrLimited() {
        let subscription = FakeSubscriptionService(status: .premiumForTests)
        let access = FeatureAccessController(subscriptionService: subscription, defaults: defaults)
        for _ in 0..<5 {
            access.recordUse(of: .foodPhotoScan)
        }
        XCTAssertTrue(access.canUse(.foodPhotoScan))
        XCTAssertEqual(access.remainingFreeUses(of: .foodPhotoScan), 1, "Premium scans do not spend the free try")
    }

    func testFreeTriesCanBeSpentAndGivenBackForQA() {
        let access = FeatureAccessController(subscriptionService: FakeSubscriptionService(), defaults: defaults)
        access.exhaustFreeUses()
        XCTAssertTrue(FreeUsageFeature.allCases.allSatisfy { !access.canUse($0) })
        access.resetFreeUses()
        XCTAssertTrue(FreeUsageFeature.allCases.allSatisfy { access.canUse($0) })
    }

    func testAScreenWithoutAPresenterNeverRunsAPaidAction() {
        let access = FeatureAccessController(subscriptionService: FakeSubscriptionService(), defaults: defaults)
        access.exhaustFreeUses()
        PremiumPrompt.featureAccess = access
        PremiumPrompt.makeCoordinator = { SubscriptionCoordinator(factory: NoPaywallFactory()) }
        var ran = false
        PremiumPrompt.requireFreeUse(.aiMessage, from: nil) { ran = true }
        XCTAssertFalse(ran)
        access.resetFreeUses()
        PremiumPrompt.requireFreeUse(.aiMessage, from: nil) { ran = true }
        XCTAssertTrue(ran, "A free try left runs at once")
    }

    // MARK: - Plans

    func testTheDesignPlansReadAsInTheDesign() throws {
        let displays = PaywallPlanFormatter.displays(for: SubscriptionProduct.placeholders)
        let yearly = try XCTUnwrap(displays.first)
        let monthly = try XCTUnwrap(displays.last)
        XCTAssertEqual(yearly.title, L10n.format(
            "paywall.plan.trialTitle",
            L10n.format("paywall.plan.trialDays", 7),
            L10n.format("paywall.plan.perYear", "$49.99")
        ))
        XCTAssertEqual(yearly.subtitle, L10n.format("paywall.plan.perMonth", "$4.16"), "49.99 / 12, rounded down")
        XCTAssertEqual(yearly.badge, L10n.format("paywall.plan.save", 58))
        XCTAssertEqual(monthly.title, L10n.format("paywall.plan.perMonth", "$9.99"))
        XCTAssertEqual(monthly.subtitle, L10n.tr("paywall.plan.billedMonthly"))
        XCTAssertNil(monthly.badge)
        XCTAssertTrue(displays.allSatisfy(\.isPlaceholder))
    }

    func testAYearlyPlanNextToAWeeklyOneShowsItsWeeklyPrice() throws {
        let displays = PaywallPlanFormatter.displays(for: [
            Self.product("weekly", price: "6.99", unit: .week, trialDays: 3),
            Self.product("yearly", price: "39.99", unit: .year)
        ])
        XCTAssertEqual(displays[0].title, L10n.format(
            "paywall.plan.trialTitle",
            L10n.format("paywall.plan.trialDays", 3),
            L10n.format("paywall.plan.perWeek", "$6.99")
        ))
        XCTAssertEqual(displays[0].subtitle, L10n.tr("paywall.plan.billedWeekly"))
        XCTAssertEqual(displays[1].subtitle, L10n.format("paywall.plan.perWeek", "$0.76"), "39.99 / 52, rounded down")
        XCTAssertNil(displays[0].badge)
        XCTAssertEqual(displays[1].badge, L10n.format("paywall.plan.save", 88))
    }

    func testTheButtonAndTimelineFollowTheTrial() {
        let week = PaywallPlanDisplay(id: "a", title: "", subtitle: "", badge: nil, freeTrialDays: 7, isPlaceholder: false)
        let threeDays = PaywallPlanDisplay(id: "b", title: "", subtitle: "", badge: nil, freeTrialDays: 3, isPlaceholder: false)
        let none = PaywallPlanDisplay(id: "c", title: "", subtitle: "", badge: nil, freeTrialDays: nil, isPlaceholder: false)
        XCTAssertEqual(PaywallPlanFormatter.ctaTitle(for: week), L10n.tr("paywall.cta.freeWeek"))
        XCTAssertEqual(PaywallPlanFormatter.ctaTitle(for: threeDays), L10n.tr("paywall.cta.freeTrial"))
        XCTAssertEqual(PaywallPlanFormatter.ctaTitle(for: none), L10n.tr("common.continue"))

        let timeline = PaywallPlanFormatter.timeline(for: Self.product("weekly", price: "6.99", unit: .week, trialDays: 3))
        XCTAssertEqual(timeline.map(\.title), [
            L10n.tr("paywall.timeline.today"),
            L10n.format("paywall.timeline.day", 2),
            L10n.format("paywall.timeline.day", 3)
        ])
        XCTAssertEqual(timeline.first?.detail, L10n.format("paywall.timeline.charged", "$0.00"))
        XCTAssertTrue(PaywallPlanFormatter.timeline(for: Self.product("m", price: "9.99", unit: .month)).isEmpty)
        XCTAssertEqual(PaywallPlanFormatter.onboardingTitle(trialDays: nil), L10n.tr("paywall.onboarding.titleNoTrial"))
    }

    func testEveryLanguageTitleFitsItsLinesAtSomeSize() {
        let long = String(repeating: "Спробуйте безкоштовно ", count: 3)
        let fitted = PaywallTitleLabel.fitted(long, width: 173, maxLines: 3)
        let font = fitted.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize, 17, "Too long for 22 pt, so it steps down to the smallest size")
        let short = PaywallTitleLabel.fitted("Try 7 Days Free With Me!", width: 173, maxLines: 3)
        XCTAssertEqual((short.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.pointSize, 22)
    }

    // MARK: - Paywall screen

    func testThePaywallShowsTheDesignPlansAtOnceAndRealOnesWhenTheyArrive() async {
        let subscription = FakeSubscriptionService()
        let viewModel = makePaywall(subscription: subscription)
        XCTAssertEqual(viewModel.plans.value.count, 2)
        XCTAssertEqual(viewModel.selectedPlanID.value, "bity.placeholder.yearly", "The trial plan comes selected")
        XCTAssertEqual(viewModel.ctaTitle.value, L10n.tr("paywall.cta.freeWeek"))
        XCTAssertEqual(viewModel.titleText.value, PaywallPlanFormatter.onboardingTitle(trialDays: 7))

        subscription.offer = SubscriptionOffer(
            placement: .onboarding,
            products: [Self.product("monthly", price: "9.99", unit: .month), Self.product("yearly", price: "49.99", unit: .year, trialDays: 7)],
            hasPaywallBuilder: false
        )
        viewModel.viewDidLoad()
        await waitUntil { viewModel.plans.value.first?.id == "monthly" }
        XCTAssertEqual(viewModel.plans.value.map(\.id), ["monthly", "yearly"])
        XCTAssertEqual(viewModel.selectedPlanID.value, "yearly")
        viewModel.select(planID: "monthly")
        XCTAssertEqual(viewModel.ctaTitle.value, L10n.tr("common.continue"))
    }

    func testADesignPlanCannotBeBoughtAndClosingReportsOnce() {
        var alerts: [String] = []
        var closed = 0
        let viewModel = makePaywall(
            subscription: FakeSubscriptionService(),
            events: SubscriptionPaywallEvents(onClosed: { closed += 1 })
        )
        viewModel.onAlert = { alerts.append($0) }
        viewModel.purchaseTapped()
        XCTAssertEqual(alerts, [L10n.tr("subscription.unavailable")])
        viewModel.closeTapped()
        viewModel.closeTapped()
        XCTAssertEqual(closed, 1)
    }

    func testBuyingATrialSchedulesTheReminderTheTimelinePromises() async {
        let subscription = FakeSubscriptionService()
        subscription.offer = SubscriptionOffer(
            placement: .main,
            products: [Self.product("yearly", price: "49.99", unit: .year, trialDays: 7)],
            hasPaywallBuilder: false
        )
        subscription.purchaseStatus = .premiumForTests
        let reminder = RecordingTrialReminder()
        var purchased: SubscriptionStatus?
        let viewModel = makePaywall(
            subscription: subscription,
            placement: .main,
            reminder: reminder,
            events: SubscriptionPaywallEvents(onPurchased: { purchased = $0 })
        )
        viewModel.viewDidLoad()
        await waitUntil { viewModel.selectedPlanID.value == "yearly" }
        viewModel.purchaseTapped()
        await waitUntil { purchased != nil }
        XCTAssertEqual(purchased?.isPremium, true)
        XCTAssertEqual(reminder.trialDays, [7])
    }

    func testTheTrialReminderGoesOutTheDayBeforeTheTrialEnds() throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let request = try XCTUnwrap(TrialReminderScheduler.request(trialDays: 7, startedAt: start, calendar: calendar))
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        let fire = try XCTUnwrap(calendar.date(from: trigger.dateComponents))
        XCTAssertEqual(calendar.dateComponents([.day], from: start, to: fire).day, 6)
        XCTAssertEqual(request.identifier, TrialReminderScheduler.identifier)
        XCTAssertNil(TrialReminderScheduler.request(trialDays: 1, startedAt: start, calendar: calendar))
    }

    // MARK: - Bity chat

    func testAFreeAccountWritesToBityTwiceThenTheMessageWaitsForPremium() async {
        let harness = TestHarness()
        let subscription = FakeSubscriptionService()
        let access = FeatureAccessController(subscriptionService: subscription, defaults: defaults)
        let service = CountingAssistant()
        let viewModel = AIAssistantViewModel(
            aiAssistantService: service,
            fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                foodEntryRepository: harness.food,
                waterEntryRepository: harness.water,
                userGoalsRepository: harness.goals,
                workoutEntryRepository: harness.workout
            )
        )
        viewModel.allowsSending = { access.canUse(.aiMessage) }
        viewModel.onMessageAnswered = { access.recordUse(of: .aiMessage) }
        var retries: [() -> Void] = []
        viewModel.onLimitReached = { retries.append($0) }

        for text in ["first", "second"] {
            viewModel.updateInput(text)
            viewModel.sendTapped()
            await waitUntil { !viewModel.isSending.value }
        }
        XCTAssertEqual(service.messages, ["first", "second"])

        viewModel.updateInput("third")
        viewModel.sendTapped()
        XCTAssertEqual(service.messages.count, 2, "The third message does not go out")
        XCTAssertEqual(retries.count, 1)
        XCTAssertEqual(viewModel.inputText.value, "third", "What was typed stays in the field")

        subscription.status = .premiumForTests
        retries.first?()
        await waitUntil { service.messages.count == 3 && !viewModel.isSending.value }
        XCTAssertEqual(service.messages.last, "third")
    }

    // MARK: - Analytics

    func testAFreeAccountKeepsTheWeekViewAndLongerTrendsAskForPremium() {
        let subscription = FakeSubscriptionService()
        let viewModel = makeProgress(subscription: subscription)
        var asked = 0
        viewModel.onRequirePremium = { _ in asked += 1 }
        viewModel.selectWeightPeriod(.month)
        viewModel.selectCaloriePeriod(.sixMonths)
        XCTAssertEqual(asked, 2)
        XCTAssertEqual(viewModel.weightPeriod.value, .week)
        XCTAssertEqual(viewModel.caloriePeriod.value, .week)

        subscription.status = .premiumForTests
        viewModel.reload()
        viewModel.selectWeightPeriod(.month)
        XCTAssertEqual(viewModel.weightPeriod.value, .month)
        XCTAssertEqual(asked, 2)
    }

    // MARK: - Helpers

    private func makePaywall(
        subscription: FakeSubscriptionService,
        placement: SubscriptionPlacement = .onboarding,
        reminder: TrialReminderScheduling? = nil,
        events: SubscriptionPaywallEvents = SubscriptionPaywallEvents()
    ) -> PaywallViewModel {
        PaywallViewModel(
            placement: placement,
            subscription: RefreshSubscriptionStatusUseCase(subscriptionService: subscription),
            trialReminder: reminder,
            events: events
        )
    }

    private func makeProgress(subscription: FakeSubscriptionService) -> ProgressViewModel {
        let harness = TestHarness()
        let rewards = RewardsRepository(coreDataStack: harness.stack)
        return ProgressViewModel(
            fetchProgressSummaryUseCase: FetchProgressSummaryUseCase(
                foodEntryRepository: harness.food,
                waterEntryRepository: harness.water,
                weightEntryRepository: harness.weight,
                workoutEntryRepository: harness.workout,
                fetchProgressPhotosUseCase: FetchProgressPhotosUseCase(
                    progressPhotoRepository: harness.photos,
                    fileStore: harness.photoStore
                ),
                rewardsRepository: rewards,
                evaluateStreakUseCase: EvaluateStreakUseCase(foodEntryRepository: harness.food, rewardsRepository: rewards),
                userGoalsRepository: harness.goals,
                fetchOnboardingStateUseCase: FetchOnboardingStateUseCase(
                    userProfileRepository: harness.profile,
                    avatarFileStore: harness.photoStore
                ),
                calculateNutritionPlanUseCase: CalculateNutritionPlanUseCase()
            ),
            logWeightUseCase: harness.logWeight(),
            saveProgressPhotoUseCase: SaveProgressPhotoUseCase(
                progressPhotoRepository: harness.photos,
                fileStore: harness.photoStore
            ),
            deleteProgressPhotoUseCase: DeleteProgressPhotoUseCase(
                progressPhotoRepository: harness.photos,
                fileStore: harness.photoStore
            ),
            refreshSubscriptionStatusUseCase: RefreshSubscriptionStatusUseCase(subscriptionService: subscription)
        )
    }

    private static func product(
        _ id: String,
        price: String,
        unit: SubscriptionPeriod.Unit,
        trialDays: Int? = nil
    ) -> SubscriptionProduct {
        SubscriptionProduct(
            id: id,
            displayName: "Bity Premium",
            displayPrice: "$\(price)",
            periodLabel: "",
            price: Decimal(string: price),
            priceLocale: Locale(identifier: "en_US"),
            period: SubscriptionPeriod(unit: unit, count: 1),
            freeTrialDays: trialDays
        )
    }
}

private extension SubscriptionStatus {
    static let premiumForTests = SubscriptionStatus(
        tier: .premium,
        productID: "yearly",
        expirationDate: nil,
        isEligibleForTrial: false
    )
}

private final class FakeSubscriptionService: SubscriptionStatusProviding {
    var status: SubscriptionStatus
    var offer: SubscriptionOffer?
    var purchaseStatus: SubscriptionStatus = .free

    init(status: SubscriptionStatus = .free) {
        self.status = status
    }

    func currentStatus() -> SubscriptionStatus { status }
    func refresh() async -> SubscriptionStatus { status }
    func availableProducts() async throws -> [SubscriptionProduct] { offer?.products ?? [] }

    func loadPlacement(_ placement: SubscriptionPlacement) async throws -> SubscriptionOffer {
        guard let offer else { throw SubscriptionError.placementFailed }
        return offer
    }

    func purchase(productID: String) async throws -> SubscriptionStatus {
        try await purchase(productID: productID, placement: .main)
    }

    func purchase(productID: String, placement: SubscriptionPlacement) async throws -> SubscriptionStatus {
        status = purchaseStatus
        return purchaseStatus
    }

    func restorePurchases() async throws -> SubscriptionStatus { status }
    func logShowPlacement(_ placement: SubscriptionPlacement) async {}
}

private final class RecordingTrialReminder: TrialReminderScheduling {
    private(set) var trialDays: [Int] = []

    func scheduleTrialEndReminder(trialDays: Int, startedAt date: Date) {
        self.trialDays.append(trialDays)
    }
}

private final class NoPaywallFactory: SubscriptionPaywallPresenting {
    func makePaywallViewController(placement: SubscriptionPlacement, events: SubscriptionPaywallEvents) async throws -> UIViewController {
        XCTFail("No paywall is asked for without a screen to show it on")
        return UIViewController()
    }
}

private final class CountingAssistant: AIAssistantServiceProtocol {
    private(set) var messages: [String] = []

    func chat(_ request: AIAssistantChatRequest) async throws -> AIAssistantChatResponse {
        messages.append(request.message)
        return AIAssistantChatResponse(
            mode: "chat",
            model: "test",
            message: AIAssistantChatMessage(role: "assistant", content: "noted", toolCalls: []),
            hasActions: false,
            error: nil
        )
    }
}
