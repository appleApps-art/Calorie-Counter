import UIKit

final class OnboardingFlowCoordinator {
    private let pager = OnboardingPagerViewController()
    private let viewModel: OnboardingFlowViewModel
    private let planScreen = OnboardingPlanViewController()
    private let subscriptionCoordinator: SubscriptionCoordinator
    private let subscriptionService: SubscriptionStatusProviding
    private var didContinuePastPaywall = false

    var onFinished: (() -> Void)?

    init(
        viewModel: OnboardingFlowViewModel,
        subscriptionCoordinator: SubscriptionCoordinator,
        subscriptionService: SubscriptionStatusProviding
    ) {
        self.viewModel = viewModel
        self.subscriptionCoordinator = subscriptionCoordinator
        self.subscriptionService = subscriptionService
    }

    func makeRootViewController() -> UIViewController {
        pager.onFinished = { [weak self] in self?.finish() }

        let welcome = WelcomeViewController()
        welcome.onGetStarted = { [weak self] in
            Analytics.tracker.track(.onboardingStarted)
            self?.pager.goForward()
        }

        let goal = OnboardingOptionsViewController.goal()
        goal.onContinue = { [weak self] index in
            guard let self, Self.goals.indices.contains(index) else { return }
            self.viewModel.setGoal(Self.goals[index])
            self.pager.goForward()
        }
        goal.onBack = { [weak self] in self?.pager.goBack() }

        let sex = OnboardingOptionsViewController.sex()
        sex.onContinue = { [weak self] index in
            guard let self, Self.sexes.indices.contains(index) else { return }
            self.viewModel.setSex(Self.sexes[index])
            self.pager.goForward()
        }
        sex.onBack = { [weak self] in self?.pager.goBack() }

        let age = OnboardingAgeViewController()
        age.onContinue = { [weak self] value in
            self?.viewModel.setAge(value)
            self?.pager.goForward()
        }
        age.onBack = { [weak self] in self?.pager.goBack() }

        let body = OnboardingBodyViewController()
        body.onContinue = { [weak self] heightCm, weightKg in
            self?.viewModel.setBody(heightCm: heightCm, weightKg: weightKg)
            self?.pager.goForward()
        }
        body.onBack = { [weak self] in self?.pager.goBack() }

        let health = OnboardingHealthViewController()
        health.onContinue = { [weak self] in
            await self?.viewModel.requestHealthAuthorization()
            await MainActor.run { self?.pager.goForward() }
        }
        health.onMaybeLater = { [weak self] in self?.pager.goForward() }
        health.onBack = { [weak self] in self?.pager.goBack() }

        let activity = OnboardingOptionsViewController.activity()
        activity.onContinue = { [weak self] index in
            guard let self, Self.activities.indices.contains(index) else { return }
            self.viewModel.setActivity(Self.activities[index])
            if let display = self.viewModel.makePlanDisplay() {
                self.planScreen.apply(display)
            }
            self.presentCalculatingThenPlan()
        }
        activity.onBack = { [weak self] in self?.pager.goBack() }

        planScreen.onContinue = { [weak self] in self?.presentPaywallThenFinish() }
        planScreen.onBack = { [weak self] in self?.pager.goBack() }
        planScreen.onLearnMore = { [weak self] in self?.openLearnMore() }

        pager.setPages([welcome, goal, sex, age, body, health, activity, planScreen])
        return pager
    }

    private func presentCalculatingThenPlan() {
        let calculating = OnboardingCalculatingViewController()
        calculating.onFinished = { [weak self, weak calculating] in
            self?.pager.goForward(animated: false)
            calculating?.dismiss(animated: false)
        }
        pager.present(calculating, animated: false)
    }

    private func presentPaywallThenFinish() {
        if subscriptionService.currentStatus().isPremium {
            finish()
            return
        }
        didContinuePastPaywall = false
        let continueOnboarding = { [weak self] in
            self?.continueAfterPaywall()
        }
        subscriptionCoordinator.presentPaywall(
            from: pager,
            placement: .onboarding,
            events: SubscriptionPaywallEvents(
                onPurchased: { _ in continueOnboarding() },
                onRestored: { _ in continueOnboarding() },
                onCancelled: { continueOnboarding() },
                onClosed: { continueOnboarding() },
                onError: { _ in continueOnboarding() }
            )
        )
    }

    private func continueAfterPaywall() {
        guard !didContinuePastPaywall else { return }
        didContinuePastPaywall = true
        if pager.presentedViewController != nil {
            pager.dismiss(animated: true) { [weak self] in
                self?.finish()
            }
        } else {
            finish()
        }
    }

    private func finish() {
        try? viewModel.complete()
        Analytics.tracker.track(.onboardingCompleted(goal: viewModel.profile.goalType?.rawValue))
        var properties: [String: Any] = ["onboarding_completed": true]
        if let goal = viewModel.profile.goalType?.rawValue { properties["goal"] = goal }
        if let sex = viewModel.profile.sex?.rawValue { properties["sex"] = sex }
        if let activity = viewModel.profile.activityLevel?.rawValue { properties["activity_level"] = activity }
        Analytics.tracker.setUserProperties(properties)
        onFinished?()
    }

    private func openLearnMore() {
        guard let url = URL(string: L10n.tr("onboarding.plan.learnMoreURL")) else { return }
        UIApplication.shared.open(url)
    }

    private static let goals: [GoalType] = [.lose, .maintain, .gain]
    private static let sexes: [BiologicalSex] = [.male, .female]
    private static let activities: [ActivityLevel] = [.sedentary, .light, .moderate, .veryActive]
}
