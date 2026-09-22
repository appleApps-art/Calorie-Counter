import UIKit

final class QuickLogSheetViewController: BaseViewController {
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

    private let titleKey: String
    private let onSelect: (HomeQuickLogAction) -> Void

    init(titleKey: String = "home.quickLog.navTitle", onSelect: @escaping (HomeQuickLogAction) -> Void) {
        self.titleKey = titleKey
        self.onSelect = onSelect
        super.init(nibName: "QuickLogSheetViewController")
        modalPresentationStyle = .pageSheet
        sheetPresentationController?.applyFigmaInspectorDetent(260)
    }

    override var analyticsScreen: AnalyticsScreen? { .quickLog }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.dynamic(light: .clear, dark: UIColor.black.withAlphaComponent(0.6))
        disableCardLiveGlass()
        navTitleLabel.text = L10n.tr(titleKey)
        OnboardingStyle.lockFigmaFont(
            navTitleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        var closeConfiguration = UIButton.Configuration.filled()
        closeConfiguration.cornerStyle = .capsule
        closeConfiguration.contentInsets = .zero
        closeConfiguration.baseBackgroundColor = AppColor.fillSecondary
        closeConfiguration.baseForegroundColor = AppColor.dynamic(
            light: UIColor(white: 114 / 255, alpha: 1), dark: UIColor(red: 180 / 255, green: 180 / 255, blue: 184 / 255, alpha: 1)
        )
        closeConfiguration.image = UIImage(systemName: "xmark", withConfiguration:
            UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
        closeButton.configuration = closeConfiguration
        closeButton.accessibilityLabel = L10n.tr("common.close")
        OnboardingStyle.applyPressFeedback(closeButton)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        configure(
            card: scanFoodCard,
            well: scanFoodWell,
            button: scanFoodButton,
            titleLabel: scanFoodTitleLabel,
            icon: scanFoodIcon,
            title: L10n.tr("home.quickLog.scanFood"),
            symbol: "camera",
            action: #selector(scanFoodTapped)
        )
        configure(
            card: scanBarcodeCard,
            well: scanBarcodeWell,
            button: scanBarcodeButton,
            titleLabel: scanBarcodeTitleLabel,
            icon: scanBarcodeIcon,
            title: L10n.tr("home.quickLog.scanBarcode"),
            symbol: "barcode.viewfinder",
            action: #selector(scanBarcodeTapped)
        )
        configure(
            card: searchCard,
            well: searchWell,
            button: searchButton,
            titleLabel: searchTitleLabel,
            icon: searchIcon,
            title: L10n.tr("home.quickLog.search"),
            symbol: "magnifyingglass",
            action: #selector(searchTapped)
        )
        configure(
            card: voiceCard,
            well: voiceWell,
            button: voiceButton,
            titleLabel: voiceTitleLabel,
            icon: voiceIcon,
            title: L10n.tr("home.quickLog.voiceLog"),
            symbol: "microphone",
            action: #selector(voiceTapped)
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
        well.backgroundColor = AppColor.dynamic(light: .black, dark: UIColor(white: 31 / 255, alpha: 1))
        well.isUserInteractionEnabled = false
        titleLabel.text = title
        titleLabel.isUserInteractionEnabled = false
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 15,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.23
        )
        titleLabel.applyLineTruncation(lines: 2)
        button.accessibilityLabel = title
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        icon.image = UIImage(systemName: symbol, withConfiguration: symbolConfig)
        icon.tintColor = AppColor.dynamic(light: .white, dark: AppColor.labelsSecondary)
        icon.contentMode = .scaleAspectFit
        icon.isUserInteractionEnabled = false
        button.configuration = nil
        button.setTitle(nil, for: .normal)
        button.backgroundColor = .clear
        button.addTarget(self, action: action, for: .touchUpInside)
        button.controlHaptic = .medium
        OnboardingStyle.applyPressFeedback(button)
        card.useLiveGlass = false
        card.cardFillColor = AppColor.backgroundsPrimary
    }

    private func disableCardLiveGlass() {
        [scanFoodCard, scanBarcodeCard, searchCard, voiceCard].forEach { card in
            card.useLiveGlass = false
        }
    }

    @objc private func scanFoodTapped() { finish(.scanFood) }
    @objc private func scanBarcodeTapped() { finish(.scanBarcode) }
    @objc private func searchTapped() { finish(.search) }
    @objc private func voiceTapped() { finish(.voiceLog) }

    @objc
    private func closeTapped() {
        dismiss(animated: true)
    }

    private func finish(_ action: HomeQuickLogAction) {
        Analytics.tracker.track(.quickLogOptionSelected(option: String(describing: action)))
        dismiss(animated: true) { [onSelect] in
            onSelect(action)
        }
    }
}
