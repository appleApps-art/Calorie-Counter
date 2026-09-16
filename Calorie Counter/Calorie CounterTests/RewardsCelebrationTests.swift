import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class RewardsCelebrationTests: XCTestCase {
    func testRewardConfettiGIFIsAnAnimatedBundleResource() {
        let bundle = Bundle(for: GIFImageView.self)
        XCTAssertNotNil(bundle.url(forResource: "RewardConfetti", withExtension: "gif"))

        let view = GIFImageView()
        view.loadGIF(named: "RewardConfetti")
        XCTAssertTrue(view.hasAnimatedGIF)
        XCTAssertGreaterThan(view.duration, 0)
    }

    func testRewardConfettiFileLivesNextToOtherGIFs() throws {
        let gif = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/Resources/RewardConfetti.gif")
        XCTAssertTrue(FileManager.default.fileExists(atPath: gif.path))
        let data = try Data(contentsOf: gif)
        XCTAssertGreaterThan(data.count, 1_000)
        XCTAssertTrue(data.starts(with: Data("GIF89a".utf8)))
    }

    func testRewardDetailHidesConfettiWhenBrowsingFromList() {
        let detail = RewardDetailViewController(
            progress: BadgeProgress(badge: .fiberChampion, current: 2, goal: 7)
        )
        detail.loadViewIfNeeded()
        XCTAssertEqual(gifView(in: detail.view)?.isHidden, true)
        XCTAssertFalse(gifView(in: detail.view)?.hasAnimatedGIF ?? true)
    }

    func testRewardDetailLoadsConfettiForUnlockCelebration() {
        let detail = RewardDetailViewController(
            progress: BadgeProgress(badge: .hydrationHero, current: 7, goal: 7),
            playsCelebration: true
        )
        detail.loadViewIfNeeded()
        let confetti = gifView(in: detail.view)
        XCTAssertEqual(confetti?.isHidden, false)
        XCTAssertEqual(confetti?.hasAnimatedGIF, true)
    }

    func testMealTrackerCompletesAfterSevenConsecutiveFoodDays() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 18))!
        let foods = (0..<7).map { offset -> FoodEntry in
            let day = calendar.date(byAdding: .day, value: -offset, to: now)!
            let date = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
            return FoodEntry(
                id: UUID(),
                name: "Oats",
                mealType: .breakfast,
                calories: 300,
                protein: 12,
                carbs: 40,
                fats: 8,
                fiber: 4,
                sugar: 2,
                sodium: 80,
                date: date
            )
        }
        let progress = BadgeProgressCalculator.progress(
            foods: foods,
            waters: [],
            weights: [],
            workouts: [],
            photos: [],
            events: [],
            goals: .default,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(progress.first { $0.badge == .mealTrackerMaster }?.isComplete, true)
        XCTAssertEqual(
            BadgeProgress.awaitingCelebration(
                in: progress,
                seenIDs: []
            ).map(\.badge).contains(.mealTrackerMaster),
            true
        )
        XCTAssertTrue(
            BadgeProgress.awaitingCelebration(
                in: progress,
                seenIDs: [RewardBadge.mealTrackerMaster.rawValue]
            ).map(\.badge).contains(.mealTrackerMaster) == false
        )
    }

    func testUnlockPresenterSourceShowsCelebrationConfetti() throws {
        let presenter = sourceFile("App/BadgeUnlockPresenter.swift")
        let detail = sourceFile("Features/Rewards/RewardDetailViewController.swift")
        let coordinator = sourceFile("App/AppCoordinator.swift")
        XCTAssertTrue(presenter.contains("playsCelebration: true"))
        XCTAssertTrue(presenter.contains("isTransitioning"))
        XCTAssertTrue(detail.contains("loadGIF(named: \"RewardConfetti\")"))
        XCTAssertTrue(detail.contains("notifyViewedIfNeeded()"))
        XCTAssertTrue(coordinator.contains("badgeUnlockPresenter.present(unseen)"))
    }

    private func sourceFile(_ relativePath: String) -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter")
            .appendingPathComponent(relativePath)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    private func gifView(in root: UIView?) -> GIFImageView? {
        guard let root else { return nil }
        if let gif = root as? GIFImageView { return gif }
        for child in root.subviews {
            if let gif = gifView(in: child) { return gif }
        }
        return nil
    }
}
