import UIKit

final class ProgressViewController: BaseViewController {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var insightCard: AdaptiveView!
    @IBOutlet private weak var insightBadgeView: UIView!
    @IBOutlet private weak var insightBadgeLabel: AdaptiveLabel!
    @IBOutlet private weak var insightBodyLabel: AdaptiveLabel!
    @IBOutlet private weak var lockCard: AdaptiveView!
    @IBOutlet private weak var lockTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var lockSubtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var upgradeButton: UIButton!
    @IBOutlet private weak var caloriesTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesPeriodControl: ProgressPeriodControl!
    @IBOutlet private weak var caloriesChartView: ProgressStackedBarChartView!
    @IBOutlet private weak var caloriesEmptyLabel: AdaptiveLabel!
    @IBOutlet private weak var fatsLegendLabel: AdaptiveLabel!
    @IBOutlet private weak var carbsLegendLabel: AdaptiveLabel!
    @IBOutlet private weak var proteinLegendLabel: AdaptiveLabel!
    @IBOutlet private weak var calorieTargetLegendLabel: AdaptiveLabel!
    @IBOutlet private weak var fatsDot: UIView!
    @IBOutlet private weak var carbsDot: UIView!
    @IBOutlet private weak var proteinDot: UIView!
    @IBOutlet private weak var calorieTargetDot: UIView!
    @IBOutlet private weak var expenditureTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var expenditurePeriodControl: ProgressPeriodControl!
    @IBOutlet private weak var expenditureChartView: ProgressBarChartView!
    @IBOutlet private weak var expenditureEmptyLabel: AdaptiveLabel!
    @IBOutlet private weak var expenditureTargetLegendLabel: AdaptiveLabel!
    @IBOutlet private weak var expenditureTargetDot: UIView!
    @IBOutlet private weak var expenditureStatsStack: UIStackView!
    @IBOutlet private weak var burnedStatView: ProgressStatPillView!
    @IBOutlet private weak var avgStatView: ProgressStatPillView!
    @IBOutlet private weak var bestStatView: ProgressStatPillView!
    @IBOutlet private weak var weightTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var weightPeriodControl: ProgressPeriodControl!
    @IBOutlet private weak var weightChartView: ProgressLineChartView!
    @IBOutlet private weak var weightEmptyLabel: AdaptiveLabel!
    @IBOutlet private weak var weightStatsStack: UIStackView!
    @IBOutlet private weak var startStatView: ProgressStatPillView!
    @IBOutlet private weak var currentStatView: ProgressStatPillView!
    @IBOutlet private weak var changeStatView: ProgressStatPillView!
    @IBOutlet private weak var photosTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var seeAllButton: UIButton!
    @IBOutlet private weak var photosStack: UIStackView!
    @IBOutlet private var photosStackHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var photosStackBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var addFirstPhotoButton: UIButton!
    @IBOutlet private var addFirstPhotoBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var scrollView: UIScrollView!

    private let viewModel: ProgressViewModel

    init(viewModel: ProgressViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "ProgressViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .progress }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.canvas
        configureChrome()
        viewModel.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        viewModel.reload()
    }

