import UIKit

final class ProgressLogSheetViewController: BaseViewController {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var navTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scanFoodButton: UIButton!
    @IBOutlet private weak var scanBarcodeButton: UIButton!
    @IBOutlet private weak var searchButton: UIButton!
    @IBOutlet private weak var voiceButton: UIButton!
    @IBOutlet private weak var scanFoodCard: AdaptiveView!
    @IBOutlet private weak var scanBarcodeCard: AdaptiveView!
    @IBOutlet private weak var searchCard: AdaptiveView!
    @IBOutlet private weak var voiceCard: AdaptiveView!
    @IBOutlet private weak var scanFoodIcon: UIImageView!
    @IBOutlet private weak var scanBarcodeIcon: UIImageView!
    @IBOutlet private weak var searchIcon: UIImageView!
    @IBOutlet private weak var voiceIcon: UIImageView!
    @IBOutlet private weak var scanFoodTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scanBarcodeTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var searchTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var voiceTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scanFoodWell: AdaptiveView!
    @IBOutlet private weak var scanBarcodeWell: AdaptiveView!
    @IBOutlet private weak var searchWell: AdaptiveView!
    @IBOutlet private weak var voiceWell: AdaptiveView!

    private let onSelect: (ProgressLogAction) -> Void

    init(onSelect: @escaping (ProgressLogAction) -> Void) {
        self.onSelect = onSelect
        super.init(nibName: "ProgressLogSheetViewController")
        modalPresentationStyle = .pageSheet
        sheetPresentationController?.applyFigmaInspectorDetent(260)
    }

    override var analyticsScreen: AnalyticsScreen? { .progressLog }

    override func viewDidLoad() {
        super.viewDidLoad()
        applySheetBackground(AppColor.sheetGlassTint)
        [scanFoodCard, scanBarcodeCard, searchCard, voiceCard].forEach { $0.useLiveGlass = false }
        navTitleLabel.text = L10n.tr("progress.log.title")
        OnboardingStyle.lockFigmaFont(
            navTitleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.styleGlassSymbolButton(closeButton, systemName: "xmark", foregroundColor: AppColor.iconSecondary)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        configure(
            card: scanFoodCard,
            well: scanFoodWell,
            button: scanFoodButton,
            titleLabel: scanFoodTitleLabel,
            icon: scanFoodIcon,
            title: L10n.tr("progress.log.weight"),
            symbol: "chart.xyaxis.line",
            action: #selector(weightTapped)
        )
        let workoutSymbol = UIImage(systemName: "figure.run.treadmill") == nil ? "figure.run" : "figure.run.treadmill"
        configure(
            card: scanBarcodeCard,
            well: scanBarcodeWell,
            button: scanBarcodeButton,
            titleLabel: scanBarcodeTitleLabel,
            icon: scanBarcodeIcon,
            title: L10n.tr("progress.log.workout"),
            symbol: workoutSymbol,
            action: #selector(workoutTapped)
        )
        configure(
            card: searchCard,
            well: searchWell,
            button: searchButton,
            titleLabel: searchTitleLabel,
            icon: searchIcon,
            title: L10n.tr("progress.log.photo"),
            symbol: "camera",
            action: #selector(photoTapped)
        )
        voiceCard.alpha = 0
        voiceCard.isUserInteractionEnabled = false
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
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        icon.image = UIImage(systemName: symbol, withConfiguration: symbolConfig)
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

    @objc private func weightTapped() { finish(.weight) }
    @objc private func workoutTapped() { finish(.workout) }
    @objc private func photoTapped() { finish(.photo) }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func finish(_ action: ProgressLogAction) {
        dismiss(animated: true) { [onSelect] in
            onSelect(action)
        }
    }
}
