import UIKit

final class PantryItemEditViewController: BaseViewController, UICalendarSelectionSingleDateDelegate {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var productCard: AdaptiveView!
    @IBOutlet private weak var productImageView: UIImageView!
    @IBOutlet private weak var nameLabel: AdaptiveLabel!
    @IBOutlet private weak var quantityCard: AdaptiveView!
    @IBOutlet private weak var quantityLabel: AdaptiveLabel!
    @IBOutlet private weak var quantityField: UITextField!
    @IBOutlet private weak var clearButton: UIButton!
    @IBOutlet private weak var calendarHost: AdaptiveView!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var scrollView: UIScrollView!

    private let viewModel: PantryItemEditViewModel
    private var calendarDateBadge: UILabel?
    private var didInstallCalendar = false

    init(viewModel: PantryItemEditViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "PantryItemEditViewController")
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
    }

    override var analyticsScreen: AnalyticsScreen? { .pantryEdit }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.gray6
        titleLabel.text = L10n.tr("pantry.editTitle")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        var closeConfiguration = UIButton.Configuration.filled()
        closeConfiguration.cornerStyle = .capsule
        closeConfiguration.contentInsets = .zero
        closeConfiguration.baseBackgroundColor = AppColor.fillSecondary
        closeConfiguration.baseForegroundColor = AppColor.dynamic(
            light: UIColor(white: 114 / 255, alpha: 1), dark: UIColor(red: 180 / 255, green: 180 / 255, blue: 184 / 255, alpha: 1)
        )
        closeConfiguration.image = UIImage(systemName: "xmark", withConfiguration:
            UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
        closeButton.configuration = closeConfiguration
        closeButton.accessibilityLabel = L10n.tr("common.close")
        OnboardingStyle.applyPressFeedback(closeButton)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        configureFoodCard()
        configureQuantityInput()
        configureCalendarHost()
        OnboardingStyle.stylePrimaryButton(saveButton, title: L10n.tr("pantry.saveChanges"))
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        scrollView.delegate = self
        scrollView.keyboardDismissMode = .onDrag
        scrollView.alwaysBounceVertical = true
        installKeyboardDismissPan()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        installCalendarIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installCalendarIfNeeded()
    }

    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        guard let dateComponents, let date = Calendar.current.date(from: dateComponents) else { return }
        viewModel.updateExpiry(date)
        refreshExpiry()
    }

    @objc private func closeTapped() { viewModel.closeTapped() }

    @objc private func saveTapped() {
        view.endEditing(true)
        viewModel.saveTapped()
    }

    @objc private func quantityChanged() {
        refreshClearButton()
    }

    @objc private func clearTapped() {
        quantityField.text = ""
        refreshClearButton()
        quantityField.becomeFirstResponder()
        reloadQuantityKeyboard()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func configureFoodCard() {
        productCard.useLiveGlass = false
        productCard.applyCardShadow = true
        productCard.showsDropShadow = true
        productCard.designShadowRadius = 16
        productCard.designCornerRadius = 24
        productCard.backgroundColor = AppColor.card
        nameLabel.text = viewModel.nameText.value
        OnboardingStyle.lockFigmaFont(
            nameLabel,
            size: 20,
            weight: .semibold,
            color: AppColor.labelsPrimary,
            kern: -0.45
        )
        nameLabel.applyLineTruncation(lines: 1)
        productImageView.clipsToBounds = true
        productImageView.layer.cornerRadius = .adaptWidth(12)
        productImageView.layer.cornerCurve = .continuous
        productImageView.contentMode = .scaleAspectFill
        productImageView.backgroundColor = AppColor.fillVibrantTertiary
        RemoteImageLoader.shared.display(
            viewModel.imageURL,
            data: viewModel.imageData,
            in: productImageView,
            placeholder: UIImage(systemName: "carrot")
        )
    }

    private func configureQuantityInput() {
        quantityCard.useLiveGlass = false
        quantityCard.applyCardShadow = true
        quantityCard.showsDropShadow = true
        quantityCard.designShadowRadius = 8
        quantityCard.designCornerRadius = 16
        quantityCard.backgroundColor = AppColor.card
        quantityLabel.text = L10n.tr("pantry.quantity")
        OnboardingStyle.lockFigmaFont(
            quantityLabel,
            size: 17,
            weight: .regular,
            color: AppColor.iconSecondary,
            kern: -0.43
        )
        quantityField.borderStyle = .none
        quantityField.backgroundColor = .clear
        quantityField.tintColor = AppColor.teal
        quantityField.clearButtonMode = .never
        quantityField.returnKeyType = .done
        quantityField.keyboardType = .decimalPad
        quantityField.inputAccessoryView = makeQuantityKeyboardDoneBar()
        quantityField.addTarget(self, action: #selector(quantityChanged), for: .editingChanged)
        quantityField.delegate = self
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = AppColor.labelsSecondary.withAlphaComponent(0.3)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        styleQuantity(viewModel.displayedQuantity())
        refreshClearButton()
    }

    private func configureCalendarHost() {
        calendarHost.useLiveGlass = false
        calendarHost.applyCardShadow = true
        calendarHost.showsDropShadow = true
        calendarHost.designShadowRadius = 8
        calendarHost.designCornerRadius = 16
        calendarHost.backgroundColor = AppColor.card
        calendarHost.clipsToBounds = false
        calendarHost.layer.masksToBounds = false
    }

    private func installCalendarIfNeeded() {
        guard !didInstallCalendar else { return }
        guard calendarHost.window != nil else { return }
        guard calendarHost.bounds.width > 1, calendarHost.bounds.height > 1 else { return }
        didInstallCalendar = true
        calendarHost.designCornerRadius = 16

        let header = makeCalendarHeader()
        let separator = UIView()
        separator.backgroundColor = AppColor.hairline
        separator.translatesAutoresizingMaskIntoConstraints = false

        let pickerHost = UIView()
        pickerHost.clipsToBounds = true
        pickerHost.translatesAutoresizingMaskIntoConstraints = false

        let calendarView = UICalendarView()
        calendarView.calendar = .current
        calendarView.locale = .current
        calendarView.tintColor = AppColor.teal
        calendarView.backgroundColor = .clear
        calendarView.wantsDateDecorations = false
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
            calendarView.bottomAnchor.constraint(equalTo: pickerHost.bottomAnchor, constant: -.adaptHeight(8))
        ] + calendarView.horizontalConstraints(in: pickerHost, inset: .adaptWidth(4)))

        if let height = calendarHost.constraints.first(where: { $0.firstAttribute == .height && $0.secondItem == nil }) {
            let headerHeight = CGFloat.adaptHeight(66) + 1 / UIScreen.main.scale
            let pickerInsets = CGFloat.adaptHeight(3) + CGFloat.adaptHeight(8)
            let fittingHeight = headerHeight + pickerInsets + ceil(calendarView.intrinsicContentSize.height)
            if let adaptive = height as? AdaptiveConstraint {
                adaptive.adaptToHeight = false
                adaptive.designConstant = fittingHeight
            } else {
                height.constant = fittingHeight
            }
        }
        let selection = UICalendarSelectionSingleDate(delegate: self)
        calendarView.selectionBehavior = selection
        let start = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date.distantPast
        let end = Calendar.current.date(byAdding: .year, value: 5, to: Date()) ?? Date.distantFuture
        calendarView.availableDateRange = DateInterval(start: start, end: end)
        applyCalendarSelection(selection)
        refreshExpiry()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.applyCalendarSelection(selection)
            let visible = Calendar.current.dateComponents(
                [.calendar, .year, .month, .day],
                from: self.viewModel.expiry.value ?? Date()
            )
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
        titleLabel.attributedText = expiryHeaderTitle()
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let badge = UILabel()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.numberOfLines = 1
        badge.textAlignment = .center
        badge.lineBreakMode = .byTruncatingTail
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

    private func expiryHeaderTitle() -> NSAttributedString {
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
            string: L10n.tr("pantry.expiryDate"),
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: AppColor.labelVibrantPrimary,
                .kern: -0.43
            ]
        ))
        return text
    }

    private func applyCalendarSelection(_ selection: UICalendarSelectionSingleDate) {
        let date = viewModel.expiry.value ?? Date()
        var components = Calendar.current.dateComponents([.calendar, .era, .year, .month, .day], from: date)
        components.calendar = Calendar.current
        selection.selectedDate = components
    }

    private func refreshExpiry() {
        let date = viewModel.expiry.value ?? Date()
        calendarDateBadge?.text = PantryItem.expiryDisplayFormatter.string(from: date)
        if let badge = calendarDateBadge {
            OnboardingStyle.lockFigmaFont(
                badge,
                size: 17,
                weight: .regular,
                color: AppColor.labelsPrimary,
                kern: -0.43
            )
        }
    }

    private func refreshClearButton() {
        let hasText = !(quantityField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        clearButton.isHidden = !hasText
    }

    private func styleQuantity(_ text: String) {
        let font = UIFont.systemFont(ofSize: 17, weight: .medium)
        quantityField.defaultTextAttributes = [
            .font: font,
            .foregroundColor: AppColor.labelsPrimary,
            .kern: -0.43
        ]
        quantityField.font = font
        quantityField.textColor = AppColor.labelsPrimary
        quantityField.typingAttributes = [
            .font: font,
            .foregroundColor: AppColor.labelsPrimary,
            .kern: -0.43
        ]
        quantityField.text = text
        refreshClearButton()
    }

    private func reloadQuantityKeyboard() {
        quantityField.keyboardType = .decimalPad
        quantityField.reloadInputViews()
    }

    private func makeQuantityKeyboardDoneBar() -> UIView {
        OnboardingStyle.makeKeyboardDoneBar(width: view.bounds.width, target: self, action: #selector(dismissKeyboard))
    }

    private func installKeyboardDismissPan() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleKeyboardDismissPan))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    @objc private func handleKeyboardDismissPan(_ pan: UIPanGestureRecognizer) {
        guard quantityField.isFirstResponder else { return }
        if abs(pan.translation(in: view).y) > 8 {
            view.endEditing(true)
        }
    }

    private static func numericQuantityInput(_ text: String) -> String {
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

    private static func isNumericQuantityInput(_ text: String) -> Bool {
        if text.isEmpty { return true }
        let pattern = #"^\d{0,6}([.,]\d{0,2})?$"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }
}

extension PantryItemEditViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard textField === quantityField else { return }
        reloadQuantityKeyboard()
        styleQuantity(viewModel.numericQuantityText())
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard textField === quantityField else { return }
        viewModel.commitQuantity(textField.text ?? "")
        styleQuantity(viewModel.displayedQuantity())
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField === quantityField else { return true }
        let current = textField.text ?? ""
        let next: String
        if let span = Range(range, in: current) {
            next = Self.numericQuantityInput(current.replacingCharacters(in: span, with: string))
        } else {
            next = Self.numericQuantityInput(current + string)
        }
        guard Self.isNumericQuantityInput(next) else { return false }
        textField.text = next
        refreshClearButton()
        return false
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension PantryItemEditViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
}

extension PantryItemEditViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
