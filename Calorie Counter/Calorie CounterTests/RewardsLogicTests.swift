import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class RewardsLogicTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    // MARK: - XP

    func testAddingAndRemovingTheSameGlassOfWaterEarnsNoXP() throws {
        let app = RewardsApp()
        let logWater = LogWaterUseCase(waterEntryRepository: app.harness.water, awardXPUseCase: app.award)
        let deleteWater = DeleteWaterEntryUseCase(waterEntryRepository: app.harness.water, awardXPUseCase: app.award)

        for _ in 0..<10 {
            let glass = try logWater.execute(amountMilliliters: 250, syncToHealth: false)
            try deleteWater.execute(id: glass.id)
        }
        XCTAssertEqual(try app.rewards.fetchState().totalXP, 0, "The water +/- buttons must not be a level farm")

        _ = try logWater.execute(amountMilliliters: 250, syncToHealth: false)
        XCTAssertEqual(try app.rewards.fetchState().totalXP, XPEventKind.water.xpAmount, "A glass that stays still counts")
    }

    func testADeletedMealTakesItsXPWithIt() throws {
        let app = RewardsApp()
        let logFood = LogFoodUseCase(foodEntryRepository: app.harness.food, awardXPUseCase: app.award)
        let deleteFood = DeleteFoodEntryUseCase(foodEntryRepository: app.harness.food, awardXPUseCase: app.award)

        let kept = try logFood.execute(meal(on: Date()))
        let removed = try logFood.execute(meal(on: Date()))
        try deleteFood.execute(id: removed.id)

        XCTAssertEqual(try app.rewards.fetchState().totalXP, XPEventKind.food.xpAmount)
        XCTAssertEqual(try app.rewards.fetchEvents().compactMap(\.relatedID), [kept.id])
    }

    // MARK: - Earned badges

    func testAnEarnedBadgeStaysEarnedAfterAMissedDay() throws {
        let app = RewardsApp()
        let lastDay = date(day: 10, hour: 12)
        for offset in 0..<7 {
            try app.harness.food.save(meal(on: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: lastDay)!)))
        }
        let earned = try app.evaluate.execute(now: lastDay, calendar: calendar)
        XCTAssertEqual(earned.first { $0.badge == .mealTrackerMaster }?.isComplete, true)

        // Two days later without a single meal: the streak is gone, the badge is not.
        let later = calendar.date(byAdding: .day, value: 2, to: lastDay)!
        let afterBreak = try app.evaluate.execute(now: later, calendar: calendar)
        XCTAssertEqual(afterBreak.first { $0.badge == .mealTrackerMaster }?.isComplete, true)
        XCTAssertTrue(try app.rewards.fetchState().unlockedBadgeIDs.contains(RewardBadge.mealTrackerMaster.rawValue))
    }

    func testABadgeCelebratedBeforeThisFixIsStillEarned() throws {
        let app = RewardsApp()
        var state = try app.rewards.fetchState()
        state.seenBadgeIDs = [RewardBadge.hydrationHero.rawValue]
        try app.rewards.save(state)

        let progress = try app.evaluate.execute(now: date(day: 10, hour: 12), calendar: calendar)
        XCTAssertEqual(progress.first { $0.badge == .hydrationHero }?.isComplete, true)
        XCTAssertEqual(RewardsScreenState(xp: 0, level: .rookie, badges: progress).unlockedCount, 1)
    }

    func testAnEarnedBadgeIsCelebratedOnceAndOnlyOnce() throws {
        let app = RewardsApp()
        var celebrated: [[RewardBadge]] = []
        app.evaluate.onNewlyUnlocked = { celebrated.append($0.map(\.badge)) }
        let lastDay = date(day: 10, hour: 12)
        for offset in 0..<7 {
            try app.harness.food.save(meal(on: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -offset, to: lastDay)!)))
        }

        try app.evaluate.execute(now: lastDay, calendar: calendar)
        XCTAssertTrue(celebrated.last?.contains(.mealTrackerMaster) == true)

        try MarkBadgeSeenUseCase(rewardsRepository: app.rewards).execute(.mealTrackerMaster)
        celebrated.removeAll()
        try app.evaluate.execute(now: calendar.date(byAdding: .day, value: 3, to: lastDay)!, calendar: calendar)
        XCTAssertFalse(celebrated.flatMap { $0 }.contains(.mealTrackerMaster))
    }

    // MARK: - Time-of-day badges

    func testEarlyBirdNeedsAMealLoggedBeforeNineThatSameMorning() {
        let lastDay = date(day: 10, hour: 12)
        let days = (0..<5).map { calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: lastDay))! }
        // Added meals are stored at midnight of their day; what matters is when they were logged.
        let meals = days.map { meal(on: $0) }

        let afternoon = progress(foods: meals, events: meals.map { foodEvent(for: $0, hour: 14) }, now: lastDay)
        XCTAssertEqual(afternoon[.earlyBirdLogger]?.isComplete, false, "Midnight timestamps alone must not make everyone an early bird")

        let morning = progress(foods: meals, events: meals.map { foodEvent(for: $0, hour: 8) }, now: lastDay)
        XCTAssertEqual(morning[.earlyBirdLogger]?.isComplete, true)

        let backfilled = progress(
            foods: meals,
            events: meals.map { foodEvent(for: $0, hour: 8, daysLater: 1) },
            now: lastDay
        )
        XCTAssertEqual(backfilled[.earlyBirdLogger]?.current, 0, "Logging yesterday's meal this morning is not an early bird day")

        let unknownTime = progress(foods: meals, events: [], now: lastDay)
        XCTAssertEqual(unknownTime[.earlyBirdLogger]?.current, 0, "A bare midnight date says nothing about when it was logged")
        let imported = days.map { meal(on: calendar.date(bySettingHour: 7, minute: 30, second: 0, of: $0)!) }
        XCTAssertEqual(progress(foods: imported, events: [], now: lastDay)[.earlyBirdLogger]?.isComplete, true,
                       "A real timestamp (e.g. from Apple Health) still counts")
    }

    func testOnlyASnackLoggedAfterNineAtNightBreaksNoLateSnacks() {
        let now = date(day: 10, hour: 22)
        let days = (0..<3).map { calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: now))! }

        let lateDinners = days.map { meal(on: $0, type: .dinner) }
        let dinners = progress(foods: lateDinners, events: lateDinners.map { foodEvent(for: $0, hour: 21) }, now: now)
        XCTAssertEqual(dinners[.noLateSnacks]?.isComplete, true, "A dinner logged late is not a late snack")

        let lateSnack = meal(on: days[1], type: .snacks)
        let withSnack = progress(
            foods: lateDinners + [lateSnack],
            events: lateDinners.map { foodEvent(for: $0, hour: 19) } + [foodEvent(for: lateSnack, hour: 23)],
            now: now
        )
        XCTAssertEqual(withSnack[.noLateSnacks]?.current, 1, "The late snack yesterday ends the run")
    }

    func testTodayOnlyCountsAsNoLateSnacksOnceTheEveningIsOver() {
        let afternoon = date(day: 10, hour: 15)
        let days = (0..<3).map { calendar.date(byAdding: .day, value: -$0, to: calendar.startOfDay(for: afternoon))! }
        let meals = days.map { meal(on: $0) }
        let events = meals.map { foodEvent(for: $0, hour: 12) }

        XCTAssertEqual(progress(foods: meals, events: events, now: afternoon)[.noLateSnacks]?.current, 2)
        let night = date(day: 10, hour: 21)
        XCTAssertEqual(progress(foods: meals, events: events, now: night)[.noLateSnacks]?.isComplete, true)
    }

    // MARK: - Swaps, photos and badge art

    func testSmartChoiceCountsSwapsInTotalNotDaysInARow() {
        let now = date(day: 28, hour: 12)
        // Seven swaps spread over four weeks, with gaps between them.
        let swapDays = [1, 3, 8, 12, 17, 22, 27]
        let swaps = swapDays.map { day in
            XPEvent(id: UUID(), kind: .foodSwap, amount: XPEventKind.foodSwap.xpAmount, date: date(day: day, hour: 13), relatedID: nil)
        }
        XCTAssertEqual(progress(foods: [], events: swaps, now: now)[.smartChoice]?.isComplete, true)

        let three = progress(foods: [], events: Array(swaps.prefix(3)), now: now)[.smartChoice]
        XCTAssertEqual(three?.current, 3)
        if Bundle.main.preferredLocalizations.first == "uk" {
            XCTAssertEqual(three?.listSubtitle, "3/7 замін")
            XCTAssertEqual(BadgeProgress(badge: .smartChoice, current: 7, goal: 7).pillTitle, "7 ЗАМІН")
            XCTAssertEqual(BadgeProgress(badge: .smartChoice, current: 7, goal: 7).rewardDetail, "Значок за 7 замін")
        }
        XCTAssertEqual(BadgeProgress(badge: .smartChoice, current: 0, goal: 7).tickLabels.first, "1")
    }

    func testTheProgressScaleIsLabelledInTheAppLanguage() {
        let days = BadgeProgress(badge: .mealTrackerMaster, current: 1, goal: 3).tickLabels
        let weeks = BadgeProgress(badge: .visualJourney, current: 1, goal: 4).tickLabels
        XCTAssertEqual(days, (1...3).map { L10n.format("rewards.tick.day", $0) })
        XCTAssertEqual(weeks, (1...4).map { L10n.format("rewards.tick.week", $0) })
        if Bundle.main.preferredLocalizations.first == "uk" {
            XCTAssertEqual(days.first, "Д1")
            XCTAssertEqual(weeks.last, "Т4")
        }
    }

    func testVisualJourneyWantsAPhotoEachWeekNotEachDay() {
        let now = date(day: 28, hour: 12)
        let weekly = (0..<4).map { week in
            photo(on: calendar.date(byAdding: .weekOfYear, value: -week, to: now)!)
        }
        let journey = progress(foods: [], photos: weekly, events: [], now: now)[.visualJourney]
        XCTAssertEqual(journey?.goal, 4)
        XCTAssertEqual(journey?.isComplete, true)

        let oneBusyWeek = (0..<7).map { photo(on: calendar.date(byAdding: .day, value: -$0, to: now)!) }
        let daily = progress(foods: [], photos: oneBusyWeek, events: [], now: now)[.visualJourney]
        XCTAssertLessThanOrEqual(daily?.current ?? 0, 2, "A photo every day of one week is not a month-long journey")
        XCTAssertEqual(daily?.isComplete, false)
        XCTAssertEqual(RewardBadge.visualJourney.unit, .weeks)
    }

    func testABadgeOnItsWayStaysDimUntilItIsEarned() {
        XCTAssertTrue(BadgeProgress(badge: .fiberChampion, current: 0, goal: 7).showsLockedArt)
        XCTAssertTrue(BadgeProgress(badge: .fiberChampion, current: 3, goal: 7).showsLockedArt, "3/7 must not look won")
        XCTAssertFalse(BadgeProgress(badge: .fiberChampion, current: 7, goal: 7).showsLockedArt)
    }

    // MARK: - Copy and celebration

    func testTheStreakPillIsGrammatical() {
        let ukrainian = Bundle.main.preferredLocalizations.first == "uk"
        func pill(_ badge: RewardBadge, _ current: Int) -> String {
            BadgeProgress(badge: badge, current: current, goal: badge.goal).pillTitle
        }
        if ukrainian {
            XCTAssertEqual(pill(.mealTrackerMaster, 7), "СЕРІЯ 7 ДНІВ")
            XCTAssertEqual(pill(.macroBalancer, 5), "СЕРІЯ 5 ДНІВ")
            XCTAssertEqual(pill(.weekendWarrior, 2), "СЕРІЯ 2 ДНІ")
            XCTAssertEqual(pill(.mealTrackerMaster, 1), "СЕРІЯ 1 ДЕНЬ")
            XCTAssertEqual(pill(.consistentWeigher, 3), "3 ТИЖНІ АКТИВНО")
            XCTAssertEqual(pill(.consistentWeigher, 1), "1 ТИЖДЕНЬ АКТИВНО")
        } else {
            XCTAssertEqual(pill(.mealTrackerMaster, 7), "7-DAY STREAK")
            XCTAssertEqual(pill(.consistentWeigher, 1), "1 WEEK ACTIVE")
            XCTAssertEqual(pill(.consistentWeigher, 3), "3 WEEKS ACTIVE")
        }
    }

    func testTheConfettiBurstsThreeTimesAndThenStops() async {
        let confetti = GIFImageView(frame: CGRect(x: 0, y: 0, width: 150, height: 113))
        confetti.loopLimit = RewardDetailViewController.confettiBursts
        var passes = 0
        var finished = 0
        confetti.onReachedEnd = { passes += 1 }
        confetti.onFinished = { finished += 1 }
        confetti.loadGIF(named: "RewardConfetti")
        XCTAssertTrue(confetti.hasAnimatedGIF)

        let started = Date()
        confetti.startAnimatingGIF()
        let deadline = Date().addingTimeInterval(confetti.duration * 3 + 4)
        while finished == 0, Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(finished, 1, "The celebration ends instead of looping forever")
        XCTAssertEqual(passes, 2, "Two full passes before the third, final one")
        XCTAssertGreaterThan(Date().timeIntervalSince(started), confetti.duration * 2)
        try? await Task.sleep(nanoseconds: UInt64(confetti.duration * 1_000_000_000))
        XCTAssertEqual(finished, 1)
        XCTAssertEqual(passes, 2, "Nothing plays after the last burst")
    }

    // MARK: - Helpers

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }

    private func meal(on date: Date, type: MealType = .lunch) -> FoodEntry {
        FoodEntry(
            id: UUID(), name: "Oats", mealType: type,
            calories: 300, protein: 12, carbs: 40, fats: 8, fiber: 4, sugar: 2, sodium: 80,
            date: date
        )
    }

    private func foodEvent(for entry: FoodEntry, hour: Int, daysLater: Int = 0) -> XPEvent {
        let day = calendar.date(byAdding: .day, value: daysLater, to: calendar.startOfDay(for: entry.date))!
        let logged = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return XPEvent(id: UUID(), kind: .food, amount: XPEventKind.food.xpAmount, date: logged, relatedID: entry.id)
    }

    private func photo(on date: Date) -> ProgressPhoto {
        ProgressPhoto(id: UUID(), fileName: "p.jpg", kind: .progress, pose: .front, note: nil, date: date)
    }

    private func progress(
        foods: [FoodEntry],
        photos: [ProgressPhoto] = [],
        events: [XPEvent],
        now: Date
    ) -> [RewardBadge: BadgeProgress] {
        let list = BadgeProgressCalculator.progress(
            foods: foods, waters: [], weights: [], workouts: [], photos: photos,
            events: events, goals: .default, now: now, calendar: calendar
        )
        return Dictionary(uniqueKeysWithValues: list.map { ($0.badge, $0) })
    }
}

@MainActor
private final class RewardsApp {
    let harness = TestHarness()
    let rewards: RewardsRepository
    let evaluate: EvaluateBadgesUseCase
    let award: AwardXPUseCase

    init() {
        rewards = RewardsRepository(coreDataStack: harness.stack)
        evaluate = EvaluateBadgesUseCase(
            rewardsRepository: rewards,
            foodEntryRepository: harness.food,
            waterEntryRepository: harness.water,
            weightEntryRepository: harness.weight,
            workoutEntryRepository: harness.workout,
            progressPhotoRepository: harness.photos,
            userGoalsRepository: harness.goals
        )
        award = AwardXPUseCase(rewardsRepository: rewards, evaluateBadgesUseCase: evaluate)
    }
}
