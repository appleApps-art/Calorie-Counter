import UIKit
import XCTest
@testable import Calorie_Counter

@MainActor
final class AIAssistantChatTests: XCTestCase {
    func testSwapCardsStayEqualAndAboveApplyWithLongTextOnEitherSide() throws {
        let long = FoodSwapItem(name: String(repeating: "Гречка із зеленню та лимоном ", count: 6), calories: 160, protein: 5, carbs: 30, fats: 2, portionLabel: String(repeating: "45 г сухої гречки, 10 г петрушки ", count: 8), imageURL: nil)
        let short = FoodSwapItem(name: "Булгур", calories: 160, protein: 5, carbs: 30, fats: 2, portionLabel: "45 г", imageURL: nil)
        for width in [CGFloat(270), 322, 360] {
            for reversed in [false, true] {
                let card = AIChatSwapCardView()
                card.configure(FoodSwapProposal(original: reversed ? long : short, alternative: reversed ? short : long, savingsKcal: 0, savingsNote: "", applyToEntryId: nil))
                let size = card.systemLayoutSizeFitting(CGSize(width: width, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
                card.frame = CGRect(origin: .zero, size: size)
                card.layoutIfNeeded()
                let left = try XCTUnwrap(card.value(forKey: "originalCardView") as? UIView)
                let right = try XCTUnwrap(card.value(forKey: "alternativeCardView") as? UIView)
                let button = try XCTUnwrap(card.value(forKey: "applyButton") as? UIButton)
                XCTAssertEqual(left.frame.height, right.frame.height, accuracy: 0.5)
                XCTAssertEqual(left.frame.width, right.frame.width, accuracy: 0.5)
                XCTAssertGreaterThan(button.frame.minY, max(left.frame.maxY, right.frame.maxY))
                XCTAssertLessThanOrEqual(right.frame.maxX, right.superview!.bounds.width)
                for key in ["originalTitleLabel", "alternativeTitleLabel", "originalDetailLabel", "alternativeDetailLabel"] {
                    let label = try XCTUnwrap(card.value(forKey: key) as? UILabel)
                    XCTAssertEqual(label.numberOfLines, 2)
                    XCTAssertEqual(label.lineBreakMode, .byTruncatingTail)
                    XCTAssertLessThanOrEqual(label.frame.maxY, label.superview!.bounds.height)
                }
            }
        }
    }

    func testUserBubbleXibPinsBubbleToTrailing() throws {
        let xml = try String(contentsOf: featureURL("AIAssistant/AIChatUserBubbleView.xib"), encoding: .utf8)
        XCTAssertTrue(
            xml.contains("firstItem=\"root\" firstAttribute=\"trailing\" secondItem=\"bubble\" secondAttribute=\"trailing\"")
        )
        XCTAssertTrue(
            xml.contains("firstItem=\"bubble\" firstAttribute=\"leading\" relation=\"greaterThanOrEqual\" secondItem=\"root\"")
        )
        XCTAssertFalse(
            xml.contains("firstItem=\"bubble\" firstAttribute=\"leading\" secondItem=\"root\" secondAttribute=\"leading\"")
        )
        XCTAssertTrue(xml.contains("textAlignment=\"left\""))
    }

    func testUserBubbleSitsOnTrailingEdgeWithLeftAlignedText() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 370, height: 160))
        let row = AIChatUserBubbleView()
        row.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: host.topAnchor),
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            row.bottomAnchor.constraint(lessThanOrEqualTo: host.bottomAnchor)
        ])
        row.configure(text: "Hi", alignment: .left)
        host.layoutIfNeeded()

        let bubble = userBubble(in: row)
        let label = userLabel(in: row)
        XCTAssertEqual(bubble.frame.maxX, row.bounds.maxX, accuracy: 1)
        XCTAssertGreaterThan(bubble.frame.minX, 40)
        XCTAssertEqual(label.textAlignment, .left)
        XCTAssertEqual(label.frame.minX, .adaptWidth(16), accuracy: 2)
    }

    func testAttachMenuXibUsesFigmaHeightAndVerticalPadding() throws {
        let menuXML = try String(contentsOf: featureURL("AIAssistant/AIChatAttachMenuView.xib"), encoding: .utf8)
        XCTAssertTrue(menuXML.contains("width=\"238\" height=\"144\""))
        XCTAssertTrue(
            menuXML.contains("firstItem=\"stack\" firstAttribute=\"top\" secondItem=\"menu\" secondAttribute=\"top\" constant=\"12\"")
        )
        XCTAssertTrue(
            menuXML.contains("firstItem=\"menu\" firstAttribute=\"bottom\" secondItem=\"stack\" secondAttribute=\"bottom\" constant=\"12\"")
        )
        XCTAssertFalse(
            menuXML.contains("firstItem=\"stack\" firstAttribute=\"top\" secondItem=\"menu\" secondAttribute=\"top\" id=\"st\"")
        )

        let screenXML = try String(contentsOf: featureURL("AIAssistant/AIAssistantViewController.xib"), encoding: .utf8)
        XCTAssertTrue(screenXML.contains("firstItem=\"attach-menu\" firstAttribute=\"height\" constant=\"144\""))
        XCTAssertFalse(screenXML.contains("firstItem=\"attach-menu\" firstAttribute=\"height\" constant=\"120\""))
    }

    func testAttachMenuRowsHaveEqualIconSlotsAndVerticalPadding() {
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let menu = AIChatAttachMenuView()
        menu.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(menu)
        NSLayoutConstraint.activate([
            menu.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            menu.topAnchor.constraint(equalTo: host.topAnchor),
            menu.widthAnchor.constraint(equalToConstant: .adaptWidth(238)),
            menu.heightAnchor.constraint(equalToConstant: .adaptHeight(144))
        ])
        host.layoutIfNeeded()

        guard let stack = firstStack(in: menu), let glass = stack.superview else {
            return XCTFail("Attach menu stack is missing")
        }

        XCTAssertEqual(stack.frame.minY, .adaptHeight(12), accuracy: 1)
        XCTAssertEqual(glass.bounds.height - stack.frame.maxY, .adaptHeight(12), accuracy: 1)

        let buttons = stack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, 3)
        let imageWidths = buttons.map { $0.configuration?.image?.size.width ?? 0 }
        XCTAssertEqual(imageWidths[0], .adaptWidth(28), accuracy: 0.5)
        XCTAssertEqual(imageWidths[1], imageWidths[0], accuracy: 0.5)
        XCTAssertEqual(imageWidths[2], imageWidths[0], accuracy: 0.5)

        buttons.forEach { button in
            let insets = button.configuration?.contentInsets ?? .zero
            XCTAssertEqual(button.bounds.height, .adaptHeight(40), accuracy: 1)
            XCTAssertEqual(button.configuration?.imagePadding ?? -1, .adaptWidth(8), accuracy: 0.5)
            XCTAssertEqual(insets.top, .adaptHeight(10), accuracy: 0.5)
            XCTAssertEqual(insets.bottom, .adaptHeight(10), accuracy: 0.5)
            XCTAssertEqual(insets.leading, .adaptWidth(6), accuracy: 0.5)
        }

        let titleMinXs = buttons.compactMap { titleView(in: $0) }.map { title in
            title.convert(title.bounds, to: glass).minX
        }
        XCTAssertEqual(titleMinXs.count, 3)
        XCTAssertEqual(titleMinXs[1], titleMinXs[0], accuracy: 1)
        XCTAssertEqual(titleMinXs[2], titleMinXs[0], accuracy: 1)
    }

    func testNewChatSessionDoesNotRestoreStoredHistory() throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(
            chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack)
        )
        try persist.append(id: UUID(), role: "user", content: "порекомендуй вечерю")
        try persist.append(id: UUID(), role: "assistant", content: "Куряче філе")

        let tab = makeViewModel(harness: harness, persist: persist)
        XCTAssertEqual(displayedKinds(tab), [.assistant(L10n.tr("ai.chat.welcome"))])

        let ephemeral = makeViewModel(harness: harness, persist: nil)
        XCTAssertEqual(displayedKinds(ephemeral), [.assistant(L10n.tr("ai.chat.welcome"))])
    }

    func testTabSessionPersistsTurnsAndEphemeralDoesNot() async throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(
            chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack)
        )
        let tab = makeViewModel(harness: harness, persist: persist)
        tab.updateInput("hi")
        tab.sendTapped()
        await waitUntil { tab.isSending.value == false }
        let afterTab = try persist.loadAll()
        XCTAssertTrue(afterTab.contains { $0.role == "user" && $0.content == "hi" })

        let ephemeral = makeViewModel(harness: harness, persist: nil)
        ephemeral.updateInput("hi from search")
        ephemeral.sendTapped()
        await waitUntil { ephemeral.isSending.value == false }
        XCTAssertEqual(try persist.loadAll().count, afterTab.count)
        XCTAssertFalse(try persist.loadAll().contains { $0.content == "hi from search" })
        XCTAssertFalse(ephemeral.messages.value.contains { item in
            if case .user(let text) = item.kind { return text == "hi" }
            return false
        })
    }

    func testEphemeralChatIgnoresHistoryClearReset() async {
        let harness = TestHarness()
        let vm = makeViewModel(harness: harness, persist: nil)
        vm.updateInput("ask bity")
        vm.sendTapped()
        await waitUntil { vm.isSending.value == false }
        XCTAssertTrue(vm.messages.value.contains { item in
            if case .user(let text) = item.kind { return text == "ask bity" }
            return false
        })
        vm.resetIfHistoryCleared()
        XCTAssertTrue(vm.messages.value.contains { item in
            if case .user(let text) = item.kind { return text == "ask bity" }
            return false
        })
    }

    func testSelectingHistoryRestoresPersistedConversation() throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(
            chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack)
        )
        let userID = UUID()
        let assistantID = UUID()
        try persist.append(id: userID, role: "user", content: "порекомендуй вечерю")
        try persist.append(id: assistantID, role: "assistant", content: "Куряче філе")

        let tab = makeViewModel(harness: harness, persist: persist)
        XCTAssertEqual(displayedKinds(tab), [.assistant(L10n.tr("ai.chat.welcome"))])

        tab.restorePersistedConversation()
        XCTAssertEqual(tab.messages.value.map(\.kind), [
            .user("порекомендуй вечерю"),
            .assistant("Куряче філе")
        ])
        XCTAssertEqual(tab.messages.value.map(\.id), [userID, assistantID])

        let ephemeral = makeViewModel(harness: harness, persist: nil)
        ephemeral.restorePersistedConversation()
        XCTAssertEqual(displayedKinds(ephemeral), [.assistant(L10n.tr("ai.chat.welcome"))])
    }

    func testCoordinatorHidesHistoryOffTabBar() throws {
        let source = try String(contentsOf: featureURL("AIAssistant/AIAssistantCoordinator.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("isPersistentSession = isTabRoot && recipe == nil"))
        XCTAssertTrue(source.contains("chat.showsHistoryButton = isPersistentSession"))
        XCTAssertTrue(source.contains("isPersistentSession: isPersistentSession"))
        XCTAssertTrue(source.contains("chat.showsNewChatButton = isPersistentSession"))
        XCTAssertTrue(source.contains("persistentChat?.restorePersistedConversation(id: conversationID)"))
    }

    func testFactoryDefaultsToEphemeralSession() throws {
        let source = try String(contentsOf: appURL("DIContainer.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("isPersistentSession: Bool = false"))
        XCTAssertTrue(source.contains("persistChatHistoryUseCase: isPersistentSession ? persistChatHistoryUseCase : nil"))
    }

    func testChatHistoryPreviewCollapsesWhitespace() {
        let preview = ChatHistoryVisualCodec.preview(
            role: "assistant",
            content: "План харчування\n\nна тиждень.   Багато тексту."
        )
        XCTAssertEqual(preview, "План харчування на тиждень. Багато тексту.")
        XCTAssertEqual(
            ChatHistoryVisualCodec.collapsedListText("я маю яйця\nмолоко"),
            "я маю яйця молоко"
        )
    }

    func testChatHistoryRowUsesCollapsedTitleAndSingleLineTruncation() throws {
        let source = try String(contentsOf: featureURL("AIAssistant/ChatHistoryViewModel.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("ChatHistoryVisualCodec.collapsedListText(user.content)"))
        let rowSource = try String(contentsOf: featureURL("AIAssistant/ChatHistoryRowView.swift"), encoding: .utf8)
        XCTAssertTrue(rowSource.contains("titleLabel.applyLineTruncation(lines: 1)"))
        XCTAssertTrue(rowSource.contains("subtitleLabel.applyLineTruncation(lines: 1)"))
    }

    func testChatHistoryRowXibAllowsSingleLineText() throws {
        let xml = try String(contentsOf: featureURL("AIAssistant/ChatHistoryRowView.xib"), encoding: .utf8)
        XCTAssertFalse(xml.contains("firstAttribute=\"height\" constant=\"70\""))
        XCTAssertTrue(xml.contains("text=\"Title\" lineBreakMode=\"tailTruncation\" numberOfLines=\"1\""))
        XCTAssertTrue(xml.contains("text=\"Subtitle\" lineBreakMode=\"tailTruncation\" numberOfLines=\"1\""))
        XCTAssertTrue(xml.contains("firstItem=\"root\" firstAttribute=\"bottom\" relation=\"greaterThanOrEqual\" secondItem=\"subtitle\""))
    }

    func testChatHistoryRowClampsLongTextToSingleLines() {
        let row = ChatHistoryRowView(frame: .zero)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.configure(
            ChatHistoryRowItem(
                id: UUID(),
                title: String(
                    repeating: "я маю яйця, молоко, полуницю, банан, що мені приготувати на перекус? ",
                    count: 8
                ),
                subtitle: String(
                    repeating: "План харчування на тиждень з білком, овочами та десертами. ",
                    count: 20
                ),
                timeText: "15:09",
                date: Date(),
                category: nil
            ),
            showsSeparator: true
        )
        row.widthAnchor.constraint(equalToConstant: 338).isActive = true
        let size = row.systemLayoutSizeFitting(
            CGSize(width: 338, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        XCTAssertGreaterThan(size.height, 60)
        XCTAssertLessThan(size.height, 140)

        let labels = descendantLabels(in: row)
        XCTAssertEqual(labels.filter { $0.numberOfLines == 1 }.count, 3)
        labels.forEach { label in
            XCTAssertFalse(label.adjustsFontSizeToFitWidth)
            XCTAssertEqual(label.minimumScaleFactor, 1)
            XCTAssertGreaterThanOrEqual(label.font.pointSize, 13)
        }
    }

    func testMealIdeasChipReturnsRecipeCardWithoutTextAndPersistsIt() async throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(
            chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack)
        )
        let service = StubAIAssistantService(response: try decodedResponse(toolCalls: [
            ["id": "meal-1", "name": "propose_meal_suggestions", "arguments": [
                "mealType": "dinner",
                "options": [[
                    "title": "Омлет з овочами", "summary": "Швидка вечеря",
                    "calories": 320, "protein": 24, "carbs": 12, "fats": 19,
                    "ingredients": ["2 яйця", "150 г овочів"],
                    "steps": ["Збийте яйця та обсмажте з овочами."]
                ]]
            ]]
        ]))
        let vm = makeViewModel(harness: harness, persist: persist, service: service)

        vm.selectCategory(.meals)
        await waitUntil { !vm.isSending.value }

        guard case .recipe(let recipe, let mealType) = vm.messages.value.last?.kind else {
            return XCTFail("An action-only meal response must show the existing recipe card")
        }
        XCTAssertEqual(recipe.title, "Омлет з овочами")
        XCTAssertEqual(recipe.calories, 320)
        XCTAssertEqual(mealType, .dinner)
        XCTAssertEqual(vm.pendingActions.value.count, 1)
        XCTAssertEqual(service.requests.first?.intent, .mealSuggestions)
        let encodedRequest = try JSONEncoder().encode(XCTUnwrap(service.requests.first))
        let requestJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: encodedRequest) as? [String: Any])
        XCTAssertEqual(requestJSON["intent"] as? String, "mealSuggestions")
        XCTAssertFalse(displayedKinds(vm).contains(.assistant(L10n.tr("ai.noText"))))
        XCTAssertTrue(try harness.food.fetchEntries(for: Date()).isEmpty)

        let restored = makeViewModel(harness: harness, persist: persist)
        restored.restorePersistedConversation()
        XCTAssertEqual(restored.messages.value.last?.kind, vm.messages.value.last?.kind)
    }

    func testRecipeCardShowsLocalizedMealTypeAboveTitleInLightAndDarkMode() throws {
        let option = MealSuggestionOption(
            title: "Омлет з овочами",
            summary: "Швидка та поживна страва",
            calories: 320, protein: 24, carbs: 12, fats: 19,
            cookTimeMinutes: 15, externalRecipeId: nil, ingredients: []
        )
        for appearance in [UIUserInterfaceStyle.light, .dark] {
            for mealType in MealType.allCases {
                let card = AIChatRecipeCardView()
                card.translatesAutoresizingMaskIntoConstraints = false
                card.widthAnchor.constraint(equalToConstant: 300).isActive = true
                card.overrideUserInterfaceStyle = appearance
                card.configure(option, mealType: mealType)
                let fitted = card.systemLayoutSizeFitting(
                    CGSize(width: 300, height: UIView.layoutFittingCompressedSize.height),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                )
                card.frame = CGRect(origin: .zero, size: fitted)
                card.layoutIfNeeded()
                let labels = descendantLabels(in: card)
                let mealLabel = try XCTUnwrap(labels.first {
                    $0.accessibilityIdentifier == "ai.chat.recipe.mealType"
                })
                let titleLabel = try XCTUnwrap(labels.first { $0.text == option.title })
                let mealFrame = mealLabel.convert(mealLabel.bounds, to: card)
                let titleFrame = titleLabel.convert(titleLabel.bounds, to: card)

                XCTAssertEqual(mealLabel.text, mealType.localizedTitle)
                XCTAssertFalse(mealLabel.isHidden)
                XCTAssertGreaterThan(mealFrame.height, 10)
                XCTAssertGreaterThanOrEqual(titleFrame.minY - mealFrame.maxY, 3)
                XCTAssertEqual(mealFrame.minX, titleFrame.minX, accuracy: 0.5)
                XCTAssertLessThanOrEqual(mealFrame.maxX, card.bounds.maxX)
                let traits = UITraitCollection(userInterfaceStyle: appearance)
                XCTAssertEqual(
                    mealLabel.textColor.resolvedColor(with: traits),
                    AppColor.labelsSecondary.resolvedColor(with: traits)
                )
                XCTAssertFalse(mealLabel.adjustsFontSizeToFitWidth)
            }
        }
    }

    func testMultiMealSuggestionsPreserveMealTypesWhenRestoredAndLogged() async throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(
            chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack)
        )
        let vm = makeViewModel(
            harness: harness,
            persist: persist,
            service: StubAIAssistantService(response: try multiMealResponse())
        )
        vm.updateInput("Запропонуй страви на сніданок, обід, перекус і вечерю")
        vm.sendTapped()
        await waitUntil { !vm.isSending.value }
        let expectedTypes: [MealType] = [.breakfast, .lunch, .snacks, .dinner]
        let proposed = vm.messages.value.compactMap { item -> (MealSuggestionOption, MealType)? in
            guard case .recipe(let option, let mealType) = item.kind else { return nil }
            return (option, mealType)
        }
        XCTAssertEqual(proposed.map { $0.1 }, expectedTypes)

        let restored = makeViewModel(harness: harness, persist: persist, confirm: confirmation(harness: harness))
        restored.restorePersistedConversation()
        XCTAssertEqual(restored.messages.value.map(\.kind), vm.messages.value.dropFirst().map(\.kind))
        for (index, item) in proposed.enumerated() {
            restored.logRecipe(item.0, mealType: item.1)
            let remainingTypes = restored.messages.value.compactMap { item -> MealType? in
                guard case .recipe(_, let mealType) = item.kind else { return nil }
                return mealType
            }
            XCTAssertEqual(remainingTypes, Array(expectedTypes.dropFirst(index + 1)))
        }
        let entries = try harness.food.fetchEntries(for: Date())
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(Set(entries.map(\.mealType)), Set(expectedTypes))
        let loggedTypes = restored.messages.value.compactMap { item -> MealType? in
            guard case .loggedMeal(_, let proposal) = item.kind else { return nil }
            return proposal.mealType
        }
        XCTAssertEqual(loggedTypes, expectedTypes)
    }

    func testConfirmingMultiMealOptionsUsesTheirMealTypesAndKeepsOtherMealsPending() async throws {
        let harness = TestHarness()
        let vm = makeViewModel(
            harness: harness,
            persist: nil,
            service: StubAIAssistantService(response: try multiMealResponse()),
            confirm: confirmation(harness: harness)
        )
        vm.selectCategory(.meals)
        await waitUntil { !vm.isSending.value }

        for remaining in (1...4).reversed() {
            guard case .mealSuggestions(let proposal) = vm.pendingActions.value.first else {
                return XCTFail("Other meal suggestions must remain pending")
            }
            XCTAssertEqual(proposal.options.count, remaining)
            vm.confirmMealSuggestion(at: 0, optionIndex: 0)
        }
        XCTAssertTrue(vm.pendingActions.value.isEmpty)
        let entries = try harness.food.fetchEntries(for: Date())
        XCTAssertEqual(entries.count, 4)
        XCTAssertEqual(Set(entries.map(\.mealType)), Set(MealType.allCases))
    }

    func testActionOnlySwapRendersCardAndRetainsOriginalForMoreOptions() async throws {
        let harness = TestHarness()
        let service = StubAIAssistantService(response: try decodedResponse(toolCalls: [
            ["id": "swap-1", "name": "propose_food_swap", "arguments": [
                "original": ["name": "Картопляні чипси", "calories": 270],
                "alternative": ["name": "Попкорн", "calories": 110],
                "savingsKcal": 160
            ]]
        ]))
        let vm = makeViewModel(harness: harness, persist: nil, service: service)
        vm.updateInput("Чим замінити картопляні чипси?")
        vm.sendTapped()
        await waitUntil { !vm.isSending.value }

        guard case .swap(let proposal) = vm.messages.value.last?.kind else {
            return XCTFail("An action-only swap response must show the existing food swap card")
        }
        XCTAssertEqual(proposal.original.name, "Картопляні чипси")
        XCTAssertEqual(proposal.alternative.name, "Попкорн")
        XCTAssertTrue(try harness.food.fetchEntries(for: Date()).isEmpty)

        vm.seeMoreSwapOptions()
        await waitUntil { !vm.isSending.value }
        let followup = try XCTUnwrap(service.requests.last)
        XCTAssertEqual(followup.intent, .foodSwap)
        let assistantHistory = try XCTUnwrap(followup.history.last { $0.role == "assistant" })
        XCTAssertTrue(assistantHistory.content.contains("Картопляні чипси"))
        XCTAssertTrue(assistantHistory.content.contains("Попкорн"))
        XCTAssertTrue(assistantHistory.content.contains("not applied"))
    }

    func testActionOnlyFoodLogSavesEntryAndDisplaysLoggedMealCard() async throws {
        let harness = TestHarness()
        let service = StubAIAssistantService(response: try decodedResponse(toolCalls: [
            ["id": "log-1", "name": "propose_food_log", "arguments": [
                "name": "Вівсянка", "mealType": "breakfast", "calories": 300,
                "protein": 12, "carbs": 42, "fats": 8, "portionGrams": 250
            ]]
        ]))
        let vm = makeViewModel(
            harness: harness,
            persist: nil,
            service: service,
            confirm: ConfirmAIAssistantActionUseCase(
                logFoodUseCase: harness.logFood(),
                replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: harness.food),
                logWaterUseCase: harness.logWater(),
                saveUserPreferenceUseCase: SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences),
                recipeRepository: harness.recipes,
                foodEntryRepository: harness.food
            )
        )
        vm.updateInput("Запиши 250 г вівсянки на сніданок")
        vm.sendTapped()
        await waitUntil { !vm.isSending.value }

        guard case .loggedMeal(let entryID, let proposal) = vm.messages.value.last?.kind else {
            return XCTFail("A food log response must show the existing logged meal card")
        }
        let saved = try XCTUnwrap(harness.food.fetchEntries(for: Date()).first)
        XCTAssertEqual(entryID, saved.id)
        XCTAssertEqual(saved.name, "Вівсянка")
        XCTAssertEqual(proposal.calories, 300)
        XCTAssertTrue(vm.pendingActions.value.isEmpty)
    }

    func testClarificationKeepsSwapIntentForShortFollowupWithoutLoggingFood() async throws {
        let harness = TestHarness()
        let question = "Який продукт ви хочете замінити?"
        let service = StubAIAssistantService(response: try decodedResponse(content: question))
        let vm = makeViewModel(harness: harness, persist: nil, service: service)
        vm.selectCategory(.swaps)
        await waitUntil { !vm.isSending.value }
        XCTAssertEqual(vm.messages.value.last?.kind, .assistant(question))
        XCTAssertTrue(vm.pendingActions.value.isEmpty)
        XCTAssertTrue(try harness.food.fetchEntries(for: Date()).isEmpty)

        vm.updateInput("Чипси")
        vm.sendTapped()
        await waitUntil { !vm.isSending.value }
        XCTAssertEqual(service.requests.last?.intent, .foodSwap)
        XCTAssertEqual(service.requests.last?.history.last?.content, question)
    }

    func testFailedFoodSaveDoesNotClaimMealWasLogged() async throws {
        let harness = TestHarness()
        let service = StubAIAssistantService(response: try decodedResponse(toolCalls: [
            ["id": "log-1", "name": "propose_food_log", "arguments": [
                "name": "Вівсянка", "mealType": "breakfast", "calories": 300
            ]]
        ]))
        for confirm in [nil, failingConfirmation(harness: harness)] {
            let vm = makeViewModel(harness: harness, persist: nil, service: service, confirm: confirm)
            vm.updateInput("Запиши вівсянку на сніданок")
            vm.sendTapped()
            await waitUntil { !vm.isSending.value }

            XCTAssertFalse(vm.messages.value.contains {
                if case .loggedMeal = $0.kind { return true }
                return false
            })
            let failures = vm.messages.value.filter {
                if case .system = $0.kind { return true }
                return false
            }
            XCTAssertEqual(failures.count, 1)
            XCTAssertEqual(vm.pendingActions.value.count, 1)
            XCTAssertTrue(try harness.food.fetchEntries(for: Date()).isEmpty)
        }
    }

    func testRecipeAndSwapCardsRemainAvailableWhenTheirSaveFails() async throws {
        let harness = TestHarness()
        let service = StubAIAssistantService(response: try decodedResponse(toolCalls: [
            ["id": "meal-1", "name": "propose_meal_suggestions", "arguments": [
                "mealType": "dinner", "options": [["title": "Омлет", "calories": 300]]
            ]],
            ["id": "swap-1", "name": "propose_food_swap", "arguments": [
                "original": ["name": "Чипси", "calories": 270],
                "alternative": ["name": "Попкорн", "calories": 110]
            ]]
        ]))
        for confirm in [nil, failingConfirmation(harness: harness)] {
            let vm = makeViewModel(harness: harness, persist: nil, service: service, confirm: confirm)
            vm.updateInput("Порадь вечерю та заміну чипсів")
            vm.sendTapped()
            await waitUntil { !vm.isSending.value }
            let recipeItem = try XCTUnwrap(vm.messages.value.first {
                if case .recipe = $0.kind { return true }
                return false
            })
            let swapItem = try XCTUnwrap(vm.messages.value.first {
                if case .swap = $0.kind { return true }
                return false
            })
            guard case .recipe(let option, let mealType) = recipeItem.kind,
                  case .swap(let proposal) = swapItem.kind else {
                return XCTFail("Expected meal and swap proposals")
            }

            vm.logRecipe(option, mealType: mealType)
            vm.applySwap(proposal)

            XCTAssertTrue(vm.messages.value.contains(recipeItem))
            XCTAssertTrue(vm.messages.value.contains(swapItem))
            XCTAssertFalse(vm.messages.value.contains {
                if case .loggedMeal = $0.kind { return true }
                return false
            })
            XCTAssertEqual(vm.pendingActions.value.count, 2)
            XCTAssertTrue(try harness.food.fetchEntries(for: Date()).isEmpty)
        }
    }

    func testEmptyOrUnusableResponsesShowRetryErrorInsteadOfNoTextBubble() async throws {
        let invalidCalls: [[[String: Any]]] = [
            [],
            [["id": "unknown-1", "name": "unknown_action", "arguments": [:]]],
            [["id": "meal-1", "name": "propose_meal_suggestions", "arguments": ["options": []]]]
        ]
        for calls in invalidCalls {
            let harness = TestHarness()
            let service = StubAIAssistantService(response: try decodedResponse(toolCalls: calls))
            let vm = makeViewModel(harness: harness, persist: nil, service: service)
            vm.selectCategory(.meals)
            await waitUntil { !vm.isSending.value }

            XCTAssertEqual(
                vm.messages.value.last?.kind,
                .system(L10n.format("ai.errorPrefix", L10n.tr("ai.error.emptyResponse")))
            )
            XCTAssertEqual(vm.statusText.value, L10n.tr("ai.failed"))
            XCTAssertTrue(vm.pendingActions.value.isEmpty)
            XCTAssertFalse(displayedKinds(vm).contains(.assistant(L10n.tr("ai.noText"))))
            XCTAssertFalse(displayedKinds(vm).contains(.typing))
        }
    }

    func testSavingRecipeAndSwapUpdatesContextForTheNextRequest() async throws {
        let harness = TestHarness()
        let service = StubAIAssistantService(response: try decodedResponse(toolCalls: [
            ["id": "meal-1", "name": "propose_meal_suggestions", "arguments": [
                "mealType": "dinner", "options": [["title": "Омлет", "calories": 300]]
            ]],
            ["id": "swap-1", "name": "propose_food_swap", "arguments": [
                "original": ["name": "Чипси", "calories": 270],
                "alternative": ["name": "Попкорн", "calories": 110]
            ]]
        ]))
        let vm = makeViewModel(
            harness: harness,
            persist: nil,
            service: service,
            confirm: ConfirmAIAssistantActionUseCase(
                logFoodUseCase: harness.logFood(),
                replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: harness.food),
                logWaterUseCase: harness.logWater(),
                saveUserPreferenceUseCase: SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences),
                recipeRepository: harness.recipes,
                foodEntryRepository: harness.food
            )
        )
        vm.updateInput("Порадь вечерю та заміну чипсів")
        vm.sendTapped()
        await waitUntil { !vm.isSending.value }
        for item in vm.messages.value {
            switch item.kind {
            case .recipe(let option, let mealType): vm.logRecipe(option, mealType: mealType)
            case .swap(let proposal): vm.applySwap(proposal)
            default: break
            }
        }
        let saved = try harness.food.fetchEntries(for: Date())
        XCTAssertEqual(saved.count, 2)

        vm.updateInput("Що я вже записав?")
        vm.sendTapped()
        await waitUntil { !vm.isSending.value }
        let history = try XCTUnwrap(service.requests.last).history
        let loggedHistory = history.filter { $0.content.hasPrefix("Logged meal:") }
        XCTAssertEqual(loggedHistory.count, 2)
        for entry in saved {
            XCTAssertTrue(loggedHistory.contains {
                $0.content.contains(entry.id.uuidString) && $0.content.contains(entry.name)
            })
        }
    }

    func testSendButtonDoesNotTriggerBackgroundKeyboardDismissal() throws {
        let controller = AIAssistantViewController(viewModel: makeViewModel(harness: TestHarness(), persist: nil))
        controller.loadViewIfNeeded()
        let button = try XCTUnwrap(controller.keyboardDismissExcludedViews.first as? UIButton)
        let binder = try XCTUnwrap(controller.view.gestureRecognizers?.compactMap {
            $0.delegate as? KeyboardDismissBinder
        }.first)
        let icon = UIImageView()
        button.addSubview(icon)
        XCTAssertFalse(binder.shouldDismissKeyboard(for: button))
        XCTAssertFalse(binder.shouldDismissKeyboard(for: icon))
        XCTAssertTrue(binder.shouldDismissKeyboard(for: controller.view))
    }

    func testFirstSendTapSubmitsCurrentDraftAndDismissesKeyboard() async throws {
        let service = StubAIAssistantService()
        let vm = makeViewModel(harness: TestHarness(), persist: nil, service: service)
        let controller = AIAssistantViewController(viewModel: vm)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        let field = try XCTUnwrap(controller.value(forKey: "inputField") as? UITextView)
        let button = try XCTUnwrap(controller.keyboardDismissExcludedViews.first as? UIButton)
        // No editingChanged event: sending must capture the current field value.
        field.text = "Порадь страву на вечерю"
        XCTAssertTrue(field.becomeFirstResponder())
        button.sendActions(for: .touchUpInside)
        XCTAssertTrue(vm.isSending.value)
        XCTAssertFalse(field.isFirstResponder)
        XCTAssertEqual(field.text, "")
        button.sendActions(for: .touchUpInside)
        await waitUntil { !vm.isSending.value }
        XCTAssertEqual(service.requests.map(\.message), ["Порадь страву на вечерю"])
    }

    func testMicrophoneRemovesListeningWavesAfterConfirmAndSend() {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
        let chrome = VoiceMicButtonChrome()
        chrome.attach(button)
        chrome.apply(isRecording: true, canConfirm: false)
        let waves = button.subviews.filter { $0.layer.borderWidth == 1.5 }
        XCTAssertEqual(waves.count, 2)
        chrome.apply(isRecording: false, canConfirm: true)
        XCTAssertTrue(waves.allSatisfy { $0.superview == nil && $0.layer.animationKeys() == nil })
        chrome.apply(isRecording: false, canConfirm: false)
        XCTAssertEqual(button.backgroundColor, .clear)
        XCTAssertTrue(button.subviews.filter { $0.layer.borderWidth == 1.5 }.isEmpty)
        XCTAssertEqual(button.transform, .identity)
    }

    func testComposerGrowsToFourLinesThenScrollsAndShrinksAfterClear() throws {
        let vm = makeViewModel(harness: TestHarness(), persist: nil)
        let controller = AIAssistantViewController(viewModel: vm)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.layoutIfNeeded()
        let field = try XCTUnwrap(controller.value(forKey: "inputField") as? UITextView)
        let surface = try XCTUnwrap(controller.value(forKey: "composerField") as? AdaptiveView)
        XCTAssertEqual(surface.bounds.height, 48, accuracy: 1)
        XCTAssertEqual(field.frame.midY, surface.bounds.midY, accuracy: 0.5)
        let placeholder = try XCTUnwrap(field.subviews.compactMap { $0 as? UILabel }.first)
        XCTAssertEqual(placeholder.frame.midY, field.bounds.midY, accuracy: 0.5)
        vm.updateInput("Привіт")
        controller.view.layoutIfNeeded()
        XCTAssertEqual(field.frame.midY, surface.bounds.midY, accuracy: 0.5)
        XCTAssertEqual(field.bounds.height, ceil(field.font!.lineHeight), accuracy: 1)
        vm.updateInput("Один\nДва\nТри\nЧотири\nПʼять\nШість")
        controller.view.layoutIfNeeded()
        XCTAssertTrue(field.isScrollEnabled)
        XCTAssertEqual(surface.bounds.height, ceil(field.font!.lineHeight * 4) + 20, accuracy: 1)
        XCTAssertFalse(surface.applyButtonGlass)
        vm.updateInput("")
        controller.view.layoutIfNeeded()
        XCTAssertFalse(field.isScrollEnabled)
        XCTAssertEqual(surface.bounds.height, 48, accuracy: 1)
    }

    func testComposerKeepsNewlinesUntilSendButtonIsTapped() async throws {
        let service = StubAIAssistantService()
        let vm = makeViewModel(harness: TestHarness(), persist: nil, service: service)
        let controller = AIAssistantViewController(viewModel: vm)
        controller.loadViewIfNeeded()
        let field = try XCTUnwrap(controller.value(forKey: "inputField") as? UITextView)
        field.text = "Чим замінити майонез?"
        field.text += "\nБез молока"
        controller.textViewDidChange(field)
        XCTAssertFalse(vm.isSending.value)
        XCTAssertEqual(field.returnKeyType, .default)
        let button = try XCTUnwrap(controller.keyboardDismissExcludedViews.first as? UIButton)
        button.sendActions(for: .touchUpInside)
        await waitUntil { !vm.isSending.value }
        XCTAssertEqual(service.requests.map(\.message), ["Чим замінити майонез?\nБез молока"])
    }

    func testMultipleTurnsStayInOneConversationAndNewChatStartsIsolatedHistory() async throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack))
        let service = StubAIAssistantService()
        let vm = makeViewModel(harness: harness, persist: persist, service: service)
        let firstID = vm.currentConversationID
        for text in ["Порадь сніданок", "Без молока"] {
            vm.updateInput(text)
            vm.sendTapped()
            await waitUntil { !vm.isSending.value }
        }
        XCTAssertEqual(try persist.conversations().count, 1)
        XCTAssertEqual(try persist.loadConversation(id: firstID).count, 4)
        XCTAssertEqual(service.requests.last?.history.filter { $0.role == "user" }.map(\.content), ["Порадь сніданок"])

        vm.updateInput("Ненадіслана чернетка")
        vm.startNewConversation()
        let secondID = vm.currentConversationID
        XCTAssertNotEqual(secondID, firstID)
        XCTAssertEqual(vm.inputText.value, "")
        XCTAssertEqual(displayedKinds(vm), [.assistant(L10n.tr("ai.chat.welcome"))])
        XCTAssertEqual(try persist.conversations().count, 1)
        XCTAssertTrue(try persist.loadConversation(id: secondID).isEmpty)

        vm.updateInput("Порадь вечерю")
        vm.sendTapped()
        await waitUntil { !vm.isSending.value }
        XCTAssertEqual(service.requests.last?.history, [])
        XCTAssertEqual(try persist.conversations().count, 2)
        XCTAssertEqual(try persist.loadConversation(id: firstID).count, 4)
        XCTAssertEqual(try persist.loadConversation(id: secondID).count, 2)
    }

    func testOpeningSelectedOlderConversationAppendsToItWithoutMixingOtherChats() async throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack))
        let oldID = UUID()
        let newerID = UUID()
        try persist.append(role: "user", content: "Мій старий сніданок", conversationID: oldID)
        try persist.append(role: "assistant", content: "Вівсянка", conversationID: oldID)
        try persist.append(role: "user", content: "Інша розмова про вечерю", conversationID: newerID)
        let service = StubAIAssistantService()
        let vm = makeViewModel(harness: harness, persist: persist, service: service)
        XCTAssertEqual(displayedKinds(vm), [.assistant(L10n.tr("ai.chat.welcome"))])

        vm.restorePersistedConversation(id: oldID)
        XCTAssertEqual(vm.currentConversationID, oldID)
        XCTAssertEqual(displayedKinds(vm), [.user("Мій старий сніданок"), .assistant("Вівсянка")])
        vm.updateInput("Додай ягоди")
        vm.sendTapped()
        await waitUntil { !vm.isSending.value }

        XCTAssertEqual(service.requests.last?.history.map(\.content), ["Мій старий сніданок", "Вівсянка"])
        XCTAssertEqual(try persist.loadConversation(id: oldID).count, 4)
        XCTAssertEqual(try persist.loadConversation(id: newerID).map(\.content), ["Інша розмова про вечерю"])
        XCTAssertEqual(try persist.conversations().count, 2)
    }

    func testRestoringWholeConversationDisplaysMoreThanTwentyMessagesButLimitsAPIContext() async throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack))
        let conversationID = UUID()
        var messageIDs: [UUID] = []
        for index in 0..<36 {
            let id = UUID()
            messageIDs.append(id)
            try persist.append(
                id: id,
                role: index.isMultiple(of: 2) ? "user" : "assistant",
                content: "Повідомлення \(index)",
                conversationID: conversationID
            )
        }
        try persist.append(role: "user", content: "Стороння розмова", conversationID: UUID())
        let service = StubAIAssistantService()
        let vm = makeViewModel(harness: harness, persist: persist, service: service)
        vm.restorePersistedConversation(id: conversationID)
        XCTAssertEqual(vm.messages.value.map(\.id), messageIDs)
        vm.updateInput("Продовжимо")
        vm.sendTapped()
        await waitUntil { !vm.isSending.value }
        let request = try XCTUnwrap(service.requests.last)
        XCTAssertEqual(request.history.count, 20)
        XCTAssertEqual(request.history.first?.content, "Повідомлення 16")
        XCTAssertEqual(request.history.last?.content, "Повідомлення 35")
        XCTAssertFalse(request.history.contains { $0.content == "Стороння розмова" })
        XCTAssertEqual(try persist.loadConversation(id: conversationID).count, 38)
    }

    func testSentMessagePersistsImmediatelyAndSessionButtonsWaitForResponse() async throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack))
        let otherID = UUID()
        try persist.append(role: "user", content: "Інший чат", conversationID: otherID)
        let vm = makeViewModel(harness: harness, persist: persist)
        let controller = AIAssistantViewController(viewModel: vm)
        controller.showsNewChatButton = true
        controller.showsBackButton = false
        controller.loadViewIfNeeded()
        let newChat = try XCTUnwrap(controller.value(forKey: "backButton") as? UIButton)
        let history = try XCTUnwrap(controller.value(forKey: "historyButton") as? UIButton)
        XCTAssertEqual(newChat.accessibilityLabel, L10n.tr("ai.chat.newChat"))
        XCTAssertFalse(newChat.isHidden)
        let conversationID = vm.currentConversationID
        var historyRequests = 0
        controller.onHistory = { historyRequests += 1 }
        vm.updateInput("Не загуби це повідомлення")
        vm.sendTapped()

        XCTAssertEqual(try persist.loadConversation(id: conversationID).map(\.content), ["Не загуби це повідомлення"])
        XCTAssertFalse(newChat.isEnabled)
        XCTAssertFalse(history.isEnabled)
        newChat.sendActions(for: .touchUpInside)
        history.sendActions(for: .touchUpInside)
        vm.startNewConversation()
        controller.restorePersistedConversation(id: otherID)
        XCTAssertEqual(vm.currentConversationID, conversationID)
        XCTAssertEqual(historyRequests, 0)

        await waitUntil { !vm.isSending.value }
        XCTAssertTrue(newChat.isEnabled)
        XCTAssertTrue(history.isEnabled)
        XCTAssertEqual(try persist.loadConversation(id: conversationID).count, 2)
        newChat.sendActions(for: .touchUpInside)
        XCTAssertNotEqual(vm.currentConversationID, conversationID)
        XCTAssertEqual(try persist.conversations().count, 2)
    }

    func testNewConversationClearsPendingActionsAndPreservesSavedChat() async throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack))
        let service = StubAIAssistantService(response: try decodedResponse(toolCalls: [
            ["id": "water", "name": "propose_water_log", "arguments": ["amountMilliliters": 250]]
        ]))
        let vm = makeViewModel(harness: harness, persist: persist, service: service)
        vm.selectCategory(.nutrition)
        await waitUntil { !vm.isSending.value }
        let oldID = vm.currentConversationID
        XCTAssertNotNil(vm.pendingWaterConfirmText.value)
        XCTAssertFalse(vm.pendingActions.value.isEmpty)
        vm.updateInput("Чернетка")
        vm.startNewConversation()
        XCTAssertTrue(vm.pendingActions.value.isEmpty)
        XCTAssertNil(vm.pendingWaterConfirmText.value)
        XCTAssertNil(vm.selectedCategory.value)
        XCTAssertEqual(vm.inputText.value, "")
        XCTAssertEqual(vm.statusText.value, "")
        XCTAssertEqual(try persist.conversations().map(\.id), [oldID])

        let relaunched = makeViewModel(harness: harness, persist: persist)
        XCTAssertNotEqual(relaunched.currentConversationID, oldID)
        XCTAssertEqual(displayedKinds(relaunched), [.assistant(L10n.tr("ai.chat.welcome"))])
    }

    func testResumingLegacyHistoryKeepsNewMessagesInTheLegacyConversation() async throws {
        let harness = TestHarness()
        let persist = PersistChatHistoryUseCase(chatHistoryRepository: ChatHistoryRepository(coreDataStack: harness.stack))
        try persist.append(role: "user", content: "Старе повідомлення без ID розмови")
        let vm = makeViewModel(harness: harness, persist: persist)
        vm.restorePersistedConversation(id: ChatConversation.legacyID)
        vm.updateInput("Продовження")
        vm.sendTapped()
        await waitUntil { !vm.isSending.value }
        XCTAssertEqual(vm.currentConversationID, ChatConversation.legacyID)
        XCTAssertEqual(try persist.conversations().count, 1)
        XCTAssertEqual(try persist.loadConversation(id: ChatConversation.legacyID).count, 3)
    }

    private func decodedResponse(
        content: String? = nil,
        toolCalls: [[String: Any]] = []
    ) throws -> AIAssistantChatResponse {
        let payload: [String: Any] = [
            "mode": "chat", "model": "test",
            "message": [
                "role": "assistant",
                "content": content as Any? ?? NSNull(),
                "toolCalls": toolCalls
            ],
            "hasActions": !toolCalls.isEmpty
        ]
        return try JSONDecoder().decode(
            AIAssistantChatResponse.self,
            from: JSONSerialization.data(withJSONObject: payload)
        )
    }

    private func multiMealResponse() throws -> AIAssistantChatResponse {
        let mealTypes: [MealType] = [.breakfast, .lunch, .snacks, .dinner]
        let options: [[String: Any]] = mealTypes.map { mealType in
            [
                "title": "Рис з овочами", "summary": "Страва на день",
                "mealType": mealType.rawValue,
                "calories": 350, "protein": 12, "carbs": 60, "fats": 9
            ]
        }
        return try decodedResponse(toolCalls: [
            ["id": "meal-plan", "name": "propose_meal_suggestions", "arguments": [
                "mealType": "dinner", "options": options
            ]]
        ])
    }

    private func confirmation(harness: TestHarness) -> ConfirmAIAssistantActionUseCase {
        ConfirmAIAssistantActionUseCase(
            logFoodUseCase: harness.logFood(),
            replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: harness.food),
            logWaterUseCase: harness.logWater(),
            saveUserPreferenceUseCase: SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences),
            recipeRepository: harness.recipes,
            foodEntryRepository: harness.food
        )
    }

    private func failingConfirmation(harness: TestHarness) -> ConfirmAIAssistantActionUseCase {
        let repository = FailingAssistantFoodRepository()
        return ConfirmAIAssistantActionUseCase(
            logFoodUseCase: LogFoodUseCase(foodEntryRepository: repository),
            replaceFoodEntryUseCase: ReplaceFoodEntryUseCase(foodEntryRepository: repository),
            logWaterUseCase: harness.logWater(),
            saveUserPreferenceUseCase: SaveUserPreferenceUseCase(userPreferenceRepository: harness.preferences),
            recipeRepository: harness.recipes,
            foodEntryRepository: repository
        )
    }

    private func makeViewModel(
        harness: TestHarness,
        persist: PersistChatHistoryUseCase?,
        service: AIAssistantServiceProtocol? = nil,
        confirm: ConfirmAIAssistantActionUseCase? = nil
    ) -> AIAssistantViewModel {
        AIAssistantViewModel(
            aiAssistantService: service ?? StubAIAssistantService(),
            fetchDailyDiaryUseCase: FetchDailyDiaryUseCase(
                foodEntryRepository: harness.food,
                waterEntryRepository: harness.water,
                userGoalsRepository: harness.goals,
                workoutEntryRepository: harness.workout
            ),
            confirmAIAssistantActionUseCase: confirm,
            persistChatHistoryUseCase: persist
        )
    }

    private func displayedKinds(_ viewModel: AIAssistantViewModel) -> [AIChatItem.Kind] {
        viewModel.messages.value.map(\.kind)
    }

    private func userBubble(in view: UIView) -> UIView {
        let bubble = view.subviews
            .flatMap(\.subviews)
            .compactMap { $0 as? AdaptiveView }
            .first
        XCTAssertNotNil(bubble)
        return bubble ?? view
    }

    private func userLabel(in view: UIView) -> UILabel {
        let label = view.subviews
            .flatMap(\.subviews)
            .flatMap(\.subviews)
            .compactMap { $0 as? AdaptiveLabel }
            .first
        XCTAssertNotNil(label)
        return label ?? UILabel()
    }

    private func descendantLabels(in view: UIView) -> [UILabel] {
        view.subviews.flatMap { subview -> [UILabel] in
            let nested = descendantLabels(in: subview)
            if let label = subview as? UILabel {
                return [label] + nested
            }
            return nested
        }
    }

    private func firstStack(in view: UIView) -> UIStackView? {
        if let stack = view as? UIStackView {
            return stack
        }
        for subview in view.subviews {
            if let stack = firstStack(in: subview) {
                return stack
            }
        }
        return nil
    }

    private func titleView(in button: UIButton) -> UIView? {
        if let label = descendantLabels(in: button).first {
            return label
        }
        return button.subviews.first { subview in
            String(describing: type(of: subview)).contains("Title")
        }
    }

    private func featureURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/Features/\(path)")
    }

    private func appURL(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Calorie Counter/App/\(path)")
    }
}

private final class StubAIAssistantService: AIAssistantServiceProtocol {
    let response: AIAssistantChatResponse
    private(set) var requests: [AIAssistantChatRequest] = []

    init(response: AIAssistantChatResponse = AIAssistantChatResponse(
        mode: "chat",
        model: "test",
        message: AIAssistantChatMessage(role: "assistant", content: "noted", toolCalls: []),
        hasActions: false,
        error: nil
    )) {
        self.response = response
    }

    func chat(_ request: AIAssistantChatRequest) async throws -> AIAssistantChatResponse {
        requests.append(request)
        return response
    }
}

private final class FailingAssistantFoodRepository: FoodEntryRepositoryProtocol {
    func fetchAll() throws -> [FoodEntry] { [] }
    func fetchEntries(for date: Date) throws -> [FoodEntry] { [] }
    func fetchEntries(from start: Date, to end: Date) throws -> [FoodEntry] { [] }
    func fetchEntry(id: UUID) throws -> FoodEntry? { nil }
    func delete(id: UUID) throws {}
    func save(_ entry: FoodEntry) throws {
        throw NSError(domain: "AIAssistantChatTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Diary save failed"
        ])
    }
}
