import UIKit

final class AddFoodEntryViewController: BaseViewController, UITextFieldDelegate, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var productCard: AdaptiveView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var nameLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var portionField: UITextField!
    @IBOutlet private weak var servingsCard: AdaptiveView!
    @IBOutlet private weak var servingsTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var servingsValueLabel: AdaptiveLabel!
    @IBOutlet private weak var decrementButton: UIButton!
    @IBOutlet private weak var incrementButton: UIButton!
    @IBOutlet private weak var mealHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var mealStackView: UIStackView!
    @IBOutlet private weak var ingredientsHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var ingredientsStackView: UIStackView!
    @IBOutlet private weak var dateHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var dateBadgeLabel: AdaptiveLabel!
    @IBOutlet private weak var changeDateButton: UIButton!
    @IBOutlet private weak var nutritionHeaderLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesCard: NutritionMicroCardView!
    @IBOutlet private weak var proteinCard: NutritionMicroCardView!
    @IBOutlet private weak var fatCard: NutritionMicroCardView!
    @IBOutlet private weak var carbsCard: NutritionMicroCardView!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var alertDimView: UIView!
    @IBOutlet private weak var alertCard: AdaptiveView!
    @IBOutlet private weak var alertIconView: UIImageView!
    @IBOutlet private weak var alertTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var alertOKButton: UIButton!
    @IBOutlet private weak var calendarHost: AdaptiveView!

    private let savedAlert = StatusAlertOverlay()
    private let viewModel: AddFoodEntryViewModel
    private var calendarView: UICalendarView?
    private var calendarDateBadge: UILabel?
    private var stepperCapsule: UIView?
    private var didInstallCalendar = false
    private var isEditingPortion = false
    private var initialPortionInput = ""
    private let footerView = UIView()
    private let footerBlurContainer = UIView()
    private let footerBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let footerBlurMask = CAGradientLayer()
    private let footerGradientView = UIView()
    private let footerFadeGradient = CAGradientLayer()

    init(viewModel: AddFoodEntryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "AddFoodEntryViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .addFoodEntry }

    override func viewDidLoad() {
        savedAlert.attach(to: view)
        savedAlert.onOK = { [weak self] in
            self?.viewModel.addedAlertOKTapped()
        }
        super.viewDidLoad()
        configureChrome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if !isEditingPortion {
            stylePortion(viewModel.portionText.value)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutStepperCapsule()
        layoutFooterChrome()
        updateScrollInsets()
        installCalendarIfNeeded()
    }

    override func bindViewModel() {
        viewModel.nameText.bind { [weak self] value in
            self?.applyName(value)
        }
        viewModel.subtitleText.bind { [weak self] value in
            self?.applySubtitle(value)
        }
        viewModel.portionText.bind { [weak self] value in
            guard let self, !self.isEditingPortion else { return }
            self.stylePortion(value)
        }
        viewModel.canEditPortion.bind { [weak self] enabled in
            self?.portionField.isEnabled = enabled
        }
        viewModel.servingsText.bind { [weak self] value in
            self?.servingsValueLabel.text = value
        }
        viewModel.canDecrementServings.bind { [weak self] enabled in
            self?.decrementButton.isEnabled = enabled
            self?.decrementButton.alpha = enabled ? 1 : 0.35
        }
        viewModel.canIncrementServings.bind { [weak self] enabled in
            self?.incrementButton.isEnabled = enabled
            self?.incrementButton.alpha = enabled ? 1 : 0.35
        }
        viewModel.errorText.bind { [weak self] message in
            guard let self, !message.isEmpty else { return }
            Haptics.error()
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
            self.present(alert, animated: true)
        }
        viewModel.canAddEntry.bind { [weak self] enabled in
            self?.addButton.isEnabled = enabled
            self?.addButton.alpha = enabled ? 1 : 0.6
        }
        viewModel.addButtonTitle.bind { [weak self] title in
            guard let button = self?.addButton else { return }
            if var configuration = button.configuration {
                configuration.title = title
                button.configuration = configuration
            } else {
                button.setTitle(title, for: .normal)
            }
        }
        viewModel.dateText.bind { [weak self] value in
            self?.dateBadgeLabel.text = value
            guard let badge = self?.calendarDateBadge else { return }
            badge.text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            OnboardingStyle.lockFigmaFont(badge, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        }
        viewModel.nutritionHeaderText.bind { [weak self] value in
            self?.applySectionHeader(self?.nutritionHeaderLabel, symbol: "heart.text.square", title: value)
        }
        viewModel.caloriesText.bind { [weak self] value in
            self?.caloriesCard.configure(title: L10n.tr("photo.result.calories"), value: value)
        }
        viewModel.proteinText.bind { [weak self] value in
            self?.proteinCard.configure(title: L10n.tr("home.protein"), value: value)
        }
        viewModel.fatText.bind { [weak self] value in
            self?.fatCard.configure(title: L10n.tr("photo.result.fat"), value: value)
        }
        viewModel.carbsText.bind { [weak self] value in
            self?.carbsCard.configure(title: L10n.tr("home.carbs"), value: value)
        }
        viewModel.ingredients.bind { [weak self] items in
            self?.renderIngredients(items)
        }
        viewModel.selectedMeal.bind { [weak self] _ in
            self?.renderMeals()
        }
        viewModel.heroImage.bind { [weak self] image in
            self?.applyHeroImage(image)
        }
        viewModel.showsAddedAlert.bind { [weak self] visible in
            self?.savedAlert.setVisible(visible)
        }
        viewModel.addedAlertText.bind { [weak self] value in
            self?.savedAlert.configure(title: value)
        }
        applyPresentation()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshFooterColors()
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard textField === portionField, let draft = viewModel.draft.value else { return }
        isEditingPortion = true
        portionField.keyboardType = .decimalPad
        portionField.text = ProductDetailsMath.numericPortionText(for: draft)
        initialPortionInput = portionField.text ?? ""
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        isEditingPortion = false
        guard textField.text != initialPortionInput else {
            if let draft = viewModel.draft.value { textField.text = ProductDetailsMath.loggedPortionText(for: draft) }
            return
        }
        let unit = (viewModel.draft.value?.portionMilliliters ?? 0) > 0 ? AppUnits.current.volumeSymbol : AppUnits.current.portionSymbol
        viewModel.commitPortion((textField.text ?? "") + " " + unit)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField === portionField else { return true }
        let current = textField.text ?? ""
        let next: String
        if let span = Range(range, in: current) {
            next = Self.numericPortionInput(current.replacingCharacters(in: span, with: string))
        } else {
            next = Self.numericPortionInput(current + string)
        }
        guard Self.isNumericPortionInput(next) else { return false }
        textField.text = next
        return false
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func configureChrome() {
        let isRecipeSheet = viewModel.presentation == .recipeSheet
        view.backgroundColor = isRecipeSheet ? UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.11, alpha: 1) : UIColor(red: 231/255, green: 1, blue: 252/255, alpha: 1) } : .clear
        backgroundImageView.image = UIImage(named: "appBackground")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.isHidden = isRecipeSheet
        view.sendSubviewToBack(backgroundImageView)
        titleLabel.text = L10n.tr("product.entry.title")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        if isRecipeSheet {
            var close = UIButton.Configuration.plain()
            close.image = UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
            close.baseForegroundColor = AppColor.iconSecondary
            close.background.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.28, alpha: 1) : UIColor.black.withAlphaComponent(0.08) }
            close.cornerStyle = .capsule
            backButton.configuration = close
        } else {
            OnboardingStyle.styleBackButton(backButton)
        }
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        productCard.useLiveGlass = false
        productCard.applyCardShadow = true
        servingsCard.useLiveGlass = false
        servingsCard.applyCardShadow = true
        calendarHost.useLiveGlass = false
        calendarHost.applyCardShadow = true
        calendarHost.clipsToBounds = false
        calendarHost.layer.masksToBounds = false
        if isRecipeSheet {
            calendarHost.designCornerRadius = 16
            applyRecipeSheetNavInset()
        }
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.cornerRadius = .adaptWidth(12)
        applyName(viewModel.nameText.value)
        applySubtitle(viewModel.subtitleText.value)
        portionField.delegate = self
        portionField.borderStyle = .none
        portionField.backgroundColor = .clear
        portionField.tintColor = AppColor.teal
        portionField.clearButtonMode = .whileEditing
        portionField.returnKeyType = .done
        portionField.keyboardType = .decimalPad
        portionField.inputAccessoryView = makePortionKeyboardDoneBar()
        scrollView.delegate = self
        scrollView.keyboardDismissMode = .onDrag
        scrollView.alwaysBounceVertical = true
        overlayFooterBehindAddButton()
        installKeyboardDismissPan()
        servingsTitleLabel.text = L10n.tr("product.entry.servings")
        OnboardingStyle.lockFigmaFont(servingsTitleLabel, size: 15, weight: .regular, color: AppColor.labelsPrimary, kern: -0.23)
        OnboardingStyle.lockFigmaFont(servingsValueLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.stylePlainSymbolButton(
            decrementButton,
            systemName: "minus",
            foregroundColor: AppColor.labelsPrimary
        )
        OnboardingStyle.stylePlainSymbolButton(
            incrementButton,
            systemName: "plus",
            foregroundColor: AppColor.labelsPrimary
        )
        installStepperCapsule()
        installStepperSeparator()
        decrementButton.addTarget(self, action: #selector(decrementTapped), for: .touchUpInside)
        incrementButton.addTarget(self, action: #selector(incrementTapped), for: .touchUpInside)
        decrementButton.controlHaptic = .selection
        incrementButton.controlHaptic = .selection
        servingsTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applySectionHeader(mealHeaderLabel, symbol: "fork.knife.circle", title: L10n.tr("product.entry.selectMeal"))
        applySectionHeader(ingredientsHeaderLabel, symbol: "list.bullet.clipboard", title: L10n.tr("product.details.ingredients"))
        applySectionHeader(dateHeaderLabel, symbol: "calendar", title: L10n.tr("product.entry.logDate"))
        dateBadgeLabel.backgroundColor = AppColor.fillQuaternary
        dateBadgeLabel.layer.cornerRadius = .adaptWidth(17)
        dateBadgeLabel.layer.masksToBounds = true
        dateBadgeLabel.textAlignment = .center
        dateBadgeLabel.isUserInteractionEnabled = true
        dateBadgeLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(changeDateTapped)))
        OnboardingStyle.lockFigmaFont(dateBadgeLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        changeDateButton.configuration = nil
        changeDateButton.setTitle(L10n.tr("product.entry.changeDate"), for: .normal)
        changeDateButton.setTitleColor(AppColor.teal, for: .normal)
        changeDateButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        changeDateButton.setContentHuggingPriority(.required, for: .horizontal)
        changeDateButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        changeDateButton.addTarget(self, action: #selector(changeDateTapped), for: .touchUpInside)
        OnboardingStyle.applyPressFeedback(changeDateButton)
        OnboardingStyle.stylePrimaryButton(addButton, title: viewModel.addButtonTitle.value, systemImage: "plus")
        addButton.isEnabled = viewModel.canAddEntry.value
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        alertDimView.isHidden = true
        alertCard.isHidden = true
        alertDimView.isUserInteractionEnabled = false
        alertCard.isUserInteractionEnabled = false
        styleListCard(mealStackView)
        styleListCard(ingredientsStackView)
        stylePortionField()
        if isRecipeSheet {
            for card in [productCard, servingsCard, calendarHost].compactMap({ $0 }) {
                card.cardFillColor = AppColor.backgroundsPrimary
                card.cardShadowOpacity = 0.1
                card.designShadowRadius = 8
                card.showsHairlineBorder = false
            }
            for card in [portionField.superview, mealStackView].compactMap({ $0 }) {
                card.layer.shadowOpacity = 0.1
                card.layer.shadowRadius = 8
                card.layer.shadowOffset = CGSize(width: 3, height: 4)
            }
        }
        let dismissTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        dismissTap.cancelsTouchesInView = false
        view.addGestureRecognizer(dismissTap)
        stylePortion(viewModel.portionText.value)
    }

    private func applyName(_ value: String) {
        nameLabel.text = value
        OnboardingStyle.lockFigmaFont(nameLabel, size: 20, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.45)
        nameLabel.applyLineTruncation(lines: 2)
    }

    private func applySubtitle(_ value: String) {
        subtitleLabel.text = value
        OnboardingStyle.lockFigmaFont(subtitleLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        subtitleLabel.applyLineTruncation(lines: 2)
    }

    private func applyHeroImage(_ image: UIImage?) {
        if let image {
            photoImageView.image = image
            photoImageView.contentMode = .scaleAspectFill
            return
        }
        photoImageView.image = OnboardingStyle.symbol("photo", pointSize: 16)?.withTintColor(
            AppColor.labelsSecondary,
            renderingMode: .alwaysOriginal
        )
        photoImageView.contentMode = .center
    }

    private func stylePortionField() {
        guard let card = portionField.superview else { return }
        card.backgroundColor = AppColor.card
        card.layer.cornerRadius = .adaptHeight(26)
        card.layer.cornerCurve = .continuous
        OnboardingStyle.applyCardFallbackShadow(card.layer)
    }

    private func styleListCard(_ stack: UIStackView) {
        stack.backgroundColor = AppColor.card
        stack.layer.cornerRadius = .adaptWidth(24)
        stack.layer.cornerCurve = .continuous
        stack.clipsToBounds = false
        stack.layer.masksToBounds = false
        OnboardingStyle.applyCardFallbackShadow(stack.layer)
    }

    private func installStepperCapsule() {
        guard stepperCapsule == nil, let stepper = decrementButton.superview else { return }
        if let stack = stepper as? UIStackView {
            stack.spacing = 0
            stack.alignment = .fill
            stack.distribution = .fillEqually
            stack.backgroundColor = .clear
        }
        let capsule = UIView()
        capsule.isUserInteractionEnabled = false
        capsule.backgroundColor = AppColor.fillQuaternary
        capsule.translatesAutoresizingMaskIntoConstraints = false
        servingsCard.insertSubview(capsule, belowSubview: stepper)
        NSLayoutConstraint.activate([
            capsule.leadingAnchor.constraint(equalTo: stepper.leadingAnchor),
            capsule.trailingAnchor.constraint(equalTo: stepper.trailingAnchor),
            capsule.topAnchor.constraint(equalTo: stepper.topAnchor),
            capsule.bottomAnchor.constraint(equalTo: stepper.bottomAnchor)
        ])
        stepperCapsule = capsule
        stepper.backgroundColor = .clear
        decrementButton.backgroundColor = .clear
        incrementButton.backgroundColor = .clear
        decrementButton.layer.cornerRadius = 0
        incrementButton.layer.cornerRadius = 0
        decrementButton.layer.maskedCorners = []
        incrementButton.layer.maskedCorners = []
    }

    private func layoutStepperCapsule() {
        guard let capsule = stepperCapsule else { return }
        capsule.layer.cornerRadius = capsule.bounds.height / 2
        capsule.layer.cornerCurve = .continuous
        capsule.clipsToBounds = true
    }

    private func installStepperSeparator() {
        guard let stepper = decrementButton.superview,
              stepper.viewWithTag(8_314) == nil else { return }
        let separator = UIView()
        separator.tag = 8_314
        separator.backgroundColor = AppColor.grabber
        separator.translatesAutoresizingMaskIntoConstraints = false
        stepper.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.centerXAnchor.constraint(equalTo: stepper.centerXAnchor),
            separator.centerYAnchor.constraint(equalTo: stepper.centerYAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),
            separator.heightAnchor.constraint(equalToConstant: .adaptHeight(24))
        ])
    }

    private func applySectionHeader(_ label: AdaptiveLabel?, symbol: String, title: String) {
        guard let label else { return }
        let image = OnboardingStyle.symbol(symbol, pointSize: 15, weight: .semibold)
        let text = NSMutableAttributedString()
        if let image {
            let attachment = NSTextAttachment()
            attachment.image = image.withTintColor(AppColor.labelVibrantPrimary, renderingMode: .alwaysOriginal)
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(string: " "))
        }
        text.append(NSAttributedString(
            string: title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
                .foregroundColor: AppColor.labelVibrantPrimary,
                .kern: -0.23
            ]
        ))
        label.attributedText = text
        label.adaptFontSize = false
    }

    private func stylePortion(_ text: String) {
        let font = UIFont.systemFont(ofSize: 17, weight: .medium)
        portionField.defaultTextAttributes = [
            .font: font,
            .foregroundColor: AppColor.labelsPrimary,
            .kern: -0.43
        ]
        portionField.font = font
        portionField.textColor = AppColor.labelsPrimary
        portionField.text = text
    }

    private func renderMeals() {
        mealStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        viewModel.mealTypes.enumerated().forEach { index, meal in
            let row = NutritionFactRowView()
            row.configureMeal(title: meal.localizedTitle, selected: meal == viewModel.selectedMeal.value, showsSeparator: index > 0)
            row.addAction(UIAction { [weak self] _ in
                self?.viewModel.selectMeal(meal)
            }, for: .touchUpInside)
            mealStackView.addArrangedSubview(row)
        }
    }

    private func renderIngredients(_ items: [FoodIngredient]) {
        let visible = viewModel.presentation != .recipeSheet && !items.isEmpty
        ingredientsHeaderLabel.superview?.isHidden = !visible
        ingredientsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard visible else { return }
        items.enumerated().forEach { index, item in
            let view = IngredientLineView()
            view.configure(item, showsSeparator: index > 0, editable: true)
            view.onCommit = { [weak self] id, text in
                self?.viewModel.commitIngredient(id: id, text: text)
            }
            ingredientsStackView.addArrangedSubview(view)
        }
    }

    private func applyPresentation() {
        let isRecipeSheet = viewModel.presentation == .recipeSheet
        dateHeaderLabel.superview?.isHidden = isRecipeSheet
        nutritionHeaderLabel.superview?.isHidden = isRecipeSheet
        calendarHost?.isHidden = !isRecipeSheet
        if isRecipeSheet {
            installCalendarIfNeeded()
        }
    }

    private func applyRecipeSheetNavInset() {
        view.constraints
            .filter { constraint in
                (constraint.firstItem as? UIView) === backButton && constraint.firstAttribute == .top
            }
            .forEach { $0.constant = .adaptHeight(16) }
    }

    private func installCalendarIfNeeded() {
        guard viewModel.presentation == .recipeSheet else { return }
        guard !didInstallCalendar else { return }
        guard let calendarHost, calendarHost.window != nil else { return }
        guard calendarHost.bounds.width > 1, calendarHost.bounds.height > 1 else { return }
        didInstallCalendar = true
        calendarHost.constraints.filter { $0.firstAttribute == .height }.forEach { $0.isActive = false }
        calendarHost.designCornerRadius = 16

        let header = makeCalendarHeader()
        let separator = UIView()
        separator.backgroundColor = AppColor.hairline
        separator.translatesAutoresizingMaskIntoConstraints = false

        let pickerHost = UIView()
        pickerHost.clipsToBounds = false
        pickerHost.translatesAutoresizingMaskIntoConstraints = false

        let calendarView = UICalendarView()
        calendarView.calendar = .current
        calendarView.locale = .current
        calendarView.tintColor = AppColor.teal
        calendarView.backgroundColor = .clear
        calendarView.wantsDateDecorations = false
        calendarView.setContentCompressionResistancePriority(.required, for: .vertical)
        calendarView.translatesAutoresizingMaskIntoConstraints = false

        calendarHost.addSubview(header)
        calendarHost.addSubview(separator)
        calendarHost.addSubview(pickerHost)
        pickerHost.addSubview(calendarView)
        calendarHost.bringSubviewToFront(separator)
        calendarHost.bringSubviewToFront(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: calendarHost.topAnchor),
            header.leadingAnchor.constraint(equalTo: calendarHost.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: calendarHost.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: .adaptHeight(66)),
            separator.topAnchor.constraint(equalTo: header.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: calendarHost.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: calendarHost.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
            pickerHost.topAnchor.constraint(equalTo: separator.bottomAnchor),
            pickerHost.leadingAnchor.constraint(equalTo: calendarHost.leadingAnchor),
            pickerHost.trailingAnchor.constraint(equalTo: calendarHost.trailingAnchor),
            pickerHost.bottomAnchor.constraint(equalTo: calendarHost.bottomAnchor),
            calendarView.topAnchor.constraint(equalTo: pickerHost.topAnchor, constant: .adaptHeight(3)),
            calendarView.leadingAnchor.constraint(equalTo: pickerHost.leadingAnchor, constant: .adaptWidth(4)),
            calendarView.trailingAnchor.constraint(equalTo: pickerHost.trailingAnchor, constant: -.adaptWidth(4)),
            calendarView.bottomAnchor.constraint(equalTo: pickerHost.bottomAnchor, constant: -.adaptHeight(8))
        ])
        let selection = UICalendarSelectionMultiDate(delegate: self)
        calendarView.selectionBehavior = selection
        let start = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date.distantPast
        let end = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date.distantFuture
        calendarView.availableDateRange = DateInterval(start: start, end: end)
        self.calendarView = calendarView
        applyCalendarSelection(selection)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyCalendarSelection(selection)
            var visible = Calendar.current.dateComponents([.year, .month, .day], from: self.viewModel.draft.value?.resolvedLogDates().first ?? Date())
            visible.calendar = Calendar.current
            calendarView.visibleDateComponents = visible
        }
    }

    private func makeCalendarHeader() -> UIView {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.isUserInteractionEnabled = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.attributedText = logDateHeaderTitle()
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let badge = UILabel()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.numberOfLines = 1
        badge.textAlignment = .center
        badge.lineBreakMode = .byTruncatingTail
        badge.text = viewModel.dateText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        OnboardingStyle.lockFigmaFont(badge, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        badge.setContentHuggingPriority(.required, for: .horizontal)
        badge.setContentCompressionResistancePriority(.required, for: .horizontal)
        calendarDateBadge = badge

        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = AppColor.fillQuaternary
        pill.layer.cornerRadius = .adaptHeight(17)
        pill.layer.cornerCurve = .continuous
        pill.clipsToBounds = true
        pill.setContentHuggingPriority(.required, for: .horizontal)
        pill.setContentCompressionResistancePriority(.required, for: .horizontal)
        pill.addSubview(badge)

        header.addSubview(titleLabel)
        header.addSubview(pill)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: .adaptWidth(16)),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            pill.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: .adaptWidth(8)),
            pill.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -.adaptWidth(16)),
            pill.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            pill.heightAnchor.constraint(equalToConstant: .adaptHeight(34)),
            badge.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: .adaptWidth(11)),
            badge.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -.adaptWidth(11)),
            badge.topAnchor.constraint(equalTo: pill.topAnchor, constant: .adaptHeight(6)),
            badge.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -.adaptHeight(6))
        ])
        return header
    }

    private func logDateHeaderTitle() -> NSAttributedString {
        let text = NSMutableAttributedString()
        if let image = OnboardingStyle.symbol("calendar", pointSize: 17, weight: .regular) {
            let attachment = NSTextAttachment()
            let tinted = image.withTintColor(AppColor.labelVibrantPrimary, renderingMode: .alwaysOriginal)
            attachment.image = tinted
            let size = tinted.size
            attachment.bounds = CGRect(x: 0, y: -3, width: size.width, height: size.height)
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(string: " "))
        }
        text.append(NSAttributedString(
            string: L10n.tr("product.entry.logDate"),
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: AppColor.labelVibrantPrimary,
                .kern: -0.43
            ]
        ))
        return text
    }

    private func applyCalendarSelection(_ selection: UICalendarSelectionMultiDate) {
        let dates = viewModel.draft.value?.resolvedLogDates() ?? [Calendar.current.startOfDay(for: Date())]
        selection.selectedDates = dates.map {
            var components = Calendar.current.dateComponents([.calendar, .era, .year, .month, .day], from: $0)
            components.calendar = Calendar.current
            return components
        }
    }

    @objc private func backTapped() {
        viewModel.backTapped()
    }

    @objc private func decrementTapped() {
        view.endEditing(true)
        viewModel.decrementServings()
    }

    @objc private func incrementTapped() {
        view.endEditing(true)
        viewModel.incrementServings()
    }

    @objc private func changeDateTapped() {
        viewModel.changeDateTapped()
    }

    @objc private func addTapped() {
        view.endEditing(true)
        viewModel.addEntryTapped()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func overlayFooterBehindAddButton() {
        view.constraints
            .filter { constraint in
                (constraint.firstItem as? UIView) === addButton && constraint.firstAttribute == .top
                    || (constraint.secondItem as? UIView) === addButton && constraint.secondAttribute == .top
            }
            .forEach { $0.isActive = false }
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        footerView.translatesAutoresizingMaskIntoConstraints = false
        footerView.isUserInteractionEnabled = false
        footerView.backgroundColor = .clear
        if footerView.superview !== view {
            view.insertSubview(footerView, belowSubview: addButton)
        }
        NSLayoutConstraint.activate([
            footerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            footerView.topAnchor.constraint(equalTo: addButton.topAnchor, constant: -.adaptHeight(viewModel.presentation == .recipeSheet ? 16 : 84))
        ])
        installFooterChrome()
    }

    private func installFooterChrome() {
        footerBlurContainer.backgroundColor = .clear
        footerBlurContainer.isUserInteractionEnabled = false
        footerBlurView.isUserInteractionEnabled = false
        footerGradientView.isUserInteractionEnabled = false
        footerGradientView.backgroundColor = .clear
        if footerBlurView.superview !== footerBlurContainer {
            footerBlurContainer.addSubview(footerBlurView)
        }
        if footerBlurContainer.superview !== footerView {
            footerView.insertSubview(footerBlurContainer, at: 0)
        }
        if footerGradientView.superview !== footerView {
            footerView.insertSubview(footerGradientView, aboveSubview: footerBlurContainer)
        }
        footerBlurMask.startPoint = CGPoint(x: 0.5, y: 1)
        footerBlurMask.endPoint = CGPoint(x: 0.5, y: 0)
        footerBlurMask.colors = [
            UIColor.black.cgColor,
            UIColor.black.withAlphaComponent(0.45).cgColor,
            UIColor.clear.cgColor
        ]
        footerBlurMask.locations = [0, 0.5, 0.95238]
        footerBlurContainer.layer.mask = footerBlurMask
        footerFadeGradient.startPoint = CGPoint(x: 0.5, y: 1)
        footerFadeGradient.endPoint = CGPoint(x: 0.5, y: 0)
        footerFadeGradient.locations = [0, 0.5, 0.95238]
        if footerFadeGradient.superlayer !== footerGradientView.layer {
            footerGradientView.layer.addSublayer(footerFadeGradient)
        }
        refreshFooterColors()
    }

    private func layoutFooterChrome() {
        guard footerView.bounds.width > 0 else { return }
        footerBlurContainer.frame = footerView.bounds
        footerBlurView.frame = footerBlurContainer.bounds
        footerGradientView.frame = footerView.bounds
        footerFadeGradient.frame = footerGradientView.bounds
        footerBlurMask.frame = footerBlurContainer.bounds
        refreshFooterColors()
    }

    private func refreshFooterColors() {
        footerFadeGradient.colors = AppColor.fadeColors(
            from: viewModel.presentation == .recipeSheet ? (view.backgroundColor ?? AppColor.backgroundsPrimary) : AppColor.backgroundsPrimary,
            traits: traitCollection
        )
    }

    private func updateScrollInsets() {
        let overlap = footerView.bounds.height - view.safeAreaInsets.bottom
        let inset = max(overlap, 0)
        scrollView.contentInset.bottom = inset
        scrollView.verticalScrollIndicatorInsets.bottom = inset
    }

    private func makePortionKeyboardDoneBar() -> UIToolbar {
        let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 44))
        bar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissKeyboard))
        ]
        bar.sizeToFit()
        return bar
    }

    private func installKeyboardDismissPan() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleKeyboardDismissPan))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    @objc private func handleKeyboardDismissPan(_ pan: UIPanGestureRecognizer) {
        guard portionField.isFirstResponder else { return }
        if abs(pan.translation(in: view).y) > 8 {
            view.endEditing(true)
        }
    }

    private static func numericPortionInput(_ text: String) -> String {
        var result = ""
        var sawSeparator = false
        var fractionCount = 0
        var integerCount = 0
        for character in text {
            if character.isNumber {
                if sawSeparator {
                    guard fractionCount < 2 else { continue }
                    fractionCount += 1
                } else {
                    guard integerCount < 6 else { continue }
                    integerCount += 1
                }
                result.append(character)
            } else if (character == "." || character == ",") && !sawSeparator && !result.isEmpty {
                sawSeparator = true
                result.append(character)
            }
        }
        return result
    }

    private static func isNumericPortionInput(_ text: String) -> Bool {
        if text.isEmpty { return true }
        let pattern = #"^\d{0,6}([.,]\d{0,2})?$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}

extension AddFoodEntryViewController: UICalendarSelectionMultiDateDelegate {
    func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didSelectDate dateComponents: DateComponents) {
        viewModel.updateDates(dates(from: selection.selectedDates))
    }

    func multiDateSelection(_ selection: UICalendarSelectionMultiDate, didDeselectDate dateComponents: DateComponents) {
        viewModel.updateDates(dates(from: selection.selectedDates))
    }

    func multiDateSelection(_ selection: UICalendarSelectionMultiDate, canDeselectDate dateComponents: DateComponents) -> Bool {
        selection.selectedDates.count > 1
    }

    private func dates(from components: [DateComponents]) -> [Date] {
        Array(Set(components.compactMap { Calendar.current.date(from: $0) }.map { Calendar.current.startOfDay(for: $0) })).sorted()
    }
}
