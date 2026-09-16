import UIKit

final class AddToPantrySheetViewController: BaseViewController {
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

    private let onSelect: (HomeQuickLogAction) -> Void

    init(onSelect: @escaping (HomeQuickLogAction) -> Void) {
        self.onSelect = onSelect
        super.init(nibName: "AddToPantrySheetViewController")
        modalPresentationStyle = .pageSheet
        sheetPresentationController?.applyFigmaInspectorDetent(260)
    }

    override var analyticsScreen: AnalyticsScreen? { .pantryAdd }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        [scanFoodCard, scanBarcodeCard, searchCard, voiceCard].forEach { $0.useLiveGlass = false }
        navTitleLabel.text = L10n.tr("pantry.addTitle")
        OnboardingStyle.lockFigmaFont(navTitleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.styleGlassSymbolButton(closeButton, systemName: "xmark", foregroundColor: AppColor.iconSecondary)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        configure(card: scanFoodCard, well: scanFoodWell, button: scanFoodButton, titleLabel: scanFoodTitleLabel, icon: scanFoodIcon, title: L10n.tr("pantry.add.fridgePhoto"), symbol: "camera", action: #selector(fridgeTapped))
        configure(card: scanBarcodeCard, well: scanBarcodeWell, button: scanBarcodeButton, titleLabel: scanBarcodeTitleLabel, icon: scanBarcodeIcon, title: L10n.tr("pantry.add.scanBarcode"), symbol: "barcode.viewfinder", action: #selector(barcodeTapped))
        configure(card: searchCard, well: searchWell, button: searchButton, titleLabel: searchTitleLabel, icon: searchIcon, title: L10n.tr("pantry.add.search"), symbol: "magnifyingglass", action: #selector(searchTapped))
        configure(card: voiceCard, well: voiceWell, button: voiceButton, titleLabel: voiceTitleLabel, icon: voiceIcon, title: L10n.tr("pantry.add.voiceLog"), symbol: "microphone", action: #selector(voiceTapped))
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
        well.backgroundColor = AppColor.labelsPrimary
        well.isUserInteractionEnabled = false
        titleLabel.text = title
        titleLabel.isUserInteractionEnabled = false
        OnboardingStyle.lockFigmaFont(titleLabel, size: 15, weight: .regular, color: AppColor.labelsPrimary, kern: -0.23)
        icon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular))
        icon.tintColor = AppColor.onAccent
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

    @objc private func fridgeTapped() { finish(.scanFood) }
    @objc private func barcodeTapped() { finish(.scanBarcode) }
    @objc private func searchTapped() { finish(.search) }
    @objc private func voiceTapped() { finish(.voiceLog) }
    @objc private func closeTapped() { dismiss(animated: true) }

    private func finish(_ action: HomeQuickLogAction) {
        dismiss(animated: true) { [onSelect] in
            onSelect(action)
        }
    }
}
