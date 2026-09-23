import UIKit

/// Bity's own paywall, built from the design. Adapty only supplies prices and runs purchases, so
/// the screen shows at once (with the design's sample plans until the store answers) and never
/// depends on a remote layout.
final class PaywallViewController: UIViewController {
    private let viewModel: PaywallViewModel

    private let closeButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let titleLabel = PaywallTitleLabel()
    private let bottomPanel = AdaptiveView()
    private let plansStack = UIStackView()
    private let ctaButton = UIButton(type: .system)
    private let cancelLabel = UILabel()
    private let termsButton = UIButton(type: .system)
    private let privacyButton = UIButton(type: .system)
    private var planCards: [PaywallPlanCardView] = []
    private var timelineCard: PaywallTimelineCardView?

    init(viewModel: PaywallViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "paywall.\(viewModel.style == .onboarding ? "onboarding" : "feature")"
        view.backgroundColor = viewModel.style == .onboarding ? AppColor.gray6 : AppColor.backgroundsPrimary
        buildContent()
        buildBottomPanel()
        buildHeader()
        bind()
        viewModel.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Content scrolls out from under the glass panel instead of hiding behind it.
        let covered = max(0, view.bounds.maxY - bottomPanel.frame.minY - view.safeAreaInsets.bottom)
        if abs(scrollView.contentInset.bottom - covered) > 0.5 {
            scrollView.contentInset.bottom = covered
            scrollView.verticalScrollIndicatorInsets.bottom = covered
        }
    }

    // MARK: - Building

