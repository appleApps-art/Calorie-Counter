import UIKit

final class RecipeCardView: UIView {
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var kcalBadge: AdaptiveView!
    @IBOutlet private weak var kcalIconView: UIImageView!
    @IBOutlet private weak var kcalLabel: AdaptiveLabel!

    var onSelect: (() -> Void)?

    private let cardShimmer = ShimmerView()
    private var isShowingSkeleton = false
    private var coverTitle: String?
    private var renderedCoverSize: CGSize = .zero
    private var lastIntrinsicHeight: CGFloat = 0

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: ceil(.adaptHeight(100, in: self) + 42))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ recipe: Recipe) {
        configure(
            title: recipe.title,
            imageURL: recipe.imageURL,
            badgeText: RecipesViewModel.calorieBadgeText(for: recipe)
        )
    }

    func configure(_ plan: MealPlan) {
        configure(title: plan.title, imageURL: nil, badgeText: nil)
        // A plan has no single dish to show, so its card carries its name instead.
        coverTitle = plan.title
        renderCoverIfNeeded()
    }

    private func renderCoverIfNeeded() {
        guard let coverTitle else { return }
        let size = imageView.bounds.size
        guard size.width > 1, size.height > 1, size != renderedCoverSize else { return }
        // The photo is laid out after the card, so this pass can still read the nib's placeholder
        // frame; drawing the name into it once made the title look blown up and cut off.
        guard size.width <= bounds.width, size.height <= bounds.height else {
            DispatchQueue.main.async { [weak self] in self?.renderCoverIfNeeded() }
            return
        }
        renderedCoverSize = size
        imageView.contentMode = .scaleAspectFill
        imageView.image = MealPlanCover.image(title: coverTitle, size: size, traits: traitCollection)
    }

    func showSkeleton() {
        onSelect = nil
        isShowingSkeleton = true
        isUserInteractionEnabled = false
        RemoteImageLoader.shared.display(nil, in: imageView, placeholder: nil)
        titleLabel.text = nil
        titleLabel.attributedText = nil
        titleLabel.backgroundColor = .clear
        imageView.image = nil
        imageView.backgroundColor = .clear
        imageView.isHidden = true
        titleLabel.isHidden = true
        kcalBadge.isHidden = true
        applyCardShimmerChrome()
        cardView.bringSubviewToFront(cardShimmer)
        cardShimmer.start()
    }

    private func configure(title: String, imageURL: URL?, badgeText: String?, fallbackURL: URL? = nil) {
        coverTitle = nil
        renderedCoverSize = .zero
        isShowingSkeleton = false
        cardShimmer.stop()
        isUserInteractionEnabled = true
        imageView.isHidden = false
        titleLabel.isHidden = false
        titleLabel.backgroundColor = .clear
        titleLabel.clipsToBounds = false
        titleLabel.layer.cornerRadius = 0
        titleLabel.text = title
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(titleLabel, size: 16, weight: .regular, color: AppColor.labelsPrimary, kern: -0.31)
        applyTitleStyle()
        applyPhotoChrome()
        imageView.contentMode = .scaleAspectFill
        imageView.preferredSymbolConfiguration = nil
        imageView.backgroundColor = AppColor.fillQuaternary
        imageView.setContentHuggingPriority(.init(1), for: .vertical)
        imageView.setContentHuggingPriority(.init(1), for: .horizontal)
        imageView.setContentCompressionResistancePriority(.init(1), for: .vertical)
        imageView.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        RemoteImageLoader.shared.display(
            imageURL,
            in: imageView,
            placeholder: UIImage(systemName: "fork.knife"),
            fallbackURL: fallbackURL
        )
        kcalBadge.isHidden = badgeText?.isEmpty != false
        kcalLabel.text = badgeText
        OnboardingStyle.lockFigmaFont(kcalLabel, size: 11, weight: .regular, color: .white, kern: 0.06)
        kcalIconView.image = UIImage(systemName: "flame", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11))
        kcalIconView.tintColor = .white

    }

    @objc
    private func tapped() {
        onSelect?()
    }

    private func applyTitleStyle() {
        titleLabel.accessibilityIdentifier = "recipeCard.title"
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.minimumScaleFactor = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        guard let attributed = titleLabel.attributedText, attributed.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.minimumLineHeight = 21
        paragraph.maximumLineHeight = 21
        mutable.addAttribute(
            .paragraphStyle,
            value: paragraph,
            range: NSRange(location: 0, length: mutable.length)
        )
        titleLabel.attributedText = mutable
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        embedNibContent()
        cardView.useLiveGlass = false
        cardView.applyCardShadow = true
        cardView.showsDropShadow = true
        cardView.showsHairlineBorder = false
        cardView.cardFillColor = AppColor.backgroundsPrimaryElevated
        cardView.cardShadowOpacity = 0.1
        cardView.designShadowRadius = 4
        // Keep two readable text lines at every width, independent of image scaling.
        titleLabel.constraints.filter { $0.firstAttribute == .height }.forEach { $0.isActive = false }
        titleLabel.heightAnchor.constraint(equalToConstant: 42).isActive = true
        kcalBadge.useLiveGlass = false
        kcalBadge.applyCardShadow = false
        kcalBadge.backgroundColor = .black
        kcalBadge.adaptCornerRadius = true
        kcalBadge.designCornerRadius = 10
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
        installShimmer()
    }

    private func installShimmer() {
        cardShimmer.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(cardShimmer)
        NSLayoutConstraint.activate([
            cardShimmer.topAnchor.constraint(equalTo: cardView.topAnchor),
            cardShimmer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            cardShimmer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            cardShimmer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])
        cardShimmer.stop()
    }

    private func applyPhotoChrome() {
        imageView.clipsToBounds = true
        imageView.layer.masksToBounds = true
        imageView.layer.cornerCurve = .continuous
        imageView.layer.cornerRadius = .adaptWidth(Self.photoCornerRadius)
    }

    private func applyCardShimmerChrome() {
        let radius = cardView.layer.cornerRadius > 0
            ? cardView.layer.cornerRadius
            : .adaptWidth(Self.cardCornerRadius)
        cardShimmer.apply(cornerRadius: radius)
    }

    private static let photoCornerRadius: CGFloat = 11
    private static let cardCornerRadius: CGFloat = 16

    override func layoutSubviews() {
        super.layoutSubviews()
        let currentHeight = intrinsicContentSize.height
        if abs(currentHeight - lastIntrinsicHeight) > 0.5 {
            lastIntrinsicHeight = currentHeight
            invalidateIntrinsicContentSize()
        }
        applyPhotoChrome()
        if isShowingSkeleton, UIView.inheritedAnimationDuration == 0 {
            applyCardShimmerChrome()
        }
        renderCoverIfNeeded()
        guard imageView.image?.isSymbolImage != true else { return }
        imageView.contentMode = .scaleAspectFill
    }
}

