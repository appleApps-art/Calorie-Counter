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
    /// Sits in the photo slot until the dish picture arrives.
    private let photoSpinner = UIActivityIndicatorView(style: .medium)
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
        OnboardingStyle.lockFigmaFont(nameLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(caloriesLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        nameLabel.applyLineTruncation(lines: 2)
        caloriesLabel.applyLineTruncation(lines: 1)
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.masksToBounds = true
        photoImageView.preferredSymbolConfiguration = nil
        photoImageView.layer.cornerRadius = .adaptWidth(12)
        photoImageView.layer.cornerCurve = .continuous
        // A dish Bity put in the plan (or one saved before it had a photo) has no catalog picture;
        // the same food-image lookup the recipe page uses fills the slot.
        loadPhoto(slot.recipe.imageURL ?? AIAssistantAPIConfiguration.production.foodImageURL(name: slot.recipe.title))
        // The design has a bare teal glyph here, with no button surface behind it.
        swapButton.configuration = nil
        swapButton.setTitle(nil, for: .normal)
        swapButton.setImage(
            OnboardingStyle.symbolImage("arrow.left.arrow.right")?
                .withTintColor(AppColor.teal, renderingMode: .alwaysOriginal),
            for: .normal
        )
        swapButton.backgroundColor = .clear
        swapButton.layer.shadowOpacity = 0
        swapButton.layer.cornerRadius = 0
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

    /// A spinner holds the slot while the picture loads; the fork only shows if there is none.
    private func loadPhoto(_ url: URL?) {
        photoSpinner.startAnimating()
        RemoteImageLoader.shared.display(url, in: photoImageView, placeholder: nil) { [weak self] loaded in
            guard let self else { return }
            self.photoSpinner.stopAnimating()
            guard !loaded else { return }
            RemoteImageLoader.shared.display(nil, in: self.photoImageView, placeholder: UIImage(systemName: "fork.knife"))
            self.photoImageView.tintColor = AppColor.iconSecondary
        }
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
        photoSpinner.hidesWhenStopped = true
        photoSpinner.accessibilityIdentifier = "mealPlan.row.photoSpinner"
        photoSpinner.color = AppColor.iconSecondary
        photoSpinner.translatesAutoresizingMaskIntoConstraints = false
        photoImageView.backgroundColor = AppColor.fillQuaternary
        cardView.addSubview(photoSpinner)
        NSLayoutConstraint.activate([
            photoSpinner.centerXAnchor.constraint(equalTo: photoImageView.centerXAnchor),
            photoSpinner.centerYAnchor.constraint(equalTo: photoImageView.centerYAnchor)
        ])
        swapSpinner.hidesWhenStopped = true
        swapSpinner.accessibilityIdentifier = "mealPlan.row.swapSpinner"
        // Pinned to the arrow rather than placed by hand: laying it out by frame put it outside the
        // card, because the card has no size yet when the row lays itself out.
        swapSpinner.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(swapSpinner)
        NSLayoutConstraint.activate([
            swapSpinner.centerXAnchor.constraint(equalTo: swapButton.centerXAnchor),
            swapSpinner.centerYAnchor.constraint(equalTo: swapButton.centerYAnchor)
        ])
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

}

extension MealPlanMealRowView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = touch.view else { return true }
        return !view.isDescendant(of: swapButton) && view !== swapButton
    }
}
