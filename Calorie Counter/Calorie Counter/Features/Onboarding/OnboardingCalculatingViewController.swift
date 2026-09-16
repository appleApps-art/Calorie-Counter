import UIKit

final class OnboardingCalculatingViewController: BaseViewController {
    @IBOutlet private weak var animationView: GIFImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!

    var onFinished: (() -> Void)?
    private var didFinish = false

    init() {
        super.init(nibName: "OnboardingCalculatingViewController")
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    override var analyticsScreen: AnalyticsScreen? { .onboardingCalculating }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let text = L10n.tr("onboarding.calculating.title").replacingOccurrences(of: "\\n", with: "\n")
        titleLabel.text = text
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 22,
            weight: .medium,
            color: AppColor.labelsPrimary,
            kern: -0.26
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        if let text = titleLabel.attributedText {
            let styled = NSMutableAttributedString(attributedString: text)
            styled.addAttribute(
                .paragraphStyle,
                value: paragraph,
                range: NSRange(location: 0, length: styled.length)
            )
            titleLabel.attributedText = styled
        }
        titleLabel.textAlignment = .center
        animationView.playsOnce = true
        animationView.onFinished = { [weak self] in
            self?.finish()
        }
        animationView.loadGIF(named: "Loading2")
        view.bringSubviewToFront(titleLabel)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animationView.startAnimatingGIF()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            animationView.stopAnimatingGIF()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinished?()
    }
}