    private func buildHeader() {
        OnboardingStyle.styleGlassSymbolButton(closeButton, systemName: "xmark", foregroundColor: AppColor.labelVibrantPrimary)
        closeButton.accessibilityLabel = L10n.tr("common.close")
        closeButton.accessibilityIdentifier = "paywall.close"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        // Only the close button sits on glass; Restore is plain text in the design.
        var restore = UIButton.Configuration.plain()
        restore.baseForegroundColor = AppColor.labelVibrantPrimary
        restore.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 4)
        restore.attributedTitle = AttributedString(
            L10n.tr("paywall.restore"),
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: .adaptFont(17), weight: .medium)])
        )
        restoreButton.configuration = restore
        restoreButton.accessibilityIdentifier = "paywall.restore"
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        [closeButton, restoreButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: .adaptWidth(16)),
            closeButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: .adaptHeight(4)),
            closeButton.widthAnchor.constraint(equalToConstant: .adaptWidth(44)),
            closeButton.heightAnchor.constraint(equalToConstant: .adaptWidth(44)),
            restoreButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -.adaptWidth(16)),
            restoreButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            restoreButton.heightAnchor.constraint(equalToConstant: .adaptWidth(44))
        ])
    }

    private func buildContent() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            // Starts at the safe area, not under the buttons: the waving mascot's head rises into
            // the header row, beside the close button, as in the design.
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Self.contentTop(viewModel.style)),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -.adaptHeight(16)),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: .adaptWidth(16)),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -.adaptWidth(16))
        ])

        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        titleLabel.maxLines = viewModel.style == .onboarding ? 3 : 2

        switch viewModel.style {
        case .onboarding:
            buildOnboardingContent()
        case .feature:
            buildFeatureContent()
        }
    }

    /// The waving mascot beside the title, its paws resting on the trial timeline. The design's
    /// frame is 911 pt tall; its gaps are a little tighter here, so on a 874 pt screen all three
    /// benefits stay clear of the plans panel instead of sliding under it.
    private func buildOnboardingContent() {
        let titleRow = UIView()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleRow.addSubview(titleLabel)
        // The row keeps the design's height, so a third line of a longer translation grows the
        // title evenly up and down instead of pushing the timeline and the mascot down.
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: titleRow.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: .adaptWidth(173)),
            titleRow.heightAnchor.constraint(equalToConstant: .adaptHeight(76))
        ])
        let timeline = PaywallTimelineCardView(fillColor: AppColor.backgroundsPrimary)
        timelineCard = timeline
        // Mirrored in right-to-left languages, so Bity still waves towards the title.
        let mascot = UIImageView(image: UIImage(named: "PaywallMascotWaving")?.imageFlippedForRightToLeftLayoutDirection())
        mascot.contentMode = .scaleAspectFit
        mascot.isAccessibilityElement = false

        contentStack.addArrangedSubview(titleRow)
        contentStack.setCustomSpacing(.adaptHeight(16), after: titleRow)
        contentStack.addArrangedSubview(timeline)
        contentStack.setCustomSpacing(.adaptHeight(16), after: timeline)
        let benefits = PaywallBenefitsView(tileColor: AppColor.dynamic(light: .black, dark: .black), spacing: .adaptHeight(8))
        contentStack.addArrangedSubview(Self.inset(benefits, by: .adaptWidth(16)))

        mascot.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addSubview(mascot)
        NSLayoutConstraint.activate([
            mascot.leadingAnchor.constraint(equalTo: timeline.leadingAnchor, constant: .adaptWidth(40)),
            mascot.bottomAnchor.constraint(equalTo: timeline.topAnchor, constant: .adaptWidth(13)),
            mascot.widthAnchor.constraint(equalToConstant: .adaptWidth(156)),
            mascot.heightAnchor.constraint(equalToConstant: .adaptWidth(158))
        ])
    }

    private func buildFeatureContent() {
        let titleRow = Self.inset(titleLabel, by: .adaptWidth(16), vertical: .adaptHeight(10))
        contentStack.addArrangedSubview(titleRow)
        contentStack.setCustomSpacing(.adaptHeight(12), after: titleRow)
        let illustration = PaywallIllustrationView()
        illustration.translatesAutoresizingMaskIntoConstraints = false
        illustration.heightAnchor.constraint(equalToConstant: .adaptWidth(PaywallIllustrationView.designSize.height)).isActive = true
        contentStack.addArrangedSubview(illustration)
        contentStack.setCustomSpacing(.adaptHeight(12), after: illustration)
        let benefits = PaywallBenefitsView(
            tileColor: AppColor.dynamic(light: .black, dark: UIColor(white: 31 / 255, alpha: 1)),
            spacing: .adaptHeight(10)
        )
        contentStack.addArrangedSubview(Self.inset(benefits, by: .adaptWidth(24)))
    }

    /// Where the content starts below the safe area: the feature paywall as designed, the
    /// onboarding one a little higher, its mascot rising beside the close button.
    private static func contentTop(_ style: PaywallStyle) -> CGFloat {
        style == .onboarding ? .adaptHeight(54) : .adaptHeight(58)
    }

    private func buildBottomPanel() {
        bottomPanel.applyCardShadow = true
        bottomPanel.useLiveGlass = true
        bottomPanel.showsDropShadow = false
        bottomPanel.cardFillColor = AppColor.backgroundsPrimaryElevated
        bottomPanel.adaptCornerRadius = true
        bottomPanel.designCornerRadius = 24

        plansStack.axis = .vertical
        plansStack.spacing = .adaptHeight(12)

        OnboardingStyle.stylePrimaryButton(ctaButton, title: " ")
        ctaButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        ctaButton.accessibilityIdentifier = "paywall.purchase"
        ctaButton.addTarget(self, action: #selector(purchaseTapped), for: .touchUpInside)

        cancelLabel.text = L10n.tr("paywall.cancelAnytime")
        cancelLabel.font = .systemFont(ofSize: .adaptFont(13), weight: .regular)
        cancelLabel.textColor = UIColor(white: 138 / 255, alpha: 1)
        cancelLabel.textAlignment = .center
        cancelLabel.numberOfLines = 0

        styleLink(termsButton, title: L10n.tr("paywall.terms"))
        termsButton.addTarget(self, action: #selector(termsTapped), for: .touchUpInside)
        styleLink(privacyButton, title: L10n.tr("settings.privacyPolicy"))
        privacyButton.addTarget(self, action: #selector(privacyTapped), for: .touchUpInside)
        let bullet = UILabel()
        bullet.text = "•"
        bullet.font = .systemFont(ofSize: .adaptFont(11), weight: .medium)
        bullet.textColor = AppColor.iconSecondary
        let links = UIStackView(arrangedSubviews: [termsButton, bullet, privacyButton])
        links.axis = .horizontal
        links.alignment = .center
        links.spacing = .adaptWidth(12)
        let linksRow = UIStackView(arrangedSubviews: [links])
        linksRow.axis = .vertical
        linksRow.alignment = .center

        // As designed: a 50 pt button, 8 pt gaps, 18 pt lines, then the home indicator.
        let footer = UIStackView(arrangedSubviews: [ctaButton, cancelLabel, linksRow])
        footer.axis = .vertical
        footer.spacing = .adaptHeight(8)

        let stack = UIStackView(arrangedSubviews: [plansStack, footer])
        stack.axis = .vertical
        stack.spacing = .adaptHeight(16)

        [bottomPanel, stack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        let stackBottom = stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        stackBottom.priority = .required - 1
        NSLayoutConstraint.activate([
            bottomPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // The panel runs past the screen edge so only its top corners show.
            bottomPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: .adaptHeight(40)),
            bottomPanel.topAnchor.constraint(equalTo: stack.topAnchor, constant: -.adaptHeight(16)),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: .adaptWidth(16)),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -.adaptWidth(16)),
            stackBottom,
            // Screens without a home indicator have no bottom safe area; keep the links off the edge.
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -.adaptHeight(8)),
            ctaButton.heightAnchor.constraint(equalToConstant: .adaptHeight(50)),
            cancelLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 18),
            termsButton.heightAnchor.constraint(equalToConstant: 18),
            privacyButton.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    private func styleLink(_ button: UIButton, title: String) {
        var config = UIButton.Configuration.plain()
        config.contentInsets = .zero
        // One line: at 18 pt tall a wrapped second line was cut off on a narrow phone.
        config.titleLineBreakMode = .byTruncatingTail
        config.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: .adaptFont(13), weight: .regular),
                .foregroundColor: AppColor.iconSecondary,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
        )
        button.configuration = config
    }

    private static func inset(_ view: UIView, by amount: CGFloat, vertical: CGFloat = 0) -> UIView {
        let container = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: vertical),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vertical),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: amount),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -amount)
        ])
        return container
    }

    // MARK: - Binding

    private func bind() {
        viewModel.titleText.bind { [weak self] text in
            self?.titleLabel.source = text
        }
        viewModel.plans.bind { [weak self] plans in
            self?.renderPlans(plans)
        }
        viewModel.selectedPlanID.bind { [weak self] id in
            self?.planCards.forEach { $0.setSelected($0.planID == id) }
        }
        viewModel.ctaTitle.bind { [weak self] title in
            guard let self else { return }
            ctaButton.configuration?.title = title
            ctaButton.setTitle(title, for: .normal)
        }
        viewModel.timeline.bind { [weak self] steps in
            self?.timelineCard?.configure(steps)
            self?.timelineCard?.isHidden = steps.isEmpty
        }
        viewModel.isBusy.bind { [weak self] busy in
            guard let self else { return }
            ctaButton.configuration?.showsActivityIndicator = busy
            ctaButton.isUserInteractionEnabled = !busy
            restoreButton.isEnabled = !busy
        }
        viewModel.onAlert = { [weak self] message in
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("product.entry.ok"), style: .default))
            self?.present(alert, animated: true)
        }
        viewModel.onOpenURL = { url in
            UIApplication.shared.open(url)
        }
        viewModel.onFinish = { [weak self] report in
            guard let self, presentingViewController != nil, parent == nil else {
                report()
                return
            }
            dismiss(animated: true, completion: report)
        }
    }

    private func renderPlans(_ plans: [PaywallPlanDisplay]) {
        plansStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        planCards = plans.map { plan in
            let card = PaywallPlanCardView(fillColor: AppColor.backgroundsPrimary)
            card.configure(plan, selected: plan.id == viewModel.selectedPlanID.value)
            card.onSelect = { [weak self] id in self?.viewModel.select(planID: id) }
            card.accessibilityIdentifier = "paywall.plan.\(plan.id)"
            return card
        }
        planCards.forEach { plansStack.addArrangedSubview($0) }
    }

    // MARK: - Actions

    @objc
    private func closeTapped() {
        Haptics.light()
        viewModel.closeTapped()
    }

    @objc
    private func restoreTapped() {
        viewModel.restoreTapped()
    }

    @objc
    private func purchaseTapped() {
        viewModel.purchaseTapped()
    }

    @objc
    private func termsTapped() {
        viewModel.termsTapped()
    }

    @objc
    private func privacyTapped() {
        viewModel.privacyTapped()
    }
}

