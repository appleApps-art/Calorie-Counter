import UIKit
import XCTest
@testable import Calorie_Counter

final class ProgressChromeTests: XCTestCase {
    func testFullScrollBottomPaddingIsFigma24NotTabBarInset() throws {
        let xib = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/Features/Progress/ProgressViewController.xib")
        let xml = try String(contentsOf: xib, encoding: .utf8)
        XCTAssertTrue(xml.contains("id=\"ssb\""))
        XCTAssertTrue(xml.contains("<real key=\"value\" value=\"24\"/>"))
        XCTAssertTrue(xml.contains("id=\"scroll\""))
        XCTAssertTrue(xml.contains("clipsSubviews=\"NO\""))

        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/Features/Progress/ProgressViewController.swift")
        let swift = try String(contentsOf: source, encoding: .utf8)
        XCTAssertFalse(swift.contains("contentInset.bottom = tabHeight"))
        XCTAssertTrue(swift.contains("contentInsetAdjustmentBehavior = .never"))
        XCTAssertTrue(swift.contains("topEdgeEffect.isHidden = true"))
    }

    @MainActor
    func testWeightFieldFitsSliderValuesAcrossThreeDigitsInBothUnitsAndThemes() throws {
        for theme in [UIUserInterfaceStyle.light, .dark] {
            let harness = TestHarness()
            let vm = LogWeightViewModel(logWeightUseCase: harness.logWeight(), initialKilograms: 99.9)
            let controller = LogWeightViewController(viewModel: vm)
            controller.overrideUserInterfaceStyle = theme
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
            window.rootViewController = controller
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            controller.view.layoutIfNeeded()
            func descendants(_ view: UIView) -> [UIView] {
                view.subviews.flatMap { [$0] + descendants($0) }
            }
            let views = descendants(controller.view)
            let field = try XCTUnwrap(views.compactMap { $0 as? UITextField }.first)
            let slider = try XCTUnwrap(views.compactMap { $0 as? UISlider }.first)
            let units = try XCTUnwrap(views.compactMap { $0 as? UISegmentedControl }.first)
            for unit in 0...1 {
                units.selectedSegmentIndex = unit
                units.sendActions(for: .valueChanged)
                for value: Float in [99.9, 100, 100.1, 199.9, 200, unit == 1 ? 440 : 200, 62] {
                    slider.value = value
                    slider.sendActions(for: .valueChanged)
                    controller.view.layoutIfNeeded()
                    XCTAssertEqual(field.text, vm.displayValueText.value)
                    let required = ((field.text ?? "") as NSString).size(withAttributes: [.font: try XCTUnwrap(field.font)]).width
                    XCTAssertGreaterThanOrEqual(field.textRect(forBounds: field.bounds).width, ceil(required), "Clipped \(field.text ?? "") in unit \(unit), theme \(theme)")
                    XCTAssertEqual(field.font?.pointSize, 34)
                    XCTAssertLessThanOrEqual(field.convert(field.bounds, to: controller.view).maxX, 386)
                }
            }
        }
    }


