import UIKit

final class RecipeFiltersViewController: BaseViewController, UITextFieldDelegate, UIScrollViewDelegate {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var resetButton: UIButton!
    @IBOutlet private weak var mealTypeLabel: AdaptiveLabel!
    @IBOutlet private weak var mealTypeStack: UIStackView!
    @IBOutlet private weak var cuisineLabel: AdaptiveLabel!
    @IBOutlet private weak var cuisineStack: UIStackView!
    @IBOutlet private weak var dietLabel: AdaptiveLabel!
    @IBOutlet private weak var dietStack: UIStackView!
    @IBOutlet private weak var cookLabel: AdaptiveLabel!
    @IBOutlet private weak var cookStack: UIStackView!
    @IBOutlet private weak var caloriesLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesValueLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesSlider: UISlider!
    @IBOutlet private weak var difficultyLabel: AdaptiveLabel!
    @IBOutlet private weak var difficultyStack: UIStackView!
    @IBOutlet private weak var excludedLabel: AdaptiveLabel!
    @IBOutlet private weak var excludedSearchField: AdaptiveView!
    @IBOutlet private weak var excludedField: UITextField!
    @IBOutlet private weak var excludedMicButton: UIButton!
    @IBOutlet private weak var suggestionsCard: AdaptiveView!
    @IBOutlet private weak var suggestionsStack: UIStackView!
    @IBOutlet private weak var excludedChipsStack: UIStackView!
    @IBOutlet private weak var showButton: UIButton!

    private let viewModel: RecipeFiltersViewModel
    private let destructiveColor = AppColor.dynamic(
        light: AppColor.accentRed,
        dark: UIColor(red: 1, green: 97 / 255, blue: 101 / 255, alpha: 1)
    )
    private var isConfigured = false
    private var lastChipSnapshot: ChipSnapshot?
    private var chipCarousels: [UIScrollView] = []
    private var dietCarousels: [UIScrollView] = []
    private var pulseWaves: [UIView] = []

