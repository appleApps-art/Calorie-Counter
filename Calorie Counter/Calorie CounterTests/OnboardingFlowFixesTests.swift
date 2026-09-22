import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class OnboardingFlowFixesTests: XCTestCase {
    // MARK: - Welcome

    func testTheWelcomeHeroAnimatesInBothThemes() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let controller = WelcomeViewController()
            controller.overrideUserInterfaceStyle = style
            controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
            controller.view.layoutIfNeeded()
            let hero = try XCTUnwrap(controller.value(forKey: "heroImageView") as? GIFImageView)
            XCTAssertTrue(hero.hasAnimatedGIF, "The scan animation plays in \(style == .dark ? "dark" : "light") too")
        }
    }

    func testEveryWelcomeFeatureIsReadInFull() throws {
        let controller = WelcomeViewController()
        controller.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        for _ in 0..<3 {
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
        }
        for key in ["feature1Label", "feature2Label", "feature3Label"] {
            let label = try XCTUnwrap(controller.value(forKey: key) as? UILabel)
            let needed = label.sizeThatFits(
                CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)
            ).height
            XCTAssertGreaterThanOrEqual(
                label.bounds.height + 0.5, needed,
                "\(label.text ?? key) is cut off"
            )
        }
    }

    // MARK: - Health permission

    func testAppleHealthIsNotAskedForBeforeOnboardingIsDone() async {
        let harness = TestHarness()
        harness.health.needsPrompt = true
        harness.settings.settings.healthAuthorizationRequested = false
        var completed = false
        let controller = HealthSyncController(
            healthSync: harness.health,
            appSettingsStore: harness.settings,
            requestAuthorizationUseCase: RequestHealthSyncAuthorizationUseCase(
                healthSync: harness.health,
                appSettingsStore: harness.settings
            ),
            syncHealthDataUseCase: harness.syncUseCase(),
            isOnboardingCompleted: { completed }
        )

        controller.refreshOnForeground()
        await settle()
        XCTAssertFalse(
            harness.settings.settings.healthAuthorizationRequested,
            "The system sheet must not cover the welcome screen on a first launch"
        )

        completed = true
        controller.refreshOnForeground()
        await settle()
        XCTAssertTrue(harness.settings.settings.healthAuthorizationRequested, "Once inside the app it asks as before")
    }

    // MARK: - The plan

    func testThePlanShowsTheNumbersItSaves() throws {
        let harness = TestHarness()
        var profile = UserProfile.empty
        profile.sex = .male
        profile.age = 30
        profile.heightCm = 180
        profile.weightKg = 80
        profile.activityLevel = .moderate
        profile.goalType = .lose

        let plan = try XCTUnwrap(CalculateNutritionPlanUseCase().execute(profile: profile))
        // Mifflin-St Jeor: 10*80 + 6.25*180 - 5*30 + 5
        XCTAssertEqual(plan.bmr, 1780)
        XCTAssertEqual(plan.tdee, (1780 * 1.55).rounded())
        XCTAssertEqual(plan.goals.calorieTarget, (1780 * 1.55 - 500).rounded())
        XCTAssertEqual(plan.goals.proteinTarget, 160, "2 g per kilo while losing")
        XCTAssertEqual(plan.goals.fatsTarget, 64, "0.8 g per kilo while losing")
        XCTAssertEqual(
            plan.goals.carbsTarget,
            ((plan.goals.calorieTarget - 160 * 4 - 64 * 9) / 4).rounded(.down),
            "Carbs take what the energy budget has left"
        )
        XCTAssertEqual(plan.goals.waterTargetMilliliters, 2800, "35 ml per kilo")
        XCTAssertEqual(plan.goals.fiberTarget, (14 * plan.goals.calorieTarget / 1000).rounded())
        XCTAssertEqual(plan.goals.sugarTarget, (plan.goals.calorieTarget * 0.05 / 4).rounded())
        XCTAssertEqual(plan.goals.sodiumTarget, 2300)

        let saved = try CompleteOnboardingUseCase(
            userProfileRepository: harness.profile,
            userGoalsRepository: harness.goals
        ).execute(profile: profile)
        XCTAssertEqual(saved.goals, plan.goals, "The screen and the diary start from the same targets")
        let stored = try harness.goals.fetchGoals()
        XCTAssertEqual(stored, plan.goals)
        XCTAssertTrue(try harness.profile.fetchProfile().onboardingCompleted)

        let display = OnboardingFlowViewModel.display(for: plan, locale: Locale(identifier: "en_US"))
        XCTAssertTrue(display.energyValue.contains("2,259"), "Shown: \(display.energyValue)")
        XCTAssertEqual(display.proteinValue, L10n.format("onboarding.plan.gramsFormat", 160))
        XCTAssertEqual(display.waterValue, L10n.format("onboarding.plan.waterValueFormat", "2.8"))
    }

    func testLosingWeightPointsAtADateAndMaintainingDoesNot() throws {
        var profile = UserProfile.empty
        profile.sex = .female
        profile.age = 28
        profile.heightCm = 165
        profile.weightKg = 70
        profile.activityLevel = .light
        profile.goalType = .lose
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let losing = try XCTUnwrap(CalculateNutritionPlanUseCase().execute(profile: profile, now: now))
        // 70 kg down to BMI 22 (59.9 kg) at half a kilo a week is about 20 weeks.
        let date = try XCTUnwrap(losing.estimatedGoalDate)
        let weeks = date.timeIntervalSince(now) / (7 * 24 * 3600)
        XCTAssertEqual(weeks, 20.2, accuracy: 0.6)

        profile.goalType = .maintain
        let maintaining = try XCTUnwrap(CalculateNutritionPlanUseCase().execute(profile: profile, now: now))
        XCTAssertNil(maintaining.estimatedGoalDate)
        XCTAssertEqual(maintaining.goals.calorieTarget, maintaining.tdee, "Maintaining eats its own TDEE")
    }

    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}