    @MainActor
    func testWeightCalendarDisablesFutureDaysAndClampsInitialSelection() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: today))
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
        let controller = ChangeDateSheetViewController(date: tomorrow, maximumDate: today)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 522))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        func descendants(_ view: UIView) -> [UIView] {
            view.subviews.flatMap { [$0] + descendants($0) }
        }
        let calendar = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UICalendarView }.first)
        XCTAssertTrue(calendar.availableDateRange.contains(today))
        XCTAssertTrue(calendar.availableDateRange.contains(yesterday))
        XCTAssertFalse(calendar.availableDateRange.contains(tomorrow))
        var selected: Date?
        controller.onSelect = { selected = $0 }
        let confirm = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }.first {
            $0.actions(forTarget: controller, forControlEvent: .touchUpInside)?.contains("selectTapped") == true
        })
        confirm.sendActions(for: .touchUpInside)
        XCTAssertEqual(selected, today)
    }

    @MainActor
    func testWeightViewModelRejectsFutureDateAndAcceptsPastAndToday() throws {
        let harness = TestHarness()
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: today))
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
        let vm = LogWeightViewModel(logWeightUseCase: harness.logWeight(), initialKilograms: 70, date: yesterday)
        var selected: Date?
        vm.onChangeDate = { selected = $0 }
        vm.updateDate(tomorrow)
        vm.changeDateTapped()
        XCTAssertEqual(selected, yesterday)
        vm.updateDate(today)
        vm.changeDateTapped()
        XCTAssertEqual(selected, today)
        let restored = LogWeightViewModel(logWeightUseCase: harness.logWeight(), initialKilograms: 70, date: tomorrow)
        restored.onChangeDate = { selected = $0 }
        restored.changeDateTapped()
        XCTAssertTrue(Calendar.current.isDate(try XCTUnwrap(selected), inSameDayAs: today))
    }


    @MainActor
    func testWorkoutCanScrollEntireCaloriesCardAboveBottomFade() throws {
        for height: CGFloat in [667, 874] {
            let harness = TestHarness()
            let controller = LogWorkoutViewController(viewModel: LogWorkoutViewModel(logWorkoutUseCase: harness.logWorkout()))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: height))
            window.rootViewController = controller
            window.makeKeyAndVisible()
            defer { window.isHidden = true }
            controller.view.layoutIfNeeded()
            func descendants(_ view: UIView) -> [UIView] {
                view.subviews.flatMap { [$0] + descendants($0) }
            }
            let views = descendants(controller.view)
            let scroll = try XCTUnwrap(views.compactMap { $0 as? UIScrollView }.first)
            let calories = try XCTUnwrap(views.compactMap { $0 as? UITextField }.first { $0.keyboardType == .decimalPad })
            let card = try XCTUnwrap(calories.superview)
            XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
            scroll.setContentOffset(CGPoint(x: 0, y: scroll.contentSize.height - scroll.bounds.height), animated: false)
            controller.view.layoutIfNeeded()
            let visible = card.convert(card.bounds, to: scroll)
            XCTAssertGreaterThanOrEqual(visible.minY, scroll.bounds.minY)
            XCTAssertLessThanOrEqual(visible.maxY, scroll.bounds.maxY - 31)
            XCTAssertGreaterThanOrEqual(card.bounds.height, 92)
        }
    }

    @MainActor
    func testWorkoutRejectsFutureDatesAndSavesAcceptedPastDate() throws {
        let harness = TestHarness()
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: today))
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: today))
        let vm = LogWorkoutViewModel(logWorkoutUseCase: harness.logWorkout(), date: yesterday)
        vm.updateDate(tomorrow)
        vm.updateCalories("350")
        vm.saveTapped()
        XCTAssertTrue(vm.errorText.value.isEmpty)
        XCTAssertEqual(try harness.workout.fetchEntries().last?.date, yesterday)
        var selected: Date?
        vm.onChangeDate = { selected = $0 }
        vm.updateDate(today)
        vm.changeDateTapped()
        XCTAssertEqual(selected, today)
        let restored = LogWorkoutViewModel(logWorkoutUseCase: harness.logWorkout(), date: tomorrow)
        restored.onChangeDate = { selected = $0 }
        restored.changeDateTapped()
        XCTAssertTrue(Calendar.current.isDate(try XCTUnwrap(selected), inSameDayAs: today))
    }


    @MainActor
    func testWorkoutEstimatesScaleAndManualCaloriesArePreserved() throws {
        let harness = TestHarness()
        let vm = LogWorkoutViewModel(logWorkoutUseCase: harness.logWorkout(), bodyWeightKilograms: 70)
        XCTAssertEqual(vm.caloriesText.value, "239")
        XCTAssertTrue(vm.isCaloriesEstimated.value)
        vm.updateDuration(3600)
        XCTAssertEqual(vm.caloriesText.value, "478")
        vm.selectType(ExerciseType.walking.rawValue)
        XCTAssertEqual(vm.caloriesText.value, "206")
        vm.updateCalories("123,5")
        vm.updateDuration(1800)
        vm.selectType(ExerciseType.cycling.rawValue)
        XCTAssertEqual(vm.caloriesText.value, "123,5")
        XCTAssertFalse(vm.isCaloriesEstimated.value)
        vm.saveTapped()
        XCTAssertEqual(try harness.workout.fetchEntries().last?.caloriesBurned, 123.5)
        vm.updateCalories("")
        vm.finishEditingCalories()
        XCTAssertEqual(vm.caloriesText.value, "221")
        vm.selectType(ExerciseType.other.rawValue)
        XCTAssertEqual(vm.caloriesText.value, "")
        let noWeight = LogWorkoutViewModel(logWorkoutUseCase: harness.logWorkout())
        XCTAssertEqual(noWeight.caloriesText.value, "")
    }

    @MainActor
    func testEmptyWorkoutCaloriesFieldHasUsableTapAreaAndAcceptsEditing() throws {
        let harness = TestHarness()
        let vm = LogWorkoutViewModel(logWorkoutUseCase: harness.logWorkout())
        let controller = LogWorkoutViewController(viewModel: vm)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }
        let field = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UITextField }.first { $0.keyboardType == .decimalPad })
        XCTAssertGreaterThan(field.bounds.width, 150)
        XCTAssertGreaterThanOrEqual(field.bounds.height, 44)
        XCTAssertTrue(field.becomeFirstResponder())
        field.text = "375"
        field.sendActions(for: .editingChanged)
        XCTAssertEqual(vm.caloriesText.value, "375")
        field.resignFirstResponder()
        XCTAssertEqual(vm.caloriesText.value, "375")
    }


    @MainActor
    func testPhotoPreviewShowsDateWithoutNavigationAndRestoresThumbnailOnClose() async throws {
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(true) }
        let controller = UIViewController()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 200)).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 200))
        }
        let source = UIImageView(image: image)
        source.frame = CGRect(x: 16, y: 180, width: 160, height: 190)
        controller.view.addSubview(source)
        let preview = ProgressPhotoPreviewView(image: image, date: "16 вер. 2026 р.", source: source)
        preview.frame = controller.view.bounds
        controller.view.addSubview(preview)
        preview.show()
        XCTAssertNil(controller.presentedViewController)
        XCTAssertEqual(source.alpha, 0)
        XCTAssertEqual(preview.subviews.compactMap { $0 as? UILabel }.first?.text, "16 вер. 2026 р.")
        let enlarged = try XCTUnwrap(preview.subviews.compactMap { $0 as? UIImageView }.first)
        XCTAssertGreaterThan(enlarged.frame.height, source.frame.height)
        XCTAssertEqual(enlarged.frame.width / enlarged.frame.height, 0.6, accuracy: 0.001)
        let dismissed = expectation(description: "Preview close completion")
        preview.onDismiss = { dismissed.fulfill() }
        XCTAssertTrue(preview.accessibilityPerformEscape())
        await fulfillment(of: [dismissed], timeout: 2)
        XCTAssertNil(preview.superview)
        XCTAssertEqual(source.alpha, 1)
    }

}
