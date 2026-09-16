import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class EditMealInteractionTests: XCTestCase {
    func testEditMealPlusPresentsFourLoggingOptions() async throws {
        let host = UINavigationController(rootViewController: UIViewController())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let coordinator = FoodLoggingCoordinator(navigationController: host,
            container: DIContainer(coreDataStack: CoreDataStack(inMemory: true)))
        coordinator.openEditMeal(mealType: .lunch, date: Date())
        try await Task.sleep(nanoseconds: 600_000_000)
        let editorNav = try XCTUnwrap(host.presentedViewController as? UINavigationController)
        let editor = try XCTUnwrap(editorNav.topViewController as? EditMealViewController)
        let plus = try XCTUnwrap(descendants(editor.view).compactMap { $0 as? UIButton }.first { button in
            button.allTargets.contains { target in
                button.actions(forTarget: target, forControlEvent: .touchUpInside)?.contains("addTapped") == true
            }
        })
        plus.sendActions(for: .touchUpInside)
        try await Task.sleep(nanoseconds: 600_000_000)
        let sheet = try XCTUnwrap(editorNav.presentedViewController as? QuickLogSheetViewController)
        XCTAssertTrue(editorNav.topViewController === editor)
        let labels = descendants(sheet.view).compactMap { ($0 as? UILabel)?.text }
        for key in ["food.edit.addMeal", "home.quickLog.scanFood", "home.quickLog.scanBarcode", "home.quickLog.search", "home.quickLog.voiceLog"] {
            XCTAssertTrue(labels.contains(L10n.tr(key)), key)
        }
        sheet.view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(bounds: sheet.view.bounds)
        let image = renderer.image { context in sheet.view.layer.render(in: context.cgContext) }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Edit meal add options"
        attachment.lifetime = .keepAlways
        add(attachment)
        host.dismiss(animated: false)
    }

    func testMicrophoneRestoresIdleColorAfterVoiceConfirmation() throws {
        let model = makeViewModel(harness: TestHarness(), service: EditMealTestAssistant())
        let controller = EditMealViewController(viewModel: model)
        controller.overrideUserInterfaceStyle = .dark
        controller.loadViewIfNeeded()
        let mic = try XCTUnwrap(controller.value(forKey: "micButton") as? UIButton)
        model.canConfirmVoice.value = true
        model.canConfirmVoice.value = false
        let traits = UITraitCollection(userInterfaceStyle: .dark)
        XCTAssertEqual(mic.tintColor.resolvedColor(with: traits), AppColor.iconSecondary.resolvedColor(with: traits))
        XCTAssertEqual(mic.imageView?.tintColor.resolvedColor(with: traits), AppColor.iconSecondary.resolvedColor(with: traits))
        XCTAssertEqual(mic.currentImage?.renderingMode, .alwaysOriginal)
    }

    func testHeaderButtonsStayCircularAcrossPhoneSizes() throws {
        let model = makeViewModel(harness: TestHarness(), service: EditMealTestAssistant())
        let controller = EditMealViewController(viewModel: model)
        controller.loadViewIfNeeded()
        let close = try XCTUnwrap(controller.value(forKey: "closeButton") as? UIButton)
        let add = try XCTUnwrap(controller.value(forKey: "addButton") as? UIButton)
        for size in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 813), CGSize(width: 440, height: 900)] {
            controller.view.frame = CGRect(origin: .zero, size: size)
            controller.view.refreshAdaptiveLayout()
            controller.view.layoutIfNeeded()
            for button in [close, add] {
                XCTAssertEqual(button.bounds.width, button.bounds.height, accuracy: 0.5)
            }
        }
    }

    func testPortionEditingUsesDecimalKeyboardAndRestoresUnit() throws {
        for portion in ["200г", "250мл", "2 шт"] {
            let view = EditMealPortionFieldView()
            let id = UUID()
            view.configure(EditMealItem(id: id, name: "Food", detailText: "", portionText: portion, imageURL: nil, imageData: nil))
            let field = try XCTUnwrap(descendants(view).compactMap { $0 as? UITextField }.first)
            XCTAssertEqual(field.keyboardType, .decimalPad)
            view.textFieldDidBeginEditing(field)
            XCTAssertTrue(field.text?.allSatisfy(\.isNumber) == true)
            var committed: String?
            view.onCommitPortion = { committedID, text in
                XCTAssertEqual(committedID, id)
                committed = text
            }
            field.text = "125,5"
            view.textFieldDidEndEditing(field)
            let suffix = String(portion.drop { $0.isNumber })
            XCTAssertEqual(committed, "125,5" + suffix)
            XCTAssertEqual(field.text, "125,5" + suffix)
        }
    }

    func testUnknownWeightDoesNotDisplayCaloriesAndFirstMeasurementPreservesNutrition() throws {
        let harness = TestHarness()
        let model = makeViewModel(harness: harness, service: EditMealTestAssistant())
        let entry = FoodLogProposal(name: "Yogurt", mealType: .breakfast, calories: 660,
                                    protein: 20, carbs: 70, fats: 30).toFoodEntry(date: Date())
        model.viewDidLoad()
        try model.stageAdditions([entry])
        let item = try XCTUnwrap(model.items.value.first)
        XCTAssertEqual(item.portionText, "")
        XCTAssertTrue(item.detailText.contains("660"))
        let view = EditMealPortionFieldView()
        view.configure(item)
        let field = try XCTUnwrap(descendants(view).compactMap { $0 as? UITextField }.first)
        XCTAssertEqual(field.placeholder, L10n.tr("editMeal.weightPlaceholder"))
        view.onCommitPortion = { model.commitPortion(id: $0, text: $1) }
        view.textFieldDidBeginEditing(field)
        field.text = "250"
        view.textFieldDidEndEditing(field)
        let measured = try XCTUnwrap(model.foodEntry(id: entry.id))
        XCTAssertEqual(measured.portionGrams, 250)
        XCTAssertEqual(measured.calories, 660)
        XCTAssertEqual(measured.protein, 20)
        XCTAssertTrue(try harness.food.fetchAll().isEmpty)
        model.commitPortion(id: entry.id, text: "125 g")
        let reduced = try XCTUnwrap(model.foodEntry(id: entry.id))
        XCTAssertEqual(reduced.calories, 330)
        XCTAssertEqual(reduced.protein, 10)
        model.saveTapped()
        XCTAssertEqual(try harness.food.fetchEntry(id: entry.id), reduced)
    }

    func testPortionRejectsLettersPastedUnitsAndMultipleSeparators() throws {
        let view = EditMealPortionFieldView()
        view.configure(EditMealItem(id: UUID(), name: "Food", detailText: "", portionText: "200г", imageURL: nil, imageData: nil))
        let field = try XCTUnwrap(descendants(view).compactMap { $0 as? UITextField }.first)
        view.textFieldDidBeginEditing(field)
        for replacement in ["abc", "250г", "1.2.3", "-10", "1e5", "12 34", "1\n2"] {
            XCTAssertFalse(view.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 3), replacementString: replacement), replacement)
        }
        for replacement in ["", "1", "12,5", "12.5"] {
            XCTAssertTrue(view.textField(field, shouldChangeCharactersIn: NSRange(location: 0, length: 3), replacementString: replacement), replacement)
        }
        var commits = 0
        view.onCommitPortion = { _, _ in commits += 1 }
        for invalid in ["", "0", ".", "letters"] {
            view.textFieldDidBeginEditing(field)
            field.text = invalid
            view.textFieldDidEndEditing(field)
            XCTAssertEqual(field.text, "200г")
        }
        XCTAssertEqual(commits, 0)
    }

    func testSendButtonIsExcludedFromKeyboardDismissGestureIncludingSubviews() {
        let controller = UIViewController()
        let send = UIButton()
        let icon = UIImageView()
        send.addSubview(icon)
        controller.view.addSubview(send)
        let binder = KeyboardDismissBinder()
        binder.attach(to: controller, excluding: { [send] })
        XCTAssertFalse(binder.shouldDismissKeyboard(for: send))
        XCTAssertFalse(binder.shouldDismissKeyboard(for: icon))
        XCTAssertTrue(binder.shouldDismissKeyboard(for: controller.view))
        XCTAssertFalse(binder.shouldDismissKeyboard(for: UITextField()))
    }

    func testOneSendActionSubmitsTextAndDismissesKeyboardWithoutWaiting() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        let viewModel = makeViewModel(harness: harness, service: service)
        let controller = EditMealViewController(viewModel: viewModel)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        let field = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UITextField }.first)
        let button = try XCTUnwrap(controller.keyboardDismissExcludedViews.first as? UIButton)
        field.text = "додай плов"
        XCTAssertTrue(field.becomeFirstResponder())
        button.sendActions(for: .touchUpInside)
        XCTAssertTrue(viewModel.isSending.value)
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertEqual(field.text, "")
        button.sendActions(for: .touchUpInside)
        await waitForCompletion(viewModel)
        XCTAssertEqual(service.messages, ["додай плов"])
    }

    func testReturnSubmitsCurrentFieldTextThroughSameHandler() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        let viewModel = makeViewModel(harness: harness, service: service)
        let controller = EditMealViewController(viewModel: viewModel)
        controller.loadViewIfNeeded()
        let field = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UITextField }.first)
        field.text = "додай борщ"
        XCTAssertTrue(controller.textFieldShouldReturn(field))
        XCTAssertTrue(viewModel.isSending.value)
        await waitForCompletion(viewModel)
        XCTAssertEqual(service.messages, ["додай борщ"])
    }

    func testAssistantRequestIdentifiesOnlyTheMealBeingEdited() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        let date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let breakfast = FoodLogProposal(name: "Яблуко", mealType: .breakfast, calories: 52,
                                       protein: 0.3, carbs: 14, fats: 0.2).toFoodEntry(date: date)
        let lunch = FoodLogProposal(name: "Суп", mealType: .lunch, calories: 200,
                                   protein: 10, carbs: 30, fats: 5).toFoodEntry(date: date)
        let previousBreakfast = FoodLogProposal(name: "Вівсянка", mealType: .breakfast, calories: 300,
                                               protein: 10, carbs: 50, fats: 7)
            .toFoodEntry(date: try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: date)))
        for entry in [breakfast, lunch, previousBreakfast] { try harness.food.save(entry) }
        let model = makeViewModel(harness: harness, service: service, date: date)
        model.reload()
        model.updateInput("додай банан")
        model.sendTapped()
        await waitForCompletion(model)

        let request = try XCTUnwrap(service.requests.first)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        let context = try XCTUnwrap(encoded?["userContext"] as? [String: Any])
        let editing = try XCTUnwrap(context["mealEditing"] as? [String: Any])
        XCTAssertEqual(editing["mealType"] as? String, "breakfast")
        XCTAssertEqual(editing["entryIDs"] as? [String], [breakfast.id.uuidString])
    }

    func testClarificationIsShownWithoutChangingTheDiary() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        let clarification = "Яке саме яблуко потрібно замінити?"
        service.response = assistantResponse(content: clarification)
        let model = makeViewModel(harness: harness, service: service)
        XCTAssertNil(model.assistantMessage.value)
        model.updateInput("заміни яблуко")
        model.sendTapped()
        await waitForCompletion(model)

        XCTAssertEqual(model.assistantMessage.value, clarification)
        XCTAssertTrue(try harness.food.fetchAll().isEmpty)
        XCTAssertTrue(model.scanningItemIDs.value.isEmpty)
    }

    func testAssistantClarificationIsPresentedOnTheMealScreen() async throws {
        let service = EditMealTestAssistant()
        let clarification = "Яке саме яблуко потрібно замінити?"
        service.response = assistantResponse(content: clarification)
        let model = makeViewModel(harness: TestHarness(), service: service)
        let controller = EditMealViewController(viewModel: model)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            controller.dismiss(animated: false)
            window.isHidden = true
        }
        controller.view.layoutIfNeeded()
        model.updateInput("заміни яблуко")
        model.sendTapped()
        await waitForCompletion(model)
        try await Task.sleep(nanoseconds: 350_000_000)

        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.preferredStyle, .alert)
        XCTAssertEqual(alert.title, L10n.tr("editMeal.aiTitle"))
        XCTAssertEqual(alert.message, clarification)
        XCTAssertEqual(alert.actions.count, 1)
    }

    func testAssistantFailureShowsErrorAndRestoresInputWithoutOverwritingANewDraft() async throws {
        for newDraft in ["", "додай грушу"] {
            let harness = TestHarness()
            let service = EditMealTestAssistant()
            service.error = AIAssistantServiceError.server(message: "Пошук тимчасово недоступний")
            let model = makeViewModel(harness: harness, service: service)
            service.onRequest = { model.updateInput(newDraft) }
            model.updateInput("додай яблуко")
            model.sendTapped()
            await waitForCompletion(model)

            XCTAssertEqual(model.assistantMessage.value, "Пошук тимчасово недоступний")
            XCTAssertEqual(model.inputText.value, newDraft.isEmpty ? "додай яблуко" : newDraft)
            XCTAssertTrue(try harness.food.fetchAll().isEmpty)
            XCTAssertTrue(model.scanningItemIDs.value.isEmpty)
        }
    }

    func testCatalogFoodLogPreservesIdentityAndPortionNutritionInSelectedMeal() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        service.response = assistantResponse(content: "Додано яблуко", calls: [
            assistantCall("propose_food_log", arguments: catalogAppleArguments())
        ])
        let model = makeViewModel(harness: harness, service: service)
        model.updateInput("додай 300 г яблука")
        model.sendTapped()
        await waitForCompletion(model)

        let entry = try XCTUnwrap(model.items.value.first.flatMap { model.foodEntry(id: $0.id) })
        XCTAssertTrue(try harness.food.fetchAll().isEmpty)
        XCTAssertEqual(entry.name, "Яблуко")
        XCTAssertEqual(entry.mealType, .breakfast)
        XCTAssertEqual(entry.catalogExternalId, "9003")
        XCTAssertEqual(entry.catalogKind, .ingredient)
        XCTAssertEqual(entry.source, "spoonacular")
        XCTAssertEqual(entry.portionGrams, 300)
        XCTAssertEqual(entry.calories, 156, accuracy: 0.001)
        XCTAssertEqual(entry.protein, 0.9, accuracy: 0.001)
        XCTAssertEqual(entry.carbs, 42, accuracy: 0.001)
        XCTAssertEqual(entry.fats, 0.6, accuracy: 0.001)
        model.commitPortion(id: entry.id, text: "150 г")
        let reduced = try XCTUnwrap(model.foodEntry(id: entry.id))
        XCTAssertEqual(reduced.calories, 78, accuracy: 0.001)
        XCTAssertEqual(reduced.protein, 0.45, accuracy: 0.001)
        XCTAssertEqual(reduced.carbs, 21, accuracy: 0.001)
        XCTAssertEqual(reduced.fats, 0.3, accuracy: 0.001)
        XCTAssertEqual(reduced.catalogExternalId, "9003")
        XCTAssertTrue(try harness.food.fetchAll().isEmpty)
        model.saveTapped()
        XCTAssertEqual(try harness.food.fetchEntry(id: entry.id), reduced)
    }

    func testSuccessfulFoodLogStillShowsClarificationForTheRemainingRequest() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        let reply = "Додано яблуко. Яку саме кашу додати?"
        service.response = assistantResponse(content: reply, calls: [
            assistantCall("propose_food_log", arguments: catalogAppleArguments())
        ])
        let model = makeViewModel(harness: harness, service: service)
        model.updateInput("додай 300 г яблука і кашу")
        model.sendTapped()
        await waitForCompletion(model)

        XCTAssertTrue(try harness.food.fetchAll().isEmpty)
        let entries = model.items.value.compactMap { model.foodEntry(id: $0.id) }
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "Яблуко")
        XCTAssertEqual(entries.first?.mealType, .breakfast)
        XCTAssertEqual(model.assistantMessage.value, reply)
    }

    func testReplacementCannotChangeAnEntryOutsideTheDisplayedMeal() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        let date = Date()
        let breakfast = FoodLogProposal(name: "Вівсянка", mealType: .breakfast, calories: 300,
                                       protein: 10, carbs: 50, fats: 7).toFoodEntry(date: date)
        let lunch = FoodLogProposal(name: "Яблуко", mealType: .lunch, calories: 52,
                                   protein: 0.3, carbs: 14, fats: 0.2).toFoodEntry(date: date)
        for entry in [breakfast, lunch] { try harness.food.save(entry) }
        service.response = assistantResponse(calls: [assistantCall("propose_food_replace", arguments: [
            "targetEntryId": lunch.id.uuidString,
            "targetName": breakfast.name,
            "newItem": catalogAppleArguments()
        ])])
        let model = makeViewModel(harness: harness, service: service, date: date)
        model.reload()
        model.updateInput("заміни вівсянку яблуком")
        model.sendTapped()
        await waitForCompletion(model)

        XCTAssertEqual(try harness.food.fetchAll().count, 2)
        XCTAssertEqual(try harness.food.fetchEntry(id: breakfast.id), breakfast)
        XCTAssertEqual(try harness.food.fetchEntry(id: lunch.id), lunch)
        XCTAssertEqual(model.assistantMessage.value, L10n.tr("editMeal.ai.targetNotFound"))
    }

    func testMissingOrAmbiguousReplacementTargetNeverFallsBackToAddingFood() async throws {
        let targetArguments: [[String: Any]] = [
            [:], ["targetName": "Груша"], ["targetName": "Яблуко"], ["targetEntryId": UUID().uuidString]
        ]
        for target in targetArguments {
            let harness = TestHarness()
            let service = EditMealTestAssistant()
            let date = Date()
            let originals = (1...2).map { index in
                FoodLogProposal(name: "Яблуко", mealType: .breakfast, calories: Double(index * 52),
                                protein: 0.3, carbs: 14, fats: 0.2).toFoodEntry(date: date)
            }
            for entry in originals { try harness.food.save(entry) }
            var arguments = target
            arguments["newItem"] = catalogAppleArguments()
            service.response = assistantResponse(calls: [assistantCall("propose_food_replace", arguments: arguments)])
            let model = makeViewModel(harness: harness, service: service, date: date)
            model.reload()
            model.updateInput("заміни яблуко")
            model.sendTapped()
            await waitForCompletion(model)

            XCTAssertEqual(try harness.food.fetchAll().count, originals.count, "Target: \(target)")
            for entry in originals {
                XCTAssertEqual(try harness.food.fetchEntry(id: entry.id), entry, "Target: \(target)")
            }
            XCTAssertEqual(model.assistantMessage.value, L10n.tr("editMeal.ai.targetNotFound"), "Target: \(target)")
        }
    }

    func testExplicitReplacementKeepsTargetIDAndCatalogIdentityInSelectedMeal() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        let date = Date()
        let original = FoodLogProposal(name: "Груша", mealType: .breakfast, calories: 60,
                                      protein: 0.3, carbs: 15, fats: 0.2).toFoodEntry(date: date)
        try harness.food.save(original)
        service.response = assistantResponse(content: "Замінено", calls: [
            assistantCall("propose_food_replace", arguments: [
                "targetEntryId": original.id.uuidString, "newItem": catalogAppleArguments()
            ])
        ])
        let model = makeViewModel(harness: harness, service: service, date: date)
        model.reload()
        model.updateInput("заміни грушу на 300 г яблука")
        model.sendTapped()
        await waitForCompletion(model)

        XCTAssertEqual(try harness.food.fetchEntry(id: original.id), original)
        model.saveTapped()
        let updated = try XCTUnwrap(harness.food.fetchEntry(id: original.id))
        XCTAssertEqual(try harness.food.fetchAll().count, 1)
        XCTAssertEqual(updated.name, "Яблуко")
        XCTAssertEqual(updated.mealType, .breakfast)
        XCTAssertEqual(updated.catalogExternalId, "9003")
        XCTAssertEqual(updated.catalogKind, .ingredient)
        XCTAssertEqual(updated.portionGrams, 300)
        XCTAssertEqual(updated.calories, 156, accuracy: 0.001)
    }

    func testMealSuggestionsShowAReplyWithoutAutomaticallyAddingTheFirstOption() async throws {
        for content in ["Виберіть яблуко або грушу.", ""] {
            let harness = TestHarness()
            let service = EditMealTestAssistant()
            service.response = assistantResponse(content: content, calls: [
                assistantCall("propose_meal_suggestions", arguments: [
                    "mealType": "breakfast",
                    "options": [
                        ["title": "Яблуко", "calories": 52, "protein": 0.3, "carbs": 14, "fats": 0.2],
                        ["title": "Груша", "calories": 60, "protein": 0.3, "carbs": 15, "fats": 0.2]
                    ]
                ])
            ])
            let model = makeViewModel(harness: harness, service: service)
            model.updateInput("який фрукт додати?")
            model.sendTapped()
            await waitForCompletion(model)

            XCTAssertTrue(try harness.food.fetchAll().isEmpty)
            if content.isEmpty {
                XCTAssertEqual(model.assistantMessage.value, L10n.tr("editMeal.ai.noChanges"))
            } else {
                XCTAssertEqual(model.assistantMessage.value, content)
            }
        }
    }

    func testFoodSwapSuggestionDoesNotReplaceAMatchingDiaryEntry() async throws {
        for content in ["Можна замінити майонез грецьким йогуртом.", ""] {
            let harness = TestHarness()
            let service = EditMealTestAssistant()
            let date = Date()
            let original = FoodLogProposal(name: "Майонез", mealType: .breakfast, calories: 136,
                                          protein: 0.2, carbs: 0.2, fats: 15).toFoodEntry(date: date)
            try harness.food.save(original)
            service.response = assistantResponse(content: content, calls: [
                assistantCall("propose_food_swap", arguments: [
                    "applyToEntryId": original.id.uuidString,
                    "original": ["name": "Майонез", "calories": 136, "protein": 0.2, "carbs": 0.2, "fats": 15],
                    "alternative": ["name": "Грецький йогурт", "calories": 20, "protein": 2, "carbs": 1, "fats": 1],
                    "savingsKcal": 116
                ])
            ])
            let model = makeViewModel(harness: harness, service: service, date: date)
            model.reload()
            model.updateInput("що корисніше можна взяти замість майонезу?")
            model.sendTapped()
            await waitForCompletion(model)

            XCTAssertEqual(try harness.food.fetchAll().count, 1)
            XCTAssertEqual(try harness.food.fetchEntry(id: original.id), original)
            XCTAssertEqual(model.assistantMessage.value, content.isEmpty ? L10n.tr("editMeal.ai.noChanges") : content)
        }
    }

    func testExistingMealWithoutPhotoReceivesNamedRecoveryURL() throws {
        let harness = TestHarness()
        let date = Date()
        let entry = FoodLogProposal(name: "Плов", mealType: .breakfast, calories: 350,
                                    protein: 10, carbs: 40, fats: 15).toFoodEntry(date: date)
        try harness.food.save(entry)
        let viewModel = makeViewModel(harness: harness, service: EditMealTestAssistant(), date: date)
        viewModel.reload()
        let item = try XCTUnwrap(viewModel.items.value.first)
        XCTAssertEqual(item.id, entry.id)
        XCTAssertEqual(item.fallbackImageURL, AIAssistantAPIConfiguration.production.foodImageURL(name: "Плов"))
        XCTAssertEqual(try harness.food.fetchAll().count, 1)
    }

    func testLastFoodAndPortionScrollAboveAssistantFadeOnDifferentScreenSizes() throws {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)] {
            let (controller, window) = try makeLongMealScreen(size: size)
            defer { window.isHidden = true }
            let scroll = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIScrollView }.first)
            let fade = try XCTUnwrap(controller.view.subviews.first {
                $0.layer.sublayers?.contains { $0 is CAGradientLayer } == true
            })
            let row = try XCTUnwrap(descendants(scroll).compactMap { $0 as? EditMealFoodRowView }.last)
            let portion = try XCTUnwrap(descendants(scroll).compactMap { $0 as? EditMealPortionFieldView }.last)
            scrollToBottom(scroll)
            let visibleArea = scroll.convert(scroll.bounds, to: controller.view)
            let fadeTop = fade.convert(fade.bounds, to: controller.view).minY
            let rowFrame = row.convert(row.bounds, to: controller.view)
            let portionFrame = portion.convert(portion.bounds, to: controller.view)
            XCTAssertGreaterThanOrEqual(rowFrame.minY, visibleArea.minY, "Screen: \(size)")
            XCTAssertLessThan(portionFrame.maxY, fadeTop, "The last portion must clear the fade on \(size)")
            let snapshot = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: snapshot)
            attachment.name = "Last meal visible \(Int(size.width))x\(Int(size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testFadeScrollSpaceIsRemovedDuringPortionEditingAndRestoredAfterwards() async throws {
        let (controller, window) = try makeLongMealScreen(size: CGSize(width: 402, height: 874))
        defer { window.isHidden = true }
        let scroll = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIScrollView }.first)
        let initialInset = scroll.contentInset.bottom
        XCTAssertGreaterThan(initialInset, 0)
        let portion = try XCTUnwrap(descendants(scroll).compactMap { $0 as? EditMealPortionFieldView }.last)
        let field = try XCTUnwrap(descendants(portion).compactMap { $0 as? UITextField }.first)
        scrollToBottom(scroll)
        XCTAssertTrue(field.becomeFirstResponder())
        try await Task.sleep(nanoseconds: 400_000_000)
        controller.view.layoutIfNeeded()
        XCTAssertEqual(scroll.contentInset.bottom, 0, accuracy: 0.5)
        let portionFrame = portion.convert(portion.bounds, to: controller.view)
        let visibleArea = scroll.convert(scroll.bounds, to: controller.view)
        XCTAssertTrue(visibleArea.contains(portionFrame), "Editing must reveal the last portion without manual scrolling")
        XCTAssertLessThanOrEqual(portionFrame.maxY, controller.view.keyboardLayoutGuide.layoutFrame.minY)
        let snapshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = "Active bottom portion above keyboard"
        attachment.lifetime = .keepAlways
        add(attachment)
        let firstPortion = try XCTUnwrap(descendants(scroll).compactMap { $0 as? EditMealPortionFieldView }.first)
        let firstField = try XCTUnwrap(descendants(firstPortion).compactMap { $0 as? UITextField }.first)
        XCTAssertTrue(firstField.becomeFirstResponder())
        try await Task.sleep(nanoseconds: 150_000_000)
        controller.view.layoutIfNeeded()
        XCTAssertTrue(field.becomeFirstResponder())
        try await Task.sleep(nanoseconds: 150_000_000)
        controller.view.layoutIfNeeded()
        XCTAssertTrue(scroll.convert(scroll.bounds, to: controller.view).contains(portion.convert(portion.bounds, to: controller.view)))
        controller.view.endEditing(true)
        try await Task.sleep(nanoseconds: 400_000_000)
        controller.view.layoutIfNeeded()
        XCTAssertEqual(scroll.contentInset.bottom, initialInset, accuracy: 0.5)
        scrollToBottom(scroll)
        let lastPortion = try XCTUnwrap(descendants(scroll).compactMap { $0 as? EditMealPortionFieldView }.last)
        XCTAssertLessThan(lastPortion.convert(lastPortion.bounds, to: controller.view).maxY,
                          scroll.convert(scroll.bounds, to: controller.view).maxY - initialInset)
    }

    func testLateKeyboardFrameRevealsBottomPortionWithoutManualScrolling() async throws {
        let (controller, window) = try makeLongMealScreen(size: CGSize(width: 402, height: 874))
        defer { window.isHidden = true }
        window.windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        let scroll = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIScrollView }.first)
        let portion = try XCTUnwrap(descendants(scroll).compactMap { $0 as? EditMealPortionFieldView }.last)
        let field = try XCTUnwrap(descendants(portion).compactMap { $0 as? UITextField }.first)
        scrollToBottom(scroll)
        XCTAssertTrue(field.becomeFirstResponder())
        try await Task.sleep(nanoseconds: 400_000_000)
        let keyboardTop: CGFloat = 400
        let keyboardFrame = window.convert(CGRect(x: 0, y: keyboardTop, width: 402, height: 474), to: window.screen.coordinateSpace)
        NotificationCenter.default.post(name: UIResponder.keyboardDidChangeFrameNotification, object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: keyboardFrame])
        controller.view.layoutIfNeeded()
        let fieldFrame = portion.convert(portion.bounds, to: window)
        XCTAssertLessThanOrEqual(fieldFrame.maxY, keyboardTop - 8)
        XCTAssertGreaterThanOrEqual(fieldFrame.minY, scroll.convert(scroll.bounds, to: window).minY)
        controller.view.endEditing(true)
    }

    func testRapidDeletionPreservesRemainingRowsAndPortionFields() async throws {
        let (controller, window) = try makeLongMealScreen(size: CGSize(width: 402, height: 874))
        defer { window.isHidden = true }
        let rows = descendants(controller.view).compactMap { $0 as? EditMealFoodRowView }
        let fields = descendants(controller.view).compactMap { $0 as? EditMealPortionFieldView }
        XCTAssertEqual(rows.count, 8)
        rows[0].onDelete?(try XCTUnwrap(rows[0].itemID))
        rows[1].onDelete?(try XCTUnwrap(rows[1].itemID))
        try await Task.sleep(nanoseconds: 400_000_000)
        controller.view.layoutIfNeeded()
        let survivors = descendants(controller.view).compactMap { $0 as? EditMealFoodRowView }
        let survivingFields = descendants(controller.view).compactMap { $0 as? EditMealPortionFieldView }
        XCTAssertEqual(survivors.count, 6)
        XCTAssertEqual(survivingFields.count, 6)
        for index in 0..<6 {
            XCTAssertTrue(survivors[index] === rows[index + 2])
            XCTAssertTrue(survivingFields[index] === fields[index + 2])
        }
        for row in survivors { row.onDelete?(try XCTUnwrap(row.itemID)) }
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertTrue(descendants(controller.view).compactMap { $0 as? EditMealFoodRowView }.isEmpty)
    }

    private func makeLongMealScreen(size: CGSize) throws -> (EditMealViewController, UIWindow) {
        let harness = TestHarness()
        let date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 44, height: 44)).pngData { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 44, height: 44))
        }
        for index in 1...8 {
            var entry = FoodLogProposal(name: "Плов \(index)", mealType: .breakfast, calories: 520,
                                        protein: 18, carbs: 65, fats: 20).toFoodEntry(date: date.addingTimeInterval(Double(index)))
            entry.portionGrams = 300
            entry.imageData = photo
            try harness.food.save(entry)
        }
        let controller = EditMealViewController(viewModel: makeViewModel(harness: harness, service: EditMealTestAssistant(), date: date))
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        XCTAssertEqual(controller.view.bounds.size, size)
        return (controller, window)
    }

    func testCloseAndSwipeDiscardDeletionAndPortionDraft() throws {
        for swipe in [false, true] {
            let harness = TestHarness()
            let date = Date()
            let first = draftTestEntry(name: "Apple", date: date)
            let second = draftTestEntry(name: "Pear", date: date)
            try harness.food.save(first)
            try harness.food.save(second)
            let model = makeViewModel(harness: harness, service: EditMealTestAssistant(), date: date)
            let controller = EditMealViewController(viewModel: model)
            controller.loadViewIfNeeded()
            model.deleteFood(id: first.id)
            model.commitPortion(id: second.id, text: "200 g")
            model.reload()
            XCTAssertEqual(model.items.value.count, 1)
            XCTAssertEqual(model.foodEntry(id: second.id)?.calories, 104)
            XCTAssertEqual(try harness.food.fetchEntry(id: first.id), first)
            XCTAssertEqual(try harness.food.fetchEntry(id: second.id), second)
            if swipe {
                controller.presentationControllerDidDismiss(UIPresentationController(presentedViewController: controller, presenting: nil))
            } else {
                let close = try XCTUnwrap(controller.value(forKey: "closeButton") as? UIButton)
                close.sendActions(for: .touchUpInside)
            }
            model.saveTapped()
            let reopened = makeViewModel(harness: harness, service: EditMealTestAssistant(), date: date)
            reopened.reload()
            XCTAssertEqual(reopened.items.value.count, 2)
            XCTAssertEqual(reopened.foodEntry(id: first.id), first)
            XCTAssertEqual(reopened.foodEntry(id: second.id), second)
        }
    }

    func testSaveCommitsOnlyDraftChangesOnceAndPreservesOtherEntries() throws {
        let harness = TestHarness()
        let date = Date()
        let deleted = draftTestEntry(name: "Apple", date: date)
        let edited = draftTestEntry(name: "Pear", date: date)
        let lunch = draftTestEntry(name: "Soup", date: date, meal: .lunch)
        for entry in [deleted, edited, lunch] { try harness.food.save(entry) }
        let model = makeViewModel(harness: harness, service: EditMealTestAssistant(), date: date)
        model.reload()
        let concurrent = draftTestEntry(name: "Later external addition", date: date)
        try harness.food.save(concurrent)
        model.deleteFood(id: deleted.id)
        model.commitPortion(id: edited.id, text: "200 g")
        let added = draftTestEntry(name: "Banana", date: date)
        try model.stageAdditions([added])
        var savedCount = 0
        model.onSaved = { savedCount += 1 }
        model.saveTapped()
        model.saveTapped()
        XCTAssertEqual(savedCount, 1)
        XCTAssertNil(try harness.food.fetchEntry(id: deleted.id))
        XCTAssertEqual(try harness.food.fetchEntry(id: edited.id)?.calories, 104)
        XCTAssertEqual(try harness.food.fetchEntry(id: added.id), added)
        XCTAssertEqual(try harness.food.fetchEntry(id: lunch.id), lunch)
        XCTAssertEqual(try harness.food.fetchEntry(id: concurrent.id), concurrent)
    }

    func testAddingFromChildScreenStaysInDraftUntilMealSave() throws {
        for save in [false, true] {
            let harness = TestHarness()
            let date = Date()
            let model = makeViewModel(harness: harness, service: EditMealTestAssistant(), date: date)
            model.reload()
            let child = AddFoodEntryViewModel(logFoodUseCase: LogFoodUseCase(foodEntryRepository: harness.food),
                                             stageEntries: { try model.stageAdditions($0) })
            child.configure(ProductDetailsMath.draft(from: draftTestEntry(name: "Apple", date: date)))
            child.addEntryTapped()
            XCTAssertTrue(child.showsAddedAlert.value)
            XCTAssertEqual(child.addedAlertText.value, L10n.tr("editMeal.addedToDraft"))
            XCTAssertEqual(model.items.value.count, 1)
            XCTAssertTrue(try harness.food.fetchAll().isEmpty)
            if save { model.saveTapped() } else { model.closeTapped() }
            XCTAssertEqual(try harness.food.fetchAll().count, save ? 1 : 0)
        }
    }

    func testClosingWhileAssistantRespondsCannotWriteOrChangeDraft() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        service.response = assistantResponse(calls: [assistantCall("propose_food_log", arguments: catalogAppleArguments())])
        let model = makeViewModel(harness: harness, service: service)
        service.onRequest = { model.closeTapped() }
        model.updateInput("apple")
        model.sendTapped()
        await waitForCompletion(model)
        model.saveTapped()
        XCTAssertTrue(try harness.food.fetchAll().isEmpty)
        XCTAssertFalse(model.isSending.value)
        XCTAssertNil(model.assistantMessage.value)
    }

    func testAssistantSeesUnsavedMealAndCancelDiscardsItsReplacement() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        let date = Date()
        var deleted = draftTestEntry(name: "Apple", date: date)
        var edited = draftTestEntry(name: "Pear", date: date)
        deleted.isEaten = true
        edited.isEaten = true
        for entry in [deleted, edited] { try harness.food.save(entry) }
        let model = makeViewModel(harness: harness, service: service, date: date)
        model.reload()
        model.deleteFood(id: deleted.id)
        model.commitPortion(id: edited.id, text: "200 g")
        service.response = assistantResponse(calls: [assistantCall("propose_food_replace", arguments: [
            "targetEntryId": edited.id.uuidString, "newItem": catalogAppleArguments()
        ])])
        model.updateInput("replace pear with apple")
        model.sendTapped()
        await waitForCompletion(model)
        let context = try XCTUnwrap(service.requests.first?.userContext)
        XCTAssertEqual(context.mealEditing?.entryIDs, [edited.id.uuidString])
        XCTAssertEqual(context.today?.meals?.map(\.name), ["Pear"])
        XCTAssertEqual(context.today?.meals?.first?.portionGrams, 200)
        XCTAssertEqual(context.today?.consumedCalories, 104)
        XCTAssertEqual(model.foodEntry(id: edited.id)?.name, "Яблуко")
        model.closeTapped()
        XCTAssertEqual(try harness.food.fetchEntry(id: deleted.id), deleted)
        XCTAssertEqual(try harness.food.fetchEntry(id: edited.id), edited)
    }

    private func draftTestEntry(name: String, date: Date, meal: MealType = .breakfast) -> FoodEntry {
        FoodLogProposal(name: name, mealType: meal, calories: 52, protein: 0.3, carbs: 14, fats: 0.2,
                        portionGrams: 100).toFoodEntry(date: date)
    }

    func testUneatenDraftDoesNotCountAsConsumedCaloriesInAssistantContext() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        let date = Date()
        let entry = draftTestEntry(name: "Apple", date: date)
        try harness.food.save(entry)
        let model = makeViewModel(harness: harness, service: service, date: date)
        model.reload()
        model.commitPortion(id: entry.id, text: "200 g")
        model.updateInput("how much protein is in this meal?")
        model.sendTapped()
        await waitForCompletion(model)
        let context = try XCTUnwrap(service.requests.first?.userContext)
        XCTAssertEqual(context.today?.consumedCalories, 0)
        XCTAssertEqual(context.today?.meals?.first?.calories, 104)
        XCTAssertEqual(try harness.food.fetchEntry(id: entry.id), entry)
    }

    func testAskBityFromSearchReturnsToTheSameUnsavedMeal() async throws {
        let harness = TestHarness()
        let service = EditMealTestAssistant()
        service.response = assistantResponse(calls: [assistantCall("propose_food_log", arguments: catalogAppleArguments())])
        let model = makeViewModel(harness: harness, service: service)
        let editor = EditMealViewController(viewModel: model)
        let nav = UINavigationController(rootViewController: editor)
        nav.pushViewController(UIViewController(), animated: false)
        let coordinator = FoodLoggingCoordinator(navigationController: nav,
            container: DIContainer(coreDataStack: CoreDataStack(inMemory: true)))
        coordinator.openAskBity(query: "apple", navigationController: nav)
        await waitForCompletion(model)
        XCTAssertTrue(nav.topViewController === editor)
        XCTAssertEqual(service.messages, ["apple"])
        XCTAssertEqual(model.items.value.count, 1)
        XCTAssertTrue(try harness.food.fetchAll().isEmpty)
        model.closeTapped()
        XCTAssertTrue(try harness.food.fetchAll().isEmpty)
    }

    private func scrollToBottom(_ scroll: UIScrollView) {
        let bottom = max(-scroll.adjustedContentInset.top,
                         scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
        scroll.layoutIfNeeded()
    }

    private func makeViewModel(harness: TestHarness, service: EditMealTestAssistant, date: Date = Date()) -> EditMealViewModel {
        let fetch = FetchDailyDiaryUseCase(foodEntryRepository: harness.food, waterEntryRepository: harness.water,
                                          userGoalsRepository: harness.goals, workoutEntryRepository: harness.workout)
        return EditMealViewModel(
            mealType: .breakfast, date: date, fetchDailyDiaryUseCase: fetch,
            deleteFoodEntryUseCase: DeleteFoodEntryUseCase(foodEntryRepository: harness.food),
            updateFoodEntryUseCase: UpdateFoodEntryUseCase(foodEntryRepository: harness.food),
            scaleFoodPortionUseCase: ScaleFoodPortionUseCase(),
            logFoodUseCase: LogFoodUseCase(foodEntryRepository: harness.food),
            replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: harness.food),
            aiAssistantService: service,
            buildAIAssistantUserContextUseCase: BuildAIAssistantUserContextUseCase(
                fetchDailyDiaryUseCase: fetch, userProfileRepository: harness.profile, userPreferenceRepository: harness.preferences),
            parseAIAssistantActionsUseCase: ParseAIAssistantActionsUseCase(),
            voiceRecorder: EditMealTestRecorder(),
            transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase(voiceFoodTranscriptionService: VoiceFoodTranscriptionService())
        )
    }

    private func assistantResponse(content: String = "", calls: [AIAssistantToolCall] = []) -> AIAssistantChatResponse {
        AIAssistantChatResponse(mode: "chat", model: "test",
            message: AIAssistantChatMessage(role: "assistant", content: content, toolCalls: calls),
            hasActions: !calls.isEmpty, error: nil)
    }

    private func assistantCall(_ name: String, arguments: [String: Any]) -> AIAssistantToolCall {
        AIAssistantToolCall(id: UUID().uuidString, name: name, arguments: arguments.mapValues(AnyCodable.init))
    }

    private func catalogAppleArguments() -> [String: Any] {
        ["name": "Яблуко", "mealType": "dinner", "calories": 156, "protein": 0.9,
         "carbs": 42, "fats": 0.6, "portionGrams": 300, "catalogExternalId": "9003",
         "kind": "ingredient", "source": "spoonacular", "catalogSource": "spoonacular"]
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }

    private func waitForCompletion(_ viewModel: EditMealViewModel) async {
        for _ in 0..<100 where viewModel.isSending.value {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertFalse(viewModel.isSending.value)
    }
}

private final class EditMealTestAssistant: AIAssistantServiceProtocol {
    var messages: [String] = []
    var requests: [AIAssistantChatRequest] = []
    var response = AIAssistantChatResponse(mode: "chat", model: "test",
        message: AIAssistantChatMessage(role: "assistant", content: "ok", toolCalls: []), hasActions: false, error: nil)
    var error: Error?
    var onRequest: (() -> Void)?

    func chat(_ request: AIAssistantChatRequest) async throws -> AIAssistantChatResponse {
        messages.append(request.message)
        requests.append(request)
        onRequest?()
        if let error { throw error }
        return response
    }
}

private final class EditMealTestRecorder: VoiceFoodAudioRecording {
    var isRecording = false
    var onPartialTranscript: ((String) -> Void)?
    var onUtteranceFinal: (() -> Void)?
    func requestPermission() async -> Bool { false }
    func startRecording() throws {}
    func stopRecording() throws -> Data { Data() }
    func cancelRecording() {}
    func normalizedPower() -> CGFloat { 0 }
}
