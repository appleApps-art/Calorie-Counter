import UIKit

enum SettingsRowAccessory {
    case disclosure
    case copy
    case checkmark
    case none
}

final class SettingsRowView: UIView {
    @IBOutlet private weak var iconBackgroundView: UIView!
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var iconWidthConstraint: AdaptiveConstraint!
    @IBOutlet private weak var iconHeightConstraint: AdaptiveConstraint!
    @IBOutlet private weak var titleToIconConstraint: AdaptiveConstraint!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var detailLabel: AdaptiveLabel!
    @IBOutlet private weak var copyButton: UIButton!
    @IBOutlet private weak var copyWidthConstraint: AdaptiveConstraint!
    @IBOutlet private weak var copyLeadingConstraint: AdaptiveConstraint!
    @IBOutlet private weak var chevronView: UIImageView!
    @IBOutlet private weak var chevronWidthConstraint: AdaptiveConstraint!
    @IBOutlet private weak var chevronLeadingConstraint: AdaptiveConstraint!
    @IBOutlet private weak var checkmarkView: UIImageView!
    @IBOutlet private weak var checkWidthConstraint: AdaptiveConstraint!
    @IBOutlet private weak var checkLeadingConstraint: AdaptiveConstraint!
    @IBOutlet private weak var segmentedControl: UISegmentedControl!
    @IBOutlet private weak var toggleSwitch: UISwitch!
    @IBOutlet private weak var separatorView: UIView!

    var onTap: (() -> Void)?
    var onCopy: (() -> Void)?
    var onUnitsChanged: ((Bool) -> Void)?
    var onToggleChanged: ((Bool) -> Void)?

    private var iconCornerRadius: CGFloat = 15
    private var titleBeforeUnits: NSLayoutConstraint?
    private var titleBeforeToggle: NSLayoutConstraint?

