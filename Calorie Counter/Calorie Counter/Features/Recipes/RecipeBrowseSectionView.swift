import UIKit

final class RecipeBrowseSectionView: UIView {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var seeMoreButton: UIButton!
    @IBOutlet private weak var cardsScroll: UIScrollView!
    @IBOutlet private weak var cardsStack: UIStackView!

    var onSeeMore: (() -> Void)?
    var onSelect: ((Recipe) -> Void)?
    private(set) var kind: RecipeBrowseSectionKind?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func applySectionChrome(_ section: RecipeBrowseSection) {
        applyHeader(kind: section.id, showsSeeMore: true)
    }

    func configure(_ section: RecipeBrowseSection) {
        applyHeader(kind: section.id, showsSeeMore: true)
        kind = section.id
        let recipes = section.recipes
        recipes.enumerated().forEach { index, recipe in
            upsertCard(recipe, at: index)
        }
        trimCards(to: recipes.count)
    }

    func upsertCard(_ recipe: Recipe, at index: Int) {
        let card: RecipeCardView
        if index < cardsStack.arrangedSubviews.count,
           let existing = cardsStack.arrangedSubviews[index] as? RecipeCardView {
            card = existing
        } else {
            card = RecipeCardView()
            addCard(card)
        }
        card.configure(recipe)
        card.onSelect = { [weak self] in
            self?.onSelect?(recipe)
        }
    }

    func trimCards(to count: Int) {
        while cardsStack.arrangedSubviews.count > count {
            let extra = cardsStack.arrangedSubviews.last!
            cardsStack.removeArrangedSubview(extra)
            extra.removeFromSuperview()
        }
    }

    func showSkeleton(kind: RecipeBrowseSectionKind) {
        applyHeader(kind: kind, showsSeeMore: false)
        self.kind = kind
        cardsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        (0..<RecipeCardGrid.browseSkeletonCardsPerSection).forEach { _ in
            let card = RecipeCardView()
            card.showSkeleton()
            addCard(card)
        }
    }

    @objc
    private func seeMoreTapped() {
        onSeeMore?()
    }

    private func applyHeader(kind: RecipeBrowseSectionKind, showsSeeMore: Bool) {
        self.kind = kind
        titleLabel.text = L10n.tr(kind.titleKey)
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        titleLabel.applyLineTruncation(lines: 1)
        seeMoreButton.setTitle(L10n.tr("recipes.seeMore"), for: .normal)
        seeMoreButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        seeMoreButton.setContentHuggingPriority(.required, for: .horizontal)
        seeMoreButton.setTitleColor(AppColor.tabSelected, for: .normal)
        seeMoreButton.titleLabel?.font = .systemFont(ofSize: .adaptFont(17), weight: .medium)
        seeMoreButton.isHidden = !showsSeeMore
        seeMoreButton.isEnabled = showsSeeMore
    }

    private func addCard(_ card: RecipeCardView) {
        cardsStack.addArrangedSubview(card)
        let width = card.widthAnchor.constraint(equalToConstant: .adaptWidth(181, in: self))
        width.identifier = "responsive-recipe-card-width"
        width.isActive = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = CGFloat.adaptWidth(181, in: self)
        for card in cardsStack.arrangedSubviews {
            if let constraint = card.constraints.first(where: { $0.identifier == "responsive-recipe-card-width" }),
               abs(constraint.constant - width) > 0.5 {
                constraint.constant = width
                card.invalidateIntrinsicContentSize()
            }
        }
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        embedNibContent()
        cardsScroll?.clipsToBounds = false
        cardsScroll?.layer.masksToBounds = false
        cardsStack?.alignment = .top
        cardsStack?.clipsToBounds = false
        seeMoreButton.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)
    }
}