    override func bindViewModel() {
        viewModel.titleText.bind { [weak self] value in
            self?.titleLabel.text = value
            OnboardingStyle.lockFigmaFont(
                self?.titleLabel,
                size: 28,
                weight: .bold,
                color: AppColor.labelVibrantPrimary,
                kern: 0.38
            )
        }
        viewModel.isPremium.bind { [weak self] _ in
            self?.refreshPremiumChrome()
        }
        viewModel.caloriePeriod.bind { [weak self] period in
            self?.caloriesPeriodControl.selectedPeriod = period
        }
        viewModel.expenditurePeriod.bind { [weak self] period in
            self?.expenditurePeriodControl.selectedPeriod = period
        }
        viewModel.weightPeriod.bind { [weak self] period in
            self?.weightPeriodControl.selectedPeriod = period
        }
        viewModel.insightText.bind { [weak self] _ in
            self?.refreshPremiumChrome()
        }
        viewModel.calorieColumns.bind { [weak self] columns in
            self?.caloriesChartView.columns = columns
            self?.caloriesEmptyLabel.isHidden = columns.contains { $0.plotValue > 0 }
        }
        viewModel.calorieTarget.bind { [weak self] value in
            self?.caloriesChartView.target = value
        }
        viewModel.calorieTargetLegend.bind { [weak self] value in
            self?.calorieTargetLegendLabel.text = value
            OnboardingStyle.lockFigmaFont(
                self?.calorieTargetLegendLabel,
                size: 12,
                weight: .regular,
                color: AppColor.labelsSecondary
            )
        }
        viewModel.expenditureColumns.bind { [weak self] columns in
            self?.expenditureChartView.columns = columns
            self?.expenditureEmptyLabel.isHidden = columns.contains { $0.value > 0 }
        }
        viewModel.expenditureTarget.bind { [weak self] value in
            self?.expenditureChartView.target = value
        }
        viewModel.expenditureTargetLegend.bind { [weak self] value in
            self?.expenditureTargetLegendLabel.text = value
            self?.expenditureTargetLegendLabel.superview?.isHidden = value.isEmpty
            OnboardingStyle.lockFigmaFont(
                self?.expenditureTargetLegendLabel,
                size: 12,
                weight: .regular,
                color: AppColor.labelsSecondary
            )
        }
        viewModel.showsExpenditureStats.bind { [weak self] visible in
            self?.expenditureStatsStack.isHidden = !visible
        }
        viewModel.burnedText.bind { [weak self] value in
            self?.burnedStatView.configure(title: L10n.tr("progress.stat.totalBurned"), value: value)
        }
        viewModel.dailyAvgText.bind { [weak self] value in
            self?.avgStatView.configure(title: L10n.tr("progress.stat.dailyAvg"), value: value)
        }
        viewModel.bestDayText.bind { [weak self] value in
            self?.bestStatView.configure(title: L10n.tr("progress.stat.bestDay"), value: value)
        }
        viewModel.weightColumns.bind { [weak self] columns in
            self?.weightChartView.columns = columns
            self?.weightEmptyLabel.isHidden = !columns.isEmpty
        }
        viewModel.showsWeightStats.bind { [weak self] visible in
            self?.weightStatsStack.isHidden = !visible
        }
        viewModel.startWeightText.bind { [weak self] value in
            self?.startStatView.configure(title: L10n.tr("progress.stat.start"), value: value)
        }
        viewModel.currentWeightText.bind { [weak self] value in
            self?.currentStatView.configure(title: L10n.tr("progress.stat.current"), value: value)
        }
        viewModel.changeWeightText.bind { [weak self] value in
            guard let self else { return }
            let color = self.viewModel.changeColorIsMint.value ? AppColor.accentMint : AppColor.labelsPrimary
            self.changeStatView.configure(
                title: L10n.tr("progress.stat.change"),
                value: value,
                valueColor: color,
                symbolName: self.viewModel.changeSymbolName.value
            )
        }
        viewModel.photoPreviews.bind { [weak self] previews in
            self?.renderPhotoPreviews(previews)
        }
        viewModel.hasPhotos.bind { [weak self] hasPhotos in
            self?.refreshPhotosChrome(hasPhotos: hasPhotos)
        }
    }