    private var copyReset: DispatchWorkItem?
    private var originalDetail = ""
    private var compactDetailWidth: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        iconBackgroundView.layer.cornerRadius = .adaptWidth(iconCornerRadius)
        iconBackgroundView.layer.cornerCurve = .continuous
    }

    func configure(
        title: String,
        detail: String = "",
        symbolName: String? = nil,
        image: UIImage? = nil,
        circledIcon: Bool = false,
        accessory: SettingsRowAccessory = .disclosure,
        showsSeparator: Bool,
        iconColor: UIColor = AppColor.labelsPrimary,
        separatorColor: UIColor = AppColor.hairline
    ) {
        copyReset?.cancel()
        originalDetail = detail
        titleLabel.text = title
        detailLabel.text = detail
        detailLabel.isHidden = detail.isEmpty
        separatorView.isHidden = !showsSeparator
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        OnboardingStyle.lockFigmaFont(
            detailLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsSecondary,
            kern: -0.43
        )
        detailLabel.applyWrapping()
        detailLabel.textAlignment = .right
        titleLabel.applyWrapping()
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        titleLabel.adjustsFontSizeToFitWidth = false
        if let image {
            showIconWrap(size: 30, cornerRadius: 8, fill: nil, titleSpacing: 16)
            iconView.image = image
            iconView.tintColor = nil
            iconView.contentMode = .scaleAspectFill
        } else if let symbolName {
            if circledIcon {
                showIconWrap(size: 30, cornerRadius: 15, fill: AppColor.fillSecondary, titleSpacing: 16)
                iconView.image = OnboardingStyle.symbol(symbolName, pointSize: 15, weight: .regular)
            } else {
                showIconWrap(size: 28, cornerRadius: 0, fill: nil, titleSpacing: 8)
                iconView.image = OnboardingStyle.symbol(symbolName, pointSize: 22, weight: .regular)
            }
            iconView.tintColor = iconColor
            iconView.contentMode = .center
        } else {
            hideIconWrap()
        }
        segmentedControl.isHidden = true
        toggleSwitch.isHidden = true
        applyAccessory(accessory)
        separatorView.backgroundColor = separatorColor
        accessibilityLabel = [title, detail].filter { !$0.isEmpty }.joined(separator: ", ")
        isAccessibilityElement = true
        accessibilityTraits = accessory == .none ? .staticText : .button
    }

    func useSingleLineLayout() {
        titleLabel.applyLineTruncation(lines: 1)
        detailLabel.applyLineTruncation(lines: 1)
        titleLabel.setContentCompressionResistancePriority(UILayoutPriority(copyButton.isHidden ? 748 : 751), for: .horizontal)
        detailLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        if compactDetailWidth == nil, let content = detailLabel.superview {
            compactDetailWidth = detailLabel.widthAnchor.constraint(lessThanOrEqualTo: content.widthAnchor, multiplier: 0.45)
        }
        compactDetailWidth?.isActive = true
    }

    /// Reserve the checkmark's space even when unselected so selection cannot reflow text.
    func setOptionSelected(_ selected: Bool) {
        checkmarkView.alpha = selected ? 1 : 0
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    func setShowsSeparator(_ shows: Bool) {
        separatorView.isHidden = !shows
    }

    func configureUnits(isMetric: Bool) {
        applyAccessory(.none)
        titleBeforeUnits?.isActive = true
        segmentedControl.isHidden = false
        toggleSwitch.isHidden = true
        detailLabel.isHidden = true
        segmentedControl.removeAllSegments()
        segmentedControl.insertSegment(withTitle: L10n.tr("settings.units.metric"), at: 0, animated: false)
        segmentedControl.insertSegment(withTitle: L10n.tr("settings.units.imperial"), at: 1, animated: false)
        segmentedControl.selectedSegmentIndex = isMetric ? 0 : 1
        segmentedControl.selectedSegmentTintColor = AppColor.teal
        segmentedControl.backgroundColor = AppColor.fillQuaternary
        segmentedControl.setTitleTextAttributes(
            [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: AppColor.labelsPrimary
            ],
            for: .normal
        )
        segmentedControl.setTitleTextAttributes(
            [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: AppColor.onAccent
            ],
            for: .selected
        )
        accessibilityTraits = .adjustable
    }

    func configureToggle(isOn: Bool) {
        applyAccessory(.none)
        titleBeforeToggle?.isActive = true
        toggleSwitch.isHidden = false
        segmentedControl.isHidden = true
        detailLabel.isHidden = true
        toggleSwitch.isOn = isOn
        toggleSwitch.onTintColor = AppColor.teal
        accessibilityTraits = .button
        accessibilityValue = isOn ? "1" : "0"
    }

    @objc
    private func handleTap() {
        guard segmentedControl.isHidden, toggleSwitch.isHidden else { return }
        if !copyButton.isHidden { copyTapped(); return }
        Haptics.light()
        onTap?()
    }

    @objc
    private func copyTapped() {
        guard let onCopy else { return }
        onCopy()
        Haptics.success()
        copyReset?.cancel()
        let message = L10n.tr("settings.userIDCopied")
        detailLabel.text = message
        copyButton.setImage(OnboardingStyle.symbol("checkmark", pointSize: 17, weight: .semibold), for: .normal)
        UIAccessibility.post(notification: .announcement, argument: message)
        let reset = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.detailLabel.text = self.originalDetail
            self.applyAccessory(.copy)
        }
        copyReset = reset
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: reset)
    }

    @objc
    private func unitsChanged() {
        Haptics.selection()
        onUnitsChanged?(segmentedControl.selectedSegmentIndex == 0)
    }

    @objc
    private func toggleChanged() {
        Haptics.selection()
        onToggleChanged?(toggleSwitch.isOn)
    }

    private func showIconWrap(size: CGFloat, cornerRadius: CGFloat, fill: UIColor?, titleSpacing: CGFloat) {
        iconBackgroundView.isHidden = false
        iconView.isHidden = false
        iconWidthConstraint.designConstant = size
        iconHeightConstraint.designConstant = size
        titleToIconConstraint.designConstant = titleSpacing
        iconBackgroundView.backgroundColor = fill ?? .clear
        iconBackgroundView.clipsToBounds = true
        iconCornerRadius = cornerRadius
        iconBackgroundView.layer.cornerRadius = .adaptWidth(cornerRadius)
        iconBackgroundView.layer.cornerCurve = .continuous
    }

    private func hideIconWrap() {
        iconBackgroundView.isHidden = true
        iconView.isHidden = true
        iconView.image = nil
        iconWidthConstraint.designConstant = 0
        iconHeightConstraint.designConstant = 0
        titleToIconConstraint.designConstant = 0
        iconBackgroundView.backgroundColor = .clear
    }

    private func applyAccessory(_ accessory: SettingsRowAccessory) {
        titleBeforeUnits?.isActive = false
        titleBeforeToggle?.isActive = false
        let showCopy = accessory == .copy
        let showCheck = accessory == .checkmark
        let showChevron = accessory == .disclosure
        copyButton.isHidden = !showCopy
        checkmarkView.isHidden = !showCheck
        chevronView.isHidden = !showChevron
        copyWidthConstraint.designConstant = showCopy ? 22 : 0
        copyLeadingConstraint.designConstant = showCopy ? 8 : 0
        checkWidthConstraint.designConstant = showCheck ? 22 : 0
        checkLeadingConstraint.designConstant = showCheck ? 8 : 0
        chevronWidthConstraint.designConstant = showChevron ? 12 : 0
        chevronLeadingConstraint.designConstant = showChevron ? 8 : 0
        if showChevron {
            chevronView.image = OnboardingStyle.symbol("chevron.right", pointSize: 13, weight: .medium)?
                .withTintColor(AppColor.labelsSecondary, renderingMode: .alwaysOriginal)
        }
        if showCheck {
            checkmarkView.image = OnboardingStyle.symbol("checkmark", pointSize: 17, weight: .regular)?
                .withTintColor(AppColor.teal, renderingMode: .alwaysOriginal)
        }
        if showCopy {
            copyButton.setImage(
                OnboardingStyle.symbol("doc.on.doc", pointSize: 17, weight: .regular)?
                    .withTintColor(AppColor.teal, renderingMode: .alwaysOriginal),
                for: .normal
            )
            copyButton.tintColor = AppColor.teal
        }
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        titleBeforeUnits = titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: segmentedControl.leadingAnchor, constant: -8)
        titleBeforeToggle = titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: toggleSwitch.leadingAnchor, constant: -8)
        if let content = titleLabel.superview {
            // Keep the standard row height when content fits, and let longer
            // translations grow vertically instead of truncating instructions.
            content.constraints.first(where: { $0.identifier == "rh" || ($0.firstItem === content && $0.firstAttribute == .height && $0.secondItem == nil) })?.priority = .defaultLow
            NSLayoutConstraint.activate([
                content.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
                titleLabel.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: 10),
                titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -10),
                detailLabel.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: 10),
                detailLabel.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -10)
            ])
        }
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        segmentedControl.addTarget(self, action: #selector(unitsChanged), for: .valueChanged)
        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }
}
