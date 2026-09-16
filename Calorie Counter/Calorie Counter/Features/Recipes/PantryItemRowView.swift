import UIKit

final class PantryItemRowView: UIView {
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var accessoryButton: UIButton!
    @IBOutlet private weak var separator: UIView!

    var onAccessory: (() -> Void)?
    var onSelect: (() -> Void)?

    private var isSelecting = false
    private var isSelected = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ item: PantryItem, selecting: Bool, selected: Bool, showsSeparator: Bool) {
        titleLabel.text = item.name
        subtitleLabel.text = item.subtitle
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(subtitleLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        titleLabel.applyLineTruncation(lines: 1)
        subtitleLabel.applyLineTruncation(lines: 1)
        imageView.clipsToBounds = true
        imageView.layer.cornerCurve = .continuous
        imageView.layer.cornerRadius = .adaptWidth(10)
        imageView.backgroundColor = AppColor.fillVibrantTertiary
        RemoteImageLoader.shared.display(
            item.imageURL,
            data: item.imageData,
            in: imageView,
            placeholder: UIImage(systemName: "carrot")
        )
        separator.isHidden = !showsSeparator
        separator.backgroundColor = AppColor.hairline
        isSelecting = selecting
        isSelected = selected
        applyAccessory()
    }

    @objc private func accessoryTapped() { onAccessory?() }
    @objc private func tapped() { onSelect?() }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        accessoryButton.addTarget(self, action: #selector(accessoryTapped), for: .touchUpInside)
        accessoryButton.setContentHuggingPriority(.required, for: .horizontal)
        accessoryButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        accessoryButton.setContentHuggingPriority(.required, for: .vertical)
        accessoryButton.setContentCompressionResistancePriority(.required, for: .vertical)
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: PantryItemRowView, _) in
            view.applyAccessory()
        }
    }

    private func applyAccessory() {
        if isSelecting {
            accessoryButton.setImage(nil, for: .normal)
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .capsule
            config.contentInsets = .zero
            if isSelected {
                config.baseBackgroundColor = AppColor.teal
                config.background.backgroundColor = AppColor.teal
                config.baseForegroundColor = AppColor.onAccent
                config.image = UIImage(
                    systemName: "checkmark",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
                )?.withTintColor(AppColor.onAccent, renderingMode: .alwaysOriginal)
            } else {
                config.baseBackgroundColor = AppColor.fillQuaternary
                config.background.backgroundColor = AppColor.fillQuaternary
                config.background.strokeColor = AppColor.fillSecondary
                config.background.strokeWidth = 1
                config.baseForegroundColor = AppColor.labelsSecondary
                config.image = nil
            }
            accessoryButton.configuration = config
            accessoryButton.backgroundColor = .clear
            accessoryButton.tintColor = isSelected ? AppColor.onAccent : AppColor.labelsSecondary
            accessoryButton.clipsToBounds = true
            accessoryButton.layer.masksToBounds = true
            accessoryButton.layer.cornerCurve = .continuous
            accessoryButton.layer.cornerRadius = .adaptWidth(16)
            accessoryButton.layer.borderWidth = 0
            accessoryButton.layer.borderColor = nil
            accessoryButton.layer.shadowOpacity = 0
        } else {
            accessoryButton.configuration = nil
            accessoryButton.backgroundColor = .clear
            accessoryButton.clipsToBounds = false
            accessoryButton.layer.masksToBounds = false
            accessoryButton.layer.borderWidth = 0
            accessoryButton.layer.borderColor = nil
            accessoryButton.layer.cornerRadius = 0
            accessoryButton.layer.shadowOpacity = 0
            accessoryButton.setImage(
                OnboardingStyle.symbol("pencil", pointSize: 17, weight: .regular),
                for: .normal
            )
            accessoryButton.tintColor = AppColor.iconSecondary
        }
    }
}
