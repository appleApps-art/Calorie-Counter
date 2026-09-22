import UIKit

final class WantToCookRowView: UIView {
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var chevronButton: UIButton!

    private let spinner = UIActivityIndicatorView(style: .medium)

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(recipe: Recipe?, loading: Bool, unavailable: Bool) {
        titleLabel.text = recipe?.title ?? L10n.tr(loading ? "product.insight.recipeLoading" : "product.insight.findRecipe")
        subtitleLabel.text = L10n.tr(unavailable ? "product.insight.recipeRetry" : "product.insight.cookWithIngredient")
        accessibilityLabel = titleLabel.text
        accessibilityHint = subtitleLabel.text
        isUserInteractionEnabled = !loading
        if loading || recipe?.imageURL != nil { spinner.startAnimating() } else { spinner.stopAnimating() }
        // Until a recipe with its photo is found, the row keeps its book icon instead of a blank.
        RemoteImageLoader.shared.display(recipe?.imageURL, in: iconImageView, placeholder: Self.placeholderIcon) { [weak self] _ in
            self?.spinner.stopAnimating()
        }
        if loading { spinner.startAnimating() }
        chevronButton.isHidden = loading
    }

    private static var placeholderIcon: UIImage? {
        OnboardingStyle.symbol("book", pointSize: 22)?.withTintColor(
            AppColor.iconSecondary,
            renderingMode: .alwaysOriginal
        )
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        if let card = subviews.first as? AdaptiveView {
            card.useLiveGlass = false
            card.applyCardShadow = true
            card.backgroundColor = AppColor.card
        }
        titleLabel.text = L10n.tr("product.details.wantToCook")
        subtitleLabel.text = L10n.tr("product.details.wantToCookSubtitle")
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 15,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary
        )
        OnboardingStyle.lockFigmaFont(
            subtitleLabel,
            size: 12,
            weight: .medium,
            color: AppColor.iconSecondary
        )
        iconImageView.image = Self.placeholderIcon
        iconImageView.tintColor = AppColor.iconSecondary
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layer.cornerRadius = .adaptWidth(12)
        spinner.hidesWhenStopped = true
        spinner.color = AppColor.iconSecondary
        spinner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: iconImageView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor)
        ])
        OnboardingStyle.stylePlainSymbolButton(
            chevronButton,
            systemName: "chevron.right",
            foregroundColor: AppColor.iconSecondary
        )
        chevronButton.isUserInteractionEnabled = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped))
        addGestureRecognizer(tap)
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = L10n.tr("product.details.wantToCook")
        accessibilityHint = L10n.tr("product.details.wantToCookSubtitle")
    }

    @objc
    private func rowTapped() {
        Haptics.light()
        onTap?()
    }
}