/// The paywall title: Title 2 emphasized from the design, 22 pt bold on a 28 pt line. A longer
/// translation steps down to 17 pt to stay within `maxLines`, measured at the label's real width.
final class PaywallTitleLabel: UILabel {
    var maxLines = 2
    var source = "" {
        didSet { fit() }
    }
    private var fittedWidth: CGFloat = -1

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.width != fittedWidth {
            fit()
        }
    }

    private func fit() {
        fittedWidth = bounds.width
        attributedText = bounds.width > 0
            ? Self.fitted(source, width: bounds.width, maxLines: maxLines)
            : Self.text(source, size: 22)
    }

    static func fitted(_ text: String, width: CGFloat, maxLines: Int) -> NSAttributedString {
        for size in stride(from: CGFloat(22), through: 17, by: -1) {
            let title = Self.text(text, size: size)
            let height = title.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).height
            if height <= lineHeight(size) * CGFloat(maxLines) + 1 {
                return title
            }
        }
        return Self.text(text, size: 17)
    }

    static func text(_ text: String, size: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.minimumLineHeight = lineHeight(size)
        paragraph.maximumLineHeight = lineHeight(size)
        return NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: .adaptFont(size), weight: .bold),
            .kern: -0.26,
            .foregroundColor: AppColor.labelVibrantPrimary,
            .paragraphStyle: paragraph
        ])
    }

    private static func lineHeight(_ size: CGFloat) -> CGFloat {
        (.adaptFont(size) * 28 / 22).rounded()
    }
}
