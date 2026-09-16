import UIKit

final class SettingsOptionPickerViewController: BaseViewController {
    struct Option {
        let title: String
        let isSelected: Bool
    }

    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var listCard: AdaptiveView!
    @IBOutlet private weak var rowsStackView: UIStackView!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var backgroundImageView: UIImageView!

    private let screenTitle: String
    private let options: [Option]
    private let onSave: (Int) -> Void
    private let analytics: AnalyticsScreen
    private var selectedIndex: Int

    init(
        title: String,
        options: [Option],
        analyticsScreen: AnalyticsScreen,
        onSave: @escaping (Int) -> Void
    ) {
        self.screenTitle = title
        self.options = options
        self.analytics = analyticsScreen
        self.onSave = onSave
        self.selectedIndex = options.firstIndex(where: \.isSelected) ?? 0
        super.init(nibName: "SettingsOptionPickerViewController")
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 38
        }
    }

    override var analyticsScreen: AnalyticsScreen? { analytics }

    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundImageView.image = UIImage(named: "OnboardingBg1")
        backgroundImageView.contentMode = .scaleAspectFill
        view.sendSubviewToBack(backgroundImageView)
        view.backgroundColor = AppColor.dynamic(light: AppColor.backgroundsPrimary, dark: AppColor.gray6)
        refreshBackgroundAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: SettingsOptionPickerViewController, _) in
            controller.refreshBackgroundAppearance()
        }
        titleLabel.text = screenTitle
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.styleGlassSymbolButton(
            closeButton,
            systemName: "xmark",
            foregroundColor: AppColor.iconSecondary
        )
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        OnboardingStyle.stylePrimaryButton(saveButton, title: L10n.tr("common.save"))
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        SettingsSheetChrome.applyListCard(listCard)
        renderOptions()
    }

    private func renderOptions() {
        rowsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        options.enumerated().forEach { index, option in
            let row = SettingsRowView()
            row.translatesAutoresizingMaskIntoConstraints = false
            row.configure(
                title: option.title,
                accessory: .checkmark,
                showsSeparator: index < options.count - 1,
                separatorColor: AppColor.separatorVibrant
            )
            row.useSingleLineLayout()
            row.heightAnchor.constraint(equalToConstant: 52).isActive = true
            row.setOptionSelected(index == selectedIndex)
            row.onTap = { [weak self] in
                guard let self, self.selectedIndex != index else { return }
                self.selectedIndex = index
                self.rowsStackView.arrangedSubviews.enumerated().forEach { position, view in
                    (view as? SettingsRowView)?.setOptionSelected(position == index)
                }
            }
            rowsStackView.addArrangedSubview(row)
        }
    }

    private func refreshBackgroundAppearance() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundImageView.image = UIImage(named: isDark ? "SettingsSheetDarkBackground" : "OnboardingBg1")
        backgroundImageView.contentMode = isDark ? .scaleToFill : .scaleAspectFill
    }

    @objc
    private func saveTapped() {
        let index = selectedIndex
        dismiss(animated: true) { [onSave] in
            onSave(index)
        }
    }

    @objc
    private func closeTapped() {
        dismiss(animated: true)
    }
}