    private func configureChrome() {
        scrollView.clipsToBounds = false
        scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 26.0, *) {
            scrollView.topEdgeEffect.isHidden = true
            scrollView.bottomEdgeEffect.isHidden = false
            scrollView.bottomEdgeEffect.style = .soft
            scrollView.leftEdgeEffect.isHidden = true
            scrollView.rightEdgeEffect.isHidden = true
        }
        OnboardingStyle.styleGlassSymbolButton(
            addButton,
            systemName: "plus",
            foregroundColor: AppColor.teal
        )
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        caloriesTitleLabel.text = L10n.tr("progress.caloriesTitle")
        expenditureTitleLabel.text = L10n.tr("progress.expenditureTitle")
        weightTitleLabel.text = L10n.tr("progress.weightTitle")
        photosTitleLabel.text = L10n.tr("progress.photosTitle")
        fatsLegendLabel.text = L10n.tr("home.fats")
        carbsLegendLabel.text = L10n.tr("home.carbs")
        proteinLegendLabel.text = L10n.tr("home.protein")
        fatsDot.backgroundColor = AppColor.accentIndigo
        carbsDot.backgroundColor = AppColor.accentMint
        proteinDot.backgroundColor = AppColor.accentBlue
        calorieTargetDot.backgroundColor = AppColor.labelsPrimary
        expenditureTargetDot.backgroundColor = AppColor.labelsPrimary
        [fatsDot, carbsDot, proteinDot, calorieTargetDot, expenditureTargetDot].forEach { dot in
            guard let dot else { return }
            dot.layer.cornerRadius = .adaptWidth(4)
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: .adaptWidth(8)),
                dot.heightAnchor.constraint(equalToConstant: .adaptWidth(8))
            ])
        }
        caloriesEmptyLabel.text = L10n.tr("progress.noData")
        expenditureEmptyLabel.text = L10n.tr("progress.noData")
        weightEmptyLabel.text = L10n.tr("progress.noData")
        lockTitleLabel.text = L10n.tr("progress.lock.title")
        lockSubtitleLabel.text = L10n.tr("progress.lock.subtitle")
        OnboardingStyle.lockFigmaFont(caloriesTitleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(expenditureTitleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(weightTitleLabel, size: 17, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(photosTitleLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(fatsLegendLabel, size: 12, weight: .regular, color: AppColor.labelsSecondary)
        OnboardingStyle.lockFigmaFont(carbsLegendLabel, size: 12, weight: .regular, color: AppColor.labelsSecondary)
        OnboardingStyle.lockFigmaFont(proteinLegendLabel, size: 12, weight: .regular, color: AppColor.labelsSecondary)
        OnboardingStyle.lockFigmaFont(caloriesEmptyLabel, size: 13, weight: .regular, color: AppColor.labelsSecondary)
        OnboardingStyle.lockFigmaFont(expenditureEmptyLabel, size: 13, weight: .regular, color: AppColor.labelsSecondary)
        OnboardingStyle.lockFigmaFont(weightEmptyLabel, size: 13, weight: .regular, color: AppColor.labelsSecondary)
        OnboardingStyle.lockFigmaFont(lockTitleLabel, size: 22, weight: .bold, color: AppColor.labelsPrimary, kern: -0.26)
        OnboardingStyle.lockFigmaFont(lockSubtitleLabel, size: 13, weight: .regular, color: AppColor.labelsSecondary, kern: -0.08)
        applyInsightBadge()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: ProgressViewController, _) in
            controller.applyInsightBadge()
        }
        OnboardingStyle.stylePrimaryButton(
            upgradeButton,
            title: L10n.tr("progress.lock.upgrade"),
            systemImage: "play.fill"
        )
        upgradeButton.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)
        seeAllButton.setTitle(L10n.tr("progress.seeAll"), for: .normal)
        seeAllButton.setTitleColor(AppColor.teal, for: .normal)
        OnboardingStyle.lockFigmaFont(seeAllButton.titleLabel, size: 15, weight: .regular, color: AppColor.teal, kern: -0.23)
        seeAllButton.addTarget(self, action: #selector(seeAllTapped), for: .touchUpInside)
        [fatsLegendLabel, carbsLegendLabel, proteinLegendLabel].forEach { label in
            label?.adjustsFontSizeToFitWidth = false
            label?.setContentCompressionResistancePriority(.required, for: .horizontal)
            label?.setContentHuggingPriority(.required, for: .horizontal)
        }
        [calorieTargetLegendLabel, expenditureTargetLegendLabel].forEach { label in
            label?.adjustsFontSizeToFitWidth = true
            label?.minimumScaleFactor = 0.75
            label?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        if let stack = fatsLegendLabel.superview as? UIStackView {
            stack.alignment = .center
            stack.clipsToBounds = true
            stack.setCustomSpacing(16, after: fatsLegendLabel)
            stack.setCustomSpacing(16, after: carbsLegendLabel)
            stack.setCustomSpacing(16, after: proteinLegendLabel)
        }
        if let stack = expenditureTargetLegendLabel.superview as? UIStackView {
            stack.alignment = .center
            stack.clipsToBounds = true
        }
        OnboardingStyle.stylePrimaryButton(
            addFirstPhotoButton,
            title: L10n.tr("progress.addFirstPhoto"),
            systemImage: "plus"
        )
        addFirstPhotoButton.addTarget(self, action: #selector(addPhotoTapped), for: .touchUpInside)
        photosStack.alignment = .fill
        photosStack.distribution = .fillEqually
        // A locked period snaps back to the one the chart still shows.
        caloriesPeriodControl.onSelect = { [weak self] period in
            guard let self else { return }
            viewModel.selectCaloriePeriod(period)
            caloriesPeriodControl.selectedPeriod = viewModel.caloriePeriod.value
        }
        expenditurePeriodControl.onSelect = { [weak self] period in
            guard let self else { return }
            viewModel.selectExpenditurePeriod(period)
            expenditurePeriodControl.selectedPeriod = viewModel.expenditurePeriod.value
        }
        weightPeriodControl.onSelect = { [weak self] period in
            guard let self else { return }
            viewModel.selectWeightPeriod(period)
            weightPeriodControl.selectedPeriod = viewModel.weightPeriod.value
        }
        caloriesChartView.onSelect = { _ in }
        expenditureChartView.onSelect = { _ in }
        weightChartView.onSelect = { _ in }
        lockCard.accessibilityLabel = L10n.tr("progress.lock.accessibility")
        caloriesPeriodControl.selectedPeriod = .week
        expenditurePeriodControl.selectedPeriod = .week
        weightPeriodControl.selectedPeriod = .week
        refreshPhotosChrome(hasPhotos: false)
    }

    private func applyInsightBadge() {
        insightBadgeLabel.adaptFontSize = false
        let radius = CGFloat.adaptWidth(10)
        insightBadgeView.backgroundColor = AppColor.labelsPrimary
        insightBadgeView.clipsToBounds = true
        insightBadgeView.layer.masksToBounds = true
        insightBadgeView.layer.cornerRadius = radius
        insightBadgeView.layer.cornerCurve = .continuous
        insightBadgeView.setContentHuggingPriority(.required, for: .horizontal)
        insightBadgeView.setContentHuggingPriority(.required, for: .vertical)
        insightBadgeView.setContentCompressionResistancePriority(.required, for: .horizontal)
        insightBadgeView.setContentCompressionResistancePriority(.required, for: .vertical)
        insightBadgeLabel.numberOfLines = 1
        insightBadgeLabel.lineBreakMode = .byTruncatingTail
        insightBadgeLabel.adjustsFontSizeToFitWidth = false
        insightBadgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        insightBadgeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let font = UIFont.systemFont(ofSize: 11, weight: .regular)
        let color = AppColor.onAccent
        let text = NSMutableAttributedString()
        let symbolSize: CGFloat = 11
        if let image = OnboardingStyle.symbol("sparkles", pointSize: symbolSize) {
            let attachment = NSTextAttachment()
            attachment.image = image.withTintColor(color, renderingMode: .alwaysOriginal)
            attachment.bounds = CGRect(x: 0, y: -2, width: symbolSize, height: symbolSize)
            text.append(NSAttributedString(attachment: attachment))
            text.append(NSAttributedString(string: " ", attributes: [.font: font]))
        }
        text.append(
            NSAttributedString(
                string: L10n.tr("progress.insight.badge"),
                attributes: [
                    .font: font,
                    .foregroundColor: color,
                    .kern: 0.06
                ]
            )
        )
        insightBadgeLabel.attributedText = text
        insightBadgeLabel.isAccessibilityElement = false
        refreshInsightAccessibility()
    }

    private func refreshPremiumChrome() {
        let premium = viewModel.isPremium.value
        let insight = viewModel.insightText.value
        lockCard.isHidden = premium
        insightCard.isHidden = !premium || insight == nil
        insightBodyLabel.text = insight
        OnboardingStyle.lockFigmaFont(
            insightBodyLabel,
            size: 13,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.08
        )
        insightBodyLabel.applyWrapping()
        refreshInsightAccessibility()
    }

    private func refreshInsightAccessibility() {
        insightCard.isAccessibilityElement = true
        insightBodyLabel.isAccessibilityElement = false
        insightBadgeLabel.isAccessibilityElement = false
        let headline = viewModel.insightText.value ?? ""
        insightCard.accessibilityLabel = [
            L10n.tr("progress.insight.badge"),
            headline
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    private func renderPhotoPreviews(_ previews: [ProgressPhotoPreview]) {
        photosStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for preview in previews.prefix(3) {
            let image: UIImage?
            if let url = preview.photo.fileURL {
                image = StoredPhoto.image(contentsOf: url, maxPixelSize: StoredPhoto.pixelSize(forPoints: 120))
            } else {
                image = nil
            }
            let thumb = ProgressPhotoThumbView()
            thumb.configure(image: image, dateText: preview.dateText, showsDate: true)
            photosStack.addArrangedSubview(thumb)
        }
        let missing = 3 - photosStack.arrangedSubviews.count
        if missing > 0, !previews.isEmpty {
            for _ in 0..<missing {
                let spacer = UIView()
                spacer.isUserInteractionEnabled = false
                photosStack.addArrangedSubview(spacer)
            }
        }
    }

    private func refreshPhotosChrome(hasPhotos: Bool) {
        photosStack.isHidden = !hasPhotos
        addFirstPhotoButton.isHidden = hasPhotos
        seeAllButton.isHidden = !hasPhotos
        photosStackHeightConstraint.isActive = hasPhotos
        photosStackBottomConstraint.isActive = hasPhotos
        addFirstPhotoBottomConstraint.isActive = !hasPhotos
    }

    @objc private func addTapped() {
        viewModel.logTapped()
    }

    @objc private func seeAllTapped() {
        viewModel.seeAllPhotosTapped()
    }

    @objc private func addPhotoTapped() {
        viewModel.addPhotoTapped()
    }

    @objc private func upgradeTapped() {
        viewModel.upgradeTapped()
    }
}