enum RecipeCardGrid {
    static let browseSkeletonCardsPerSection = 2
    static let initialSkeletonCount = 10
    static let paginationSkeletonCount = 4
    static let skeletonRowTag = 914_001

    static func appendCards(
        to stack: UIStackView,
        count: Int,
        skeleton: Bool = false,
        configure: (Int, RecipeCardView) -> Void
    ) {
        stride(from: 0, to: count, by: 2).forEach { index in
            let row = UIStackView()
            row.axis = .horizontal
            row.distribution = .fillEqually
            row.spacing = .adaptWidth(8)
            if skeleton {
                row.tag = skeletonRowTag
            }
            let left = RecipeCardView()
            configure(index, left)
            row.addArrangedSubview(left)
            if index + 1 < count {
                let right = RecipeCardView()
                configure(index + 1, right)
                row.addArrangedSubview(right)
            } else {
                row.addArrangedSubview(UIView())
            }
            stack.addArrangedSubview(row)
        }
    }

    static func appendSkeletonCards(to stack: UIStackView, count: Int) {
        appendCards(to: stack, count: count, skeleton: true) { _, card in
            card.showSkeleton()
        }
    }

    static func removeSkeletonRows(from stack: UIStackView) {
        stack.arrangedSubviews.filter { $0.tag == skeletonRowTag }.forEach { row in
            stack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
    }
}
