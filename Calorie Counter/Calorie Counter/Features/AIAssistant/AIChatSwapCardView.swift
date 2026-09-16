import UIKit

final class AIChatSwapCardView: UIView {
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var originalCardView: AdaptiveView!
    @IBOutlet private weak var originalImageView: UIImageView!
    @IBOutlet private weak var originalTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var originalDetailLabel: AdaptiveLabel!
    @IBOutlet private weak var alternativeCardView: AdaptiveView!
    @IBOutlet private weak var alternativeImageView: UIImageView!
    @IBOutlet private weak var alternativeTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var alternativeDetailLabel: AdaptiveLabel!
    @IBOutlet private weak var arrowView: UIImageView!
    @IBOutlet private weak var applyButton: UIButton!
    @IBOutlet private weak var moreButton: UIButton!

    private var textHeightConstraints: [NSLayoutConstraint] = []

    var onApply: (() -> Void)?
    var onSeeMore: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ proposal: FoodSwapProposal) {
        originalTitleLabel.text = proposal.original.name
        originalDetailLabel.text = detail(for: proposal.original)
        alternativeTitleLabel.text = proposal.alternative.name
        alternativeDetailLabel.text = detail(for: proposal.alternative)
        [originalTitleLabel, alternativeTitleLabel].forEach {
            OnboardingStyle.lockFigmaFont($0, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        }
        [originalDetailLabel, alternativeDetailLabel].forEach {
            OnboardingStyle.lockFigmaFont($0, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        }
        for (label, constraint) in zip(
            [originalTitleLabel, alternativeTitleLabel, originalDetailLabel, alternativeDetailLabel],
            textHeightConstraints
        ) {
            guard let label else { continue }
            label.applyLineTruncation(lines: 2)
            if let text = label.attributedText {
                let truncated = NSMutableAttributedString(attributedString: text)
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                paragraph.lineBreakMode = .byTruncatingTail
                truncated.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: truncated.length))
                label.attributedText = truncated
            }
            label.lineBreakMode = .byTruncatingTail
            constraint.constant = ceil(label.font.lineHeight * 2)
        }
        displayPhoto(proposal.original.imageURL, in: originalImageView)
        displayPhoto(proposal.alternative.imageURL, in: alternativeImageView)
        [originalCardView, alternativeCardView].forEach { card in
            card.applyCardShadow = true
            card.showsDropShadow = false
            card.showsHairlineBorder = true
            card.useLiveGlass = false
        }
        arrowView.image = OnboardingStyle.symbol("arrow.right", pointSize: 14)?.withTintColor(
            AppColor.labelsPrimary,
            renderingMode: .alwaysOriginal
        )
        arrowView.contentMode = .center
        cardView.backgroundColor = OnboardingStyle.fillQuaternary
        cardView.applyCardShadow = false
        cardView.useLiveGlass = false
        OnboardingStyle.stylePrimaryButton(applyButton, title: L10n.tr("ai.chat.useSwap"))
        moreButton.setTitle(L10n.tr("ai.chat.seeMoreOptions"), for: .normal)
        OnboardingStyle.styleSecondaryButton(moreButton, title: L10n.tr("ai.chat.seeMoreOptions"))
        moreButton.setTitleColor(AppColor.iconSecondary, for: .normal)
        moreButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
    }

    @objc
    private func applyTapped() {
        onApply?()
    }

    @objc
    private func moreTapped() {
        onSeeMore?()
    }

    private func detail(for item: FoodSwapItem) -> String {
        if let portion = item.portionLabel, !portion.isEmpty {
            return L10n.format("ai.chat.swap.detail", portion, Int(item.calories.rounded()))
        }
        return L10n.format("ai.chat.kcal", Int(item.calories.rounded()))
    }

    private func displayPhoto(_ url: URL?, in imageView: UIImageView) {
        imageView.clipsToBounds = true
        imageView.layer.cornerCurve = .continuous
        imageView.layer.cornerRadius = .adaptWidth(11)
        imageView.backgroundColor = AppColor.fillSecondary
        RemoteImageLoader.shared.display(
            url,
            in: imageView,
            placeholder: OnboardingStyle.symbol("photo", pointSize: 22)?.withTintColor(
                AppColor.labelsSecondary,
                renderingMode: .alwaysOriginal
            )
        )
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        textHeightConstraints = [originalTitleLabel, alternativeTitleLabel, originalDetailLabel, alternativeDetailLabel].compactMap { label in
            label?.heightAnchor.constraint(equalToConstant: 44)
        }
        NSLayoutConstraint.activate(textHeightConstraints)
        applyButton?.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        moreButton?.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)
    }
}
