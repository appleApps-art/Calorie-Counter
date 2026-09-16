import UIKit

final class FoodItemRowView: UIControl, UIGestureRecognizerDelegate {
    @IBOutlet private weak var photoView: AdaptiveView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var detailLabel: AdaptiveLabel!
    @IBOutlet private weak var checkButton: UIButton!

    private(set) var itemID: UUID?
    var onToggle: ((UUID) -> Void)?
    var onSelect: ((UUID) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ item: HomeFoodItem, imageLoader: RemoteImageLoader = .shared) {
        itemID = item.id
        let strike: NSUnderlineStyle.RawValue = item.isEaten ? NSUnderlineStyle.single.rawValue : 0
        titleLabel.attributedText = NSAttributedString(
            string: item.name,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .regular),
                .foregroundColor: AppColor.labelsPrimary,
                .kern: -0.43,
                .strikethroughStyle: strike
            ]
        )
        detailLabel.attributedText = NSAttributedString(
            string: item.detailText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: AppColor.labelsSecondary,
                .kern: -0.23,
                .strikethroughStyle: strike
            ]
        )
        titleLabel.applyLineTruncation(lines: 1)
        detailLabel.applyLineTruncation(lines: 1)
        photoView.backgroundColor = AppColor.fillVibrantTertiary
        photoView.useLiveGlass = false
        photoView.clipsToBounds = true
        photoView.layer.masksToBounds = true
        photoImageView.clipsToBounds = true
        photoImageView.layer.cornerCurve = .continuous
        photoImageView.layer.cornerRadius = .adaptWidth(11)
        photoView.bringSubviewToFront(photoImageView)
        imageLoader.display(
            item.imageURL,
            data: item.imageData,
            in: photoImageView,
            placeholder: OnboardingStyle.symbol("photo", pointSize: 16)?.withTintColor(
                AppColor.labelsSecondary,
                renderingMode: .alwaysOriginal
            ),
            fallbackURL: AIAssistantAPIConfiguration.production.foodImageURL(name: item.name)
        )
        styleCheck(eaten: item.isEaten)
    }

    @IBAction private func checkTapped() {
        guard let itemID else { return }
        onToggle?(itemID)
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        checkButton?.addTarget(self, action: #selector(checkTapped), for: .touchUpInside)
        checkButton?.controlHaptic = .selection
        let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = touch.view, let checkButton else { return true }
        return !view.isDescendant(of: checkButton)
    }

    @objc
    private func rowTapped() {
        guard let itemID else { return }
        Haptics.light()
        onSelect?(itemID)
    }

    private func styleCheck(eaten: Bool) {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.contentInsets = .zero
        config.background.backgroundInsets = NSDirectionalEdgeInsets(
            top: .adaptHeight(6), leading: .adaptWidth(6),
            bottom: .adaptHeight(6), trailing: .adaptWidth(6)
        )
        if eaten {
            config.baseBackgroundColor = AppColor.teal
            config.background.backgroundColor = AppColor.teal
            config.baseForegroundColor = .white
            config.image = UIImage(
                systemName: "checkmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: .adaptFont(14), weight: .semibold)
            )?.withTintColor(.white, renderingMode: .alwaysOriginal)
        } else {
            config.baseBackgroundColor = AppColor.fillQuaternary
            config.background.backgroundColor = AppColor.fillQuaternary
            config.background.strokeColor = AppColor.fillSecondary
            config.background.strokeWidth = 1
            config.baseForegroundColor = AppColor.labelsSecondary
            config.image = nil
        }
        checkButton.configuration = config
        checkButton.backgroundColor = .clear
        checkButton.tintColor = eaten ? .white : AppColor.labelsSecondary
        checkButton.clipsToBounds = true
        checkButton.layer.masksToBounds = true
        checkButton.layer.cornerCurve = .continuous
        checkButton.layer.cornerRadius = .adaptWidth(22)
        checkButton.layer.shadowOpacity = 0
    }
}