    init(viewModel: RecipeFiltersViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "RecipeFiltersViewController")
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }

    override var analyticsScreen: AnalyticsScreen? { .recipeFilters }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.backgroundsPrimary
        titleLabel.text = L10n.tr("recipes.filtersTitle")
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        titleLabel.textAlignment = .center
        OnboardingStyle.styleGlassSymbolButton(closeButton, systemName: "xmark")
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        resetButton.setTitle(L10n.tr("recipes.filters.reset"), for: .normal)
        resetButton.setTitleColor(destructiveColor, for: .normal)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        styleSection(mealTypeLabel, L10n.tr("recipes.filters.mealType"))
        styleSection(cuisineLabel, L10n.tr("recipes.filters.cuisine"))
        styleSection(dietLabel, L10n.tr("recipes.filters.diet"))
        styleSection(cookLabel, L10n.tr("recipes.filters.cookTime"))
        styleSection(caloriesLabel, L10n.tr("recipes.filters.calories"))
        styleSection(difficultyLabel, L10n.tr("recipes.filters.difficulty"))
        styleSection(excludedLabel, L10n.tr("recipes.filters.excluded"))
        OnboardingStyle.lockFigmaFont(
            caloriesValueLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        caloriesValueLabel.textAlignment = .right
        caloriesSlider.minimumValue = 0
        caloriesSlider.maximumValue = Float(RecipeSearchFilters.calorieCeiling)
        caloriesSlider.minimumTrackTintColor = AppColor.teal
        caloriesSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        caloriesSlider.addTarget(self, action: #selector(sliderEnded), for: [.touchUpInside, .touchUpOutside])
        configureChipScrolls()
        configureExcludedSearch()
        OnboardingStyle.stylePrimaryButton(showButton, title: L10n.tr("recipes.filters.showResults"))
        showButton.addTarget(self, action: #selector(showTapped), for: .touchUpInside)
        isConfigured = true
        render(viewModel.filters.value)
        renderSuggestions()
    }

    override func bindViewModel() {
        viewModel.filters.bind { [weak self] filters in
            self?.render(filters)
        }
        viewModel.excludedQuery.bind { [weak self] text in
            guard let self else { return }
            if self.excludedField.text != text {
                self.excludedField.text = text
            }
            self.renderSuggestions()
        }
        viewModel.isRecording.bind { [weak self] _ in
            self?.styleTrailingButton()
        }
        viewModel.canConfirmExcluded.bind { [weak self] _ in
            self?.styleTrailingButton()
            self?.renderSuggestions()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyChipFades()
        if viewModel.canConfirmExcluded.value, excludedMicButton.bounds.height > 1 {
            excludedMicButton.layer.cornerRadius = excludedMicButton.bounds.height / 2
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        OnboardingStyle.applyChatChipsEdgeFade(to: scrollView)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        viewModel.addExcluded(textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }

    @objc private func closeTapped() { viewModel.closeTapped() }
    @objc private func resetTapped() { viewModel.resetTapped() }
    @objc private func showTapped() { viewModel.showResultsTapped() }
    @objc private func sliderChanged() {
        let value = Int(caloriesSlider.value.rounded())
        updateCaloriesHeader(value)
        guard !caloriesSlider.isTracking else { return }
        viewModel.updateCalories(value)
    }
    @objc private func sliderEnded() {
        viewModel.updateCalories(Int(caloriesSlider.value.rounded()))
    }
    @objc private func excludedChanged() {
        viewModel.updateExcludedQuery(excludedField.text ?? "")
    }
    @objc private func trailingActionTapped() { viewModel.trailingActionTapped() }

    private func styleSection(_ label: AdaptiveLabel, _ text: String) {
        label.text = text
        OnboardingStyle.lockFigmaFont(label, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
    }

    private func configureChipScrolls() {
        chipCarousels = [mealTypeStack, cuisineStack, cookStack, difficultyStack].compactMap { stack in
            (stack as? AdaptiveStackView)?.adaptSpacing = false
            stack.axis = .horizontal
            stack.alignment = .fill
            stack.distribution = .fill
            stack.spacing = .adaptWidth(8)
            guard let scroll = stack.superview as? UIScrollView else { return nil }
            OnboardingStyle.pinChipCarouselFullBleed(scroll, to: view)
            scroll.delegate = self
            return scroll
        }
    }

    private func applyChipFades() {
        (chipCarousels + dietCarousels).forEach { OnboardingStyle.applyChatChipsEdgeFade(to: $0) }
    }

    private func configureExcludedSearch() {
        excludedSearchField.useLiveGlass = true
        excludedSearchField.applyButtonGlass = true
        excludedSearchField.applyCardShadow = true
        excludedField.delegate = self
        excludedField.placeholder = L10n.tr("recipes.filters.addIngredients")
        excludedField.returnKeyType = .done
        excludedField.font = .systemFont(ofSize: .adaptFont(17), weight: .medium)
        excludedField.textColor = AppColor.labelsPrimary
        excludedField.backgroundColor = .clear
        excludedField.borderStyle = .none
        excludedField.addTarget(self, action: #selector(excludedChanged), for: .editingChanged)
        excludedSearchField.subviews.compactMap { $0 as? UIImageView }.first?.tintColor = AppColor.iconSecondary
        styleTrailingButton()
        excludedMicButton.addTarget(self, action: #selector(trailingActionTapped), for: .touchUpInside)
        suggestionsCard.useLiveGlass = false
        suggestionsCard.applyCardShadow = true
        suggestionsCard.cardFillColor = AppColor.backgroundsPrimary
        suggestionsStack.layer.cornerCurve = .continuous
        suggestionsStack.layer.cornerRadius = .adaptWidth(24)
        suggestionsStack.clipsToBounds = true
    }

    private func styleTrailingButton() {
        stopListeningAnimation()
        excludedSearchField.clipsToBounds = false
        excludedSearchField.layer.masksToBounds = false
        if viewModel.canConfirmExcluded.value {
            styleConfirmButton()
            return
        }
        OnboardingStyle.stylePlainSymbolButton(
            excludedMicButton,
            systemName: "microphone",
            foregroundColor: viewModel.isRecording.value ? AppColor.teal : AppColor.iconSecondary
        )
        excludedMicButton.clipsToBounds = false
        excludedMicButton.layer.masksToBounds = false
        if viewModel.isRecording.value {
            startListeningAnimation()
        }
    }

    private func styleConfirmButton() {
        let check = UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )?.withTintColor(AppColor.onAccent, renderingMode: .alwaysOriginal)
        excludedMicButton.configuration = nil
        excludedMicButton.setTitle(nil, for: .normal)
        excludedMicButton.setImage(check, for: .normal)
        excludedMicButton.tintColor = AppColor.onAccent
        excludedMicButton.backgroundColor = AppColor.teal
        excludedMicButton.clipsToBounds = true
        excludedMicButton.layer.masksToBounds = true
        excludedMicButton.imageView?.contentMode = .center
        excludedMicButton.imageView?.clipsToBounds = false
        excludedMicButton.imageView?.tintColor = AppColor.onAccent
        excludedMicButton.layer.cornerCurve = .continuous
        excludedMicButton.layer.shadowOpacity = 0
        excludedMicButton.layer.cornerRadius = excludedMicButton.bounds.height / 2
        if excludedMicButton.bounds.height < 1 {
            excludedMicButton.layer.cornerRadius = .adaptWidth(14)
        }
        excludedMicButton.controlHaptic = .medium
        OnboardingStyle.applyPressFeedback(excludedMicButton)
    }

    private func startListeningAnimation() {
        installPulseWavesIfNeeded()
        pulseWaves.forEach { $0.isHidden = false }
        excludedMicButton.layoutIfNeeded()
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1
        pulse.toValue = 1.14
        pulse.duration = 0.72
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        if let imageView = excludedMicButton.imageView {
            imageView.layer.add(pulse, forKey: "micPulse")
        } else {
            excludedMicButton.layer.add(pulse, forKey: "micPulse")
        }
        pulseWaves.enumerated().forEach { index, wave in
            wave.layer.cornerRadius = wave.bounds.height / 2
            wave.layer.cornerCurve = .continuous
            let group = CAAnimationGroup()
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.72
            scale.toValue = 1.55
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.4
            fade.toValue = 0
            group.animations = [scale, fade]
            group.duration = 1.15
            group.repeatCount = .infinity
            group.beginTime = CACurrentMediaTime() + Double(index) * 0.38
            wave.layer.add(group, forKey: "wave")
        }
    }

    private func stopListeningAnimation() {
        excludedMicButton.imageView?.layer.removeAnimation(forKey: "micPulse")
        excludedMicButton.layer.removeAnimation(forKey: "micPulse")
        excludedMicButton.imageView?.transform = .identity
        excludedMicButton.transform = .identity
        pulseWaves.forEach { wave in
            wave.layer.removeAllAnimations()
            wave.isHidden = true
        }
    }

    private func installPulseWavesIfNeeded() {
        guard pulseWaves.isEmpty else { return }
        (0..<2).forEach { _ in
            let wave = UIView()
            wave.isUserInteractionEnabled = false
            wave.backgroundColor = .clear
            wave.layer.borderWidth = 1.5
            wave.layer.borderColor = AppColor.teal.withAlphaComponent(0.5).cgColor
            wave.translatesAutoresizingMaskIntoConstraints = false
            excludedMicButton.insertSubview(wave, at: 0)
            NSLayoutConstraint.activate([
                wave.centerXAnchor.constraint(equalTo: excludedMicButton.centerXAnchor),
                wave.centerYAnchor.constraint(equalTo: excludedMicButton.centerYAnchor),
                wave.widthAnchor.constraint(equalTo: excludedMicButton.widthAnchor),
                wave.heightAnchor.constraint(equalTo: excludedMicButton.heightAnchor)
            ])
            pulseWaves.append(wave)
        }
    }

    private func render(_ filters: RecipeSearchFilters) {
        guard isConfigured else { return }
        updateCaloriesHeader(filters.maxCalories)
        if !caloriesSlider.isTracking {
            let next = Float(filters.maxCalories)
            if abs(caloriesSlider.value - next) > 0.5 {
                caloriesSlider.value = next
            }
        }
        let snapshot = ChipSnapshot(filters)
        guard lastChipSnapshot != snapshot else { return }
        lastChipSnapshot = snapshot
        fill(mealTypeStack, keys: viewModel.mealTypeOptions) { key in
            filters.contains(L10n.tr(key), in: filters.mealTypes)
        } action: { [weak self] key in
            self?.viewModel.selectMealType(key)
        }
        fill(cuisineStack, keys: viewModel.cuisineOptions) { key in
            key == "recipes.filters.any" ? filters.cuisines.isEmpty : filters.contains(L10n.tr(key), in: filters.cuisines)
        } action: { [weak self] key in
            self?.viewModel.selectCuisine(key)
        }
        fillScrollingRows(dietStack, keys: viewModel.dietOptions) { key in
            key == "recipes.filters.any" ? filters.diets.isEmpty : filters.contains(L10n.tr(key), in: filters.diets)
        } action: { [weak self] key in
            self?.viewModel.selectDiet(key)
        }
        cookStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        cookStack.axis = .horizontal
        cookStack.distribution = .fill
        viewModel.cookOptions.forEach { key, minutes in
            cookStack.addArrangedSubview(
                chip(title: L10n.tr(key), selected: filters.maxReadyMinutes == minutes) { [weak self] in
                    self?.viewModel.selectCookTime(minutes)
                }
            )
        }
        fill(difficultyStack, keys: viewModel.difficultyOptions) { key in
            key == "recipes.filters.any"
                ? filters.difficulties.isEmpty
                : filters.contains(L10n.tr(key), in: filters.difficulties)
        } action: { [weak self] key in
            self?.viewModel.selectDifficulty(key)
        }
        renderExcludedChips(filters.excludedIngredients)
        renderSuggestions()
        view.layoutIfNeeded()
        applyChipFades()
    }

    private func updateCaloriesHeader(_ value: Int) {
        caloriesValueLabel.text = L10n.format("recipes.filters.caloriesValue", 0, value)
    }

    private func renderExcludedChips(_ titles: [String]) {
        excludedChipsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        excludedChipsStack.isHidden = titles.isEmpty
        guard !titles.isEmpty else { return }
        var row = makeChipRow()
        var used: CGFloat = 0
        let maxWidth = max(excludedChipsStack.bounds.width, view.bounds.width - .adaptWidth(32))
        titles.forEach { title in
            let button = chip(title: title, selected: false, destructive: true) { [weak self] in
                self?.viewModel.removeExcluded(title)
            }
            let width = button.intrinsicContentSize.width
            if used > 0, used + .adaptWidth(8) + width > maxWidth {
                finishChipRow(row)
                excludedChipsStack.addArrangedSubview(row)
                row = makeChipRow()
                used = 0
            }
            row.addArrangedSubview(button)
            used += (used == 0 ? 0 : .adaptWidth(8)) + width
        }
        finishChipRow(row)
        excludedChipsStack.addArrangedSubview(row)
    }

    private func renderSuggestions() {
        guard isConfigured else { return }
        suggestionsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let titles = viewModel.suggestionTitles
        suggestionsCard.isHidden = titles.isEmpty
        titles.enumerated().forEach { index, name in
            suggestionsStack.addArrangedSubview(
                makeSuggestionRow(
                    title: name,
                    showsSeparator: index < titles.count - 1
                ) { [weak self] in
                    self?.viewModel.addExcluded(name)
                }
            )
        }
    }

    private func fill(
        _ stack: UIStackView,
        keys: [String],
        selected: (String) -> Bool,
        action: @escaping (String) -> Void
    ) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        keys.forEach { key in
            stack.addArrangedSubview(
                chip(title: L10n.tr(key), selected: selected(key)) { action(key) }
            )
        }
    }

    private func fillScrollingRows(
        _ stack: UIStackView,
        keys: [String],
        selected: (String) -> Bool,
        action: @escaping (String) -> Void
    ) {
        dietCarousels.removeAll()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = .adaptHeight(12)
        stride(from: 0, to: keys.count, by: 3).forEach { index in
            let rowKeys = Array(keys[index..<min(index + 3, keys.count)])
            let row = makeChipRow()
            rowKeys.forEach { key in
                row.addArrangedSubview(
                    chip(title: L10n.tr(key), selected: selected(key)) { action(key) }
                )
            }
            let scroll = makeChipRowScroll(row)
            stack.addArrangedSubview(scroll)
            OnboardingStyle.pinChipCarouselFullBleed(scroll, to: view)
            scroll.delegate = self
            dietCarousels.append(scroll)
        }
    }

    private func makeChipRowScroll(_ row: UIStackView) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)
        NSLayoutConstraint.activate([
            scroll.heightAnchor.constraint(equalToConstant: .adaptHeight(34)),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        return scroll
    }

    private func finishChipRow(_ row: UIStackView) {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(spacer)
    }

    private func makeChipRow() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = .adaptWidth(8)
        row.alignment = .fill
        row.distribution = .fill
        return row
    }

    private func makeSuggestionRow(
        title: String,
        showsSeparator: Bool,
        action: @escaping () -> Void
    ) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: "plus")
        config.imagePlacement = .trailing
        config.imagePadding = .adaptWidth(16)
        config.baseForegroundColor = AppColor.labelsPrimary
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: .adaptWidth(16),
            bottom: 0,
            trailing: .adaptWidth(16)
        )
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = .systemFont(ofSize: .adaptFont(17), weight: .regular)
            attributes.kern = -0.43
            attributes.foregroundColor = AppColor.labelsPrimary
            return attributes
        }
        config.imageColorTransformer = UIConfigurationColorTransformer { _ in
            AppColor.labelsSecondary
        }
        button.configuration = config
        button.contentHorizontalAlignment = .fill
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        row.addSubview(button)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: .adaptHeight(40)),
            button.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            button.topAnchor.constraint(equalTo: row.topAnchor),
            button.bottomAnchor.constraint(equalTo: row.bottomAnchor)
        ])
        if showsSeparator {
            let line = UIView()
            line.translatesAutoresizingMaskIntoConstraints = false
            line.backgroundColor = AppColor.hairline
            row.addSubview(line)
            NSLayoutConstraint.activate([
                line.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
                line.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                line.trailingAnchor.constraint(equalTo: row.trailingAnchor),
                line.bottomAnchor.constraint(equalTo: row.bottomAnchor)
            ])
        }
        return row
    }

    private func chip(title: String, selected: Bool, destructive: Bool = false, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = nil
        button.translatesAutoresizingMaskIntoConstraints = false
        if destructive {
            let close = UIImage(
                systemName: "xmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            )
            button.setTitle(title, for: .normal)
            button.setImage(close, for: .normal)
            button.semanticContentAttribute = .forceRightToLeft
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
            button.tintColor = AppColor.onAccent
            button.setTitleColor(AppColor.onAccent, for: .normal)
            button.backgroundColor = destructiveColor
        } else {
            button.setImage(nil, for: .normal)
            button.setTitle(title, for: .normal)
            button.setTitleColor(selected ? AppColor.onAccent : AppColor.labelsPrimary, for: .normal)
            button.backgroundColor = selected ? AppColor.teal : AppColor.fillQuaternary
        }
        button.titleLabel?.font = .systemFont(ofSize: .adaptFont(15), weight: .regular)
        button.titleLabel?.adjustsFontSizeToFitWidth = false
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.titleLabel?.numberOfLines = 1
        button.contentEdgeInsets = UIEdgeInsets(
            top: .adaptHeight(7),
            left: .adaptWidth(12),
            bottom: .adaptHeight(7),
            right: destructive ? .adaptWidth(8) : .adaptWidth(12)
        )
        button.layer.cornerRadius = .adaptHeight(17)
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .vertical)
        button.setContentCompressionResistancePriority(.required, for: .vertical)
        button.heightAnchor.constraint(equalToConstant: .adaptHeight(34)).isActive = true
        button.controlHaptic = .selection
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }
}

private struct ChipSnapshot: Equatable {
    var mealTypes: [String]
    var cuisines: [String]
    var diets: [String]
    var maxReadyMinutes: Int?
    var difficulties: [String]
    var excludedIngredients: [String]

    init(_ filters: RecipeSearchFilters) {
        mealTypes = filters.mealTypes
        cuisines = filters.cuisines
        diets = filters.diets
        maxReadyMinutes = filters.maxReadyMinutes
        difficulties = filters.difficulties
        excludedIngredients = filters.excludedIngredients
    }
}
