import UIKit

enum RecipesCreateAction {
    case recipe
    case mealPlan
}

final class RecipesCreateSheetViewController: BaseViewController {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var navTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scanFoodButton: UIButton!
    @IBOutlet private weak var scanBarcodeButton: UIButton!
    @IBOutlet private weak var scanFoodCard: AdaptiveView!
    @IBOutlet private weak var scanBarcodeCard: AdaptiveView!
    @IBOutlet private weak var scanFoodIcon: UIImageView!
    @IBOutlet private weak var scanBarcodeIcon: UIImageView!
    @IBOutlet private weak var scanFoodTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scanBarcodeTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scanFoodWell: AdaptiveView!
    @IBOutlet private weak var scanBarcodeWell: AdaptiveView!

    private let onSelect: (RecipesCreateAction) -> Void

    init(onSelect: @escaping (RecipesCreateAction) -> Void) {
        self.onSelect = onSelect
        super.init(nibName: "RecipesCreateSheetViewController")
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.custom { [weak sheet] context in
                sheet?.inspectorDetentHeight(
                    198,
                    minimumContentHeight: Self.contentDesignHeight,
                    maximumHeight: context.maximumDetentValue
                ) ?? min(Self.sheetDetentHeight, context.maximumDetentValue)
            }]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
    }

    static var sheetDetentHeight: CGFloat {
        contentDesignHeight
    }

    private static let contentDesignHeight: CGFloat = 16 + 44 + 30 + 68 + 6

    override var analyticsScreen: AnalyticsScreen? { .recipesCreate }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Keep the native glass backdrop, with the darker tint used by the inspector design.
        applySheetBackground(AppColor.sheetGlassTint)
        [scanFoodCard, scanBarcodeCard].forEach { $0.useLiveGlass = false }
        navTitleLabel.text = L10n.tr("recipes.create.title")
        OnboardingStyle.lockFigmaFont(
            navTitleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.styleGlassSymbolButton(
            closeButton, systemName: "xmark", foregroundColor: AppColor.iconSecondary
        )
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        configure(
            card: scanFoodCard,
            well: scanFoodWell,
            button: scanFoodButton,
            titleLabel: scanFoodTitleLabel,
            icon: scanFoodIcon,
            title: L10n.tr("recipes.create.recipe"),
            symbol: "book",
            action: #selector(recipeTapped)
        )
        configure(
            card: scanBarcodeCard,
            well: scanBarcodeWell,
            button: scanBarcodeButton,
            titleLabel: scanBarcodeTitleLabel,
            icon: scanBarcodeIcon,
            title: L10n.tr("recipes.create.mealPlan"),
            symbol: "list.bullet.clipboard",
            action: #selector(mealPlanTapped)
        )
    }

    private func configure(
        card: AdaptiveView,
        well: AdaptiveView,
        button: UIButton,
        titleLabel: AdaptiveLabel,
        icon: UIImageView,
        title: String,
        symbol: String,
        action: Selector
    ) {
        card.cardFillColor = .white
        well.backgroundColor = .black
        well.isUserInteractionEnabled = false
        titleLabel.text = title
        titleLabel.isUserInteractionEnabled = false
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 15,
            weight: .regular,
            color: .black,
            kern: -0.23
        )
        icon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.isUserInteractionEnabled = false
        button.configuration = nil
        button.setTitle(nil, for: .normal)
        button.backgroundColor = .clear
        button.addTarget(self, action: action, for: .touchUpInside)
        button.controlHaptic = .medium
        OnboardingStyle.applyPressFeedback(button)
        card.useLiveGlass = false
    }

    @objc private func recipeTapped() { finish(.recipe) }
    @objc private func mealPlanTapped() { finish(.mealPlan) }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func finish(_ action: RecipesCreateAction) {
        dismiss(animated: true) { [onSelect] in
            onSelect(action)
        }
    }
}
