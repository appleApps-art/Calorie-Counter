import UIKit

final class RewardDetailViewController: BaseViewController {
    @IBOutlet private weak var closeButton: UIButton!
    @IBOutlet private weak var confettiView: GIFImageView!
    @IBOutlet private weak var badgeImageView: UIImageView!
    @IBOutlet private weak var pillView: AdaptiveView!
    @IBOutlet private weak var pillLabel: AdaptiveLabel!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var progressCardView: RewardProgressCardView!
    @IBOutlet private weak var shareButton: UIButton!
    @IBOutlet private weak var viewAllButton: UIButton!

    var onDismissed: (() -> Void)?
    var onViewed: (() -> Void)?

    static let confettiBursts = 3

    private let progress: BadgeProgress
    private let playsCelebration: Bool
    private var didNotifyDismiss = false
    private var didNotifyViewed = false

    init(progress: BadgeProgress, playsCelebration: Bool = false) {
        self.progress = progress
        self.playsCelebration = playsCelebration
        super.init(nibName: "RewardDetailViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .rewardDetail }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureChrome()
        populate()
        if playsCelebration {
            confettiView.isHidden = false
            confettiView.playsOnce = false
            // Three bursts celebrate the badge; an endless loop turns into noise behind the card.
            confettiView.loopLimit = Self.confettiBursts
            confettiView.onFinished = { [weak confettiView] in
                UIView.animate(withDuration: 0.3) { confettiView?.alpha = 0 }
            }
            confettiView.loadGIF(named: "RewardConfetti")
        } else {
            confettiView.isHidden = true
        }
        NSLayoutConstraint.deactivate(progressCardView.constraints.filter {
            $0.firstAttribute == .height && $0.secondItem == nil
        })
        pillView.constraints.first { $0.firstAttribute == .width && $0.secondItem == nil }?.priority = .defaultHigh
        pillView.constraints.first { $0.firstAttribute == .height && $0.secondItem == nil }?.priority = .defaultHigh
        NSLayoutConstraint.activate([
            pillView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
            pillView.heightAnchor.constraint(greaterThanOrEqualTo: pillLabel.heightAnchor, constant: 24),
            shareButton.topAnchor.constraint(greaterThanOrEqualTo: progressCardView.bottomAnchor, constant: 24)
        ])
        keepBottomBlockTogether()
        FlowScrollLayout.install(in: view)
    }

    /// In the design the title, the reward card and the buttons sit together at the bottom;
    /// spare height goes above the title instead of stretching the card.
    private func keepBottomBlockTogether() {
        guard let titleTop = view.constraints.first(where: {
            $0.firstItem === titleLabel && $0.firstAttribute == .top && $0.secondItem === pillView
        }) else { return }
        titleTop.isActive = false
        // Below the scroll content's preferred height (249), so extra room never makes it scroll.
        let preferred = titleLabel.topAnchor.constraint(equalTo: pillView.bottomAnchor, constant: titleTop.constant)
        preferred.priority = .init(240)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: pillView.bottomAnchor, constant: titleTop.constant),
            preferred
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if playsCelebration {
            confettiView.startAnimatingGIF()
        } else {
            notifyViewedIfNeeded()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            confettiView.stopAnimatingGIF()
            notifyDismissedIfNeeded()
        }
    }

    private func configureChrome() {
        view.backgroundColor = AppColor.gray6
        OnboardingStyle.styleGlassSymbolButton(closeButton, systemName: "xmark")
        OnboardingStyle.stylePrimaryButton(
            shareButton,
            title: L10n.tr("rewards.share"),
            systemImage: "square.and.arrow.up"
        )
        OnboardingStyle.styleSecondaryButton(viewAllButton, title: L10n.tr("rewards.viewAll"))
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        viewAllButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        pillView.backgroundColor = AppColor.card
        applyPillShadow()
    }

    private func populate() {
        badgeImageView.image = UIImage(named: progress.badge.imageName)
        badgeImageView.alpha = progress.showsLockedArt ? 0.15 : 1
        pillLabel.text = progress.pillTitle
        titleLabel.text = progress.badge.celebrationTitle
        pillLabel.applyWrapping()
        OnboardingStyle.lockFigmaFont(pillLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.styleTitle(titleLabel)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        progressCardView.configure(progress)
        view.sendSubviewToBack(confettiView)
        confettiView.contentMode = .scaleAspectFill
        confettiView.isUserInteractionEnabled = false
    }

    private func applyPillShadow() {
        pillView.layer.masksToBounds = false
        pillView.layer.shadowColor = UIColor.black.cgColor
        pillView.layer.shadowOpacity = 0.1
        pillView.layer.shadowRadius = 16
        pillView.layer.shadowOffset = CGSize(width: 3, height: 4)
    }

    @objc private func closeTapped() {
        notifyViewedIfNeeded()
        dismiss(animated: true) { [weak self] in
            self?.notifyDismissedIfNeeded()
        }
    }

    private func notifyViewedIfNeeded() {
        guard !didNotifyViewed else { return }
        didNotifyViewed = true
        onViewed?()
    }

    private func notifyDismissedIfNeeded() {
        guard !didNotifyDismiss else { return }
        didNotifyDismiss = true
        onDismissed?()
    }

    @objc private func shareTapped() {
        Analytics.tracker.track(.badgeShared(badge: progress.badge.rawValue))
        let image = UIImage(named: progress.badge.imageName)
        let items: [Any] = [progress.badge.title, progress.pillTitle, image].compactMap { $0 }
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        present(activity, animated: true)
    }
}
