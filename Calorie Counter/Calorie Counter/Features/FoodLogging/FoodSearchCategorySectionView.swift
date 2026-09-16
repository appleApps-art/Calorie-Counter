import UIKit

final class FoodSearchCategorySectionView: UIView {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var seeMoreButton: UIButton!
    @IBOutlet private weak var cardView: AdaptiveView!
    @IBOutlet private weak var stackView: UIStackView!

    var onSeeMore: (() -> Void)?
    var onSelect: ((UUID) -> Void)?
    var onRetry: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ section: FoodSearchBrowseSection) {
        if section.isLoading {
            showSkeleton(category: section.category)
            return
        }
        titleLabel.text = L10n.tr(section.category.titleKey)
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        seeMoreButton.setTitle(L10n.tr("search.seeMore"), for: .normal)
        seeMoreButton.titleLabel?.font = .systemFont(ofSize: .adaptFont(17), weight: .medium)
        seeMoreButton.setTitleColor(AppColor.tabSelected, for: .normal)
        seeMoreButton.isHidden = !section.showsMore
        seeMoreButton.isEnabled = section.showsMore
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        seeMoreButton.setContentHuggingPriority(.required, for: .horizontal)
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if section.items.isEmpty {
            let empty = EmptyScreenView()
            empty.configure(
                title: L10n.tr(section.loadFailed ? "search.catalogLoadFailed" : "search.emptyTitle"),
                subtitle: nil,
                actionTitle: section.loadFailed ? L10n.tr("search.retry") : nil,
                systemImage: "arrow.clockwise"
            )
            empty.setContentTopInset(24)
            empty.setActionBottomInset(16)
            empty.onAction = { [weak self] in self?.onRetry?() }
            stackView.addArrangedSubview(empty)
        }
        section.items.enumerated().forEach { index, item in
            let row = FoodSearchResultRowView()
            row.configure(item, showsSeparator: index < section.items.count - 1)
            row.onSelect = { [weak self] id in
                self?.onSelect?(id)
            }
            stackView.addArrangedSubview(row)
        }
    }

    func showSkeleton(category: FoodSearchCategory) {
        titleLabel.text = L10n.tr(category.titleKey)
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        seeMoreButton.setTitle(L10n.tr("search.seeMore"), for: .normal)
        seeMoreButton.titleLabel?.font = .systemFont(ofSize: .adaptFont(17), weight: .medium)
        seeMoreButton.setTitleColor(AppColor.tabSelected, for: .normal)
        seeMoreButton.isHidden = true
        seeMoreButton.isEnabled = false
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        (0..<2).forEach { index in
            let row = FoodSearchResultRowView()
            row.showSkeleton(showsSeparator: index == 0)
            stackView.addArrangedSubview(row)
        }
    }

    @objc
    private func seeMoreTapped() {
        onSeeMore?()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        cardView.useLiveGlass = false
        cardView.applyCardShadow = true
        cardView.showsHairlineBorder = false
        cardView.showsDropShadow = true
        seeMoreButton.addTarget(self, action: #selector(seeMoreTapped), for: .touchUpInside)
    }
}
