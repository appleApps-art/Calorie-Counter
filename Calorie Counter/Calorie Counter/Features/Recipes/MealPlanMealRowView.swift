import UIKit

final class MealPlanMealRowView: UIView {
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var nameLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesLabel: AdaptiveLabel!
    @IBOutlet private weak var swapButton: UIButton!

    var onSwap: (() -> Void)?
    var onOpen: (() -> Void)?

    private let swapSpinner = UIActivityIndicatorView(style: .medium)
    private var openTap: UITapGestureRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ slot: MealPlanSlot, isSwapping: Bool) {
        nameLabel.text = slot.recipe.title
        caloriesLabel.text = slot.recipe.calories.map { L10n.format("recipes.kcal", Int($0.rounded())) } ?? ""
        OnboardingStyle.lockFigmaFont(nameLabel, size: 20, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.45)
        OnboardingStyle.lockFigmaFont(caloriesLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        nameLabel.applyLineTruncation(lines: 2)
        caloriesLabel.applyLineTruncation(lines: 1)
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.masksToBounds = true
        photoImageView.preferredSymbolConfiguration = nil
        photoImageView.layer.cornerRadius = .adaptWidth(12)
        photoImageView.layer.cornerCurve = .continuous
        RemoteImageLoader.shared.display(
            slot.recipe.imageURL,
            in: photoImageView,
            placeholder: UIImage(systemName: "fork.knife")
        )
        OnboardingStyle.styleGlassSymbolButton(
            swapButton,
            systemName: "arrow.left.arrow.right",
            foregroundColor: AppColor.teal,
            liveGlass: false
        )
        swapButton.tintColor = AppColor.teal
        swapButton.isHidden = isSwapping
        swapButton.isEnabled = !isSwapping
        swapSpinner.color = AppColor.teal
        if isSwapping {
            swapSpinner.startAnimating()
        } else {
            swapSpinner.stopAnimating()
        }
        openTap?.isEnabled = !isSwapping
    }

    @objc
    private func swapTapped() {
        onSwap?()
    }

    @objc
    private func openTapped() {
        onOpen?()
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        embedNibContent()
        cardView.useLiveGlass = false
        cardView.applyCardShadow = true
        cardView.cardFillColor = AppColor.backgroundsPrimaryElevated
        cardView.clipsToBounds = false
        cardView.isUserInteractionEnabled = true
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        caloriesLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        caloriesLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.superview?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.superview?.setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        swapButton.addTarget(self, action: #selector(swapTapped), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: self, action: #selector(openTapped))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        cardView.addGestureRecognizer(tap)
        openTap = tap
        swapSpinner.hidesWhenStopped = true
        cardView.addSubview(swapSpinner)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        swapSpinner.sizeToFit()
        swapSpinner.center = swapButton.center
    }
}

extension MealPlanMealRowView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = touch.view else { return true }
        return !view.isDescendant(of: swapButton) && view !== swapButton
    }
}
