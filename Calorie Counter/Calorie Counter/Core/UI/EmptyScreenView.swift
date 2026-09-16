import UIKit

final class EmptyScreenView: UIView {
    @IBOutlet private weak var illustrationView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var subtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var actionButton: UIButton!
    @IBOutlet private weak var actionHeightConstraint: AdaptiveConstraint!
    @IBOutlet private weak var contentTopConstraint: AdaptiveConstraint!
    @IBOutlet private weak var actionBottomConstraint: AdaptiveConstraint!
    @IBOutlet private weak var messageWidthConstraint: AdaptiveConstraint!
    @IBOutlet private weak var illustrationWidthConstraint: AdaptiveConstraint!
    @IBOutlet private weak var illustrationHeightConstraint: AdaptiveConstraint!

    var onAction: (() -> Void)?
    private var showsIllustrationShadow = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(
        title: String,
        subtitle: String?,
        actionTitle: String?,
        systemImage: String? = "sparkles",
        illustrationName: String = "EmptyScreen",
        titleNumberOfLines: Int = 0
    ) {
        unclipAncestors()
        applyIllustration(named: illustrationName)
        titleLabel.text = title
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = titleNumberOfLines == 1 ? 1 : 0
        titleLabel.lineBreakMode = titleNumberOfLines == 1 ? .byTruncatingTail : .byWordWrapping
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 22,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.26
        )
        if titleNumberOfLines == 1 {
            titleLabel.applyLineTruncation(lines: 1)
        } else {
            titleLabel.applyWrapping()
        }
        configureMessageLabel(titleLabel, wraps: titleNumberOfLines != 1)
        let subtitleText = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        subtitleLabel.isHidden = subtitleText.isEmpty
        subtitleLabel.text = subtitleText
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.lineBreakMode = .byWordWrapping
        OnboardingStyle.lockFigmaFont(
            subtitleLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsSecondary,
            kern: -0.43
        )
        subtitleLabel.applyWrapping()
        configureMessageLabel(subtitleLabel, wraps: true)
        let buttonTitle = actionTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        actionButton.isHidden = buttonTitle.isEmpty
        actionHeightConstraint.designConstant = buttonTitle.isEmpty ? 0 : 50
        if !buttonTitle.isEmpty {
            if let systemImage, !systemImage.isEmpty {
                OnboardingStyle.stylePrimaryButton(actionButton, title: buttonTitle, systemImage: systemImage)
            } else {
                OnboardingStyle.stylePrimaryButton(actionButton, title: buttonTitle)
            }
        }
    }

    func setContentTopInset(_ value: CGFloat) {
        contentTopConstraint?.designConstant = value
    }

    func setActionBottomInset(_ value: CGFloat) {
        actionBottomConstraint?.adaptToHeight = true
        actionBottomConstraint?.designConstant = value
    }

    func setActionBottomInsetPoints(_ value: CGFloat) {
        let inset = max(0, value)
        actionBottomConstraint?.adaptToHeight = false
        guard abs((actionBottomConstraint?.constant ?? 0) - inset) > 0.5 else { return }
        actionBottomConstraint?.constant = inset
    }

    func setMessageWidth(_ width: CGFloat) {
        messageWidthConstraint?.designConstant = width
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        unclipAncestors()
        refreshIllustrationShadow()
        let messageWidth = messageWidthConstraint?.constant ?? 0
        if messageWidth > 0 {
            titleLabel.preferredMaxLayoutWidth = messageWidth
            subtitleLabel.preferredMaxLayoutWidth = messageWidth
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshIllustrationShadow()
    }

    @objc
    private func actionTapped() {
        onAction?()
    }

    private func applyIllustration(named name: String) {
        illustrationView.image = UIImage(named: name)?.withRenderingMode(.alwaysOriginal)
        illustrationView.isOpaque = false
        illustrationView.backgroundColor = .clear
        let usesCardIllustration = name == "emptyImage1" || name == "emptyImage2" || name == "emptyImagePantry"
        illustrationWidthConstraint?.designConstant = usesCardIllustration ? 176 : 208
        illustrationHeightConstraint?.designConstant = usesCardIllustration ? 164 : 196
        showsIllustrationShadow = usesCardIllustration
        if usesCardIllustration {
            illustrationView.contentMode = .scaleAspectFill
            illustrationView.clipsToBounds = true
            illustrationView.layer.masksToBounds = true
            illustrationView.layer.cornerCurve = .continuous
            illustrationView.layer.cornerRadius = .adaptWidth(32)
        } else {
            illustrationView.contentMode = .scaleAspectFit
            illustrationView.clipsToBounds = false
            illustrationView.layer.masksToBounds = false
            illustrationView.layer.cornerRadius = 0
        }
        refreshIllustrationShadow()
    }

    private func refreshIllustrationShadow() {
        guard let illustrationView else { return }
        let wrap = illustrationView.superview
        wrap?.clipsToBounds = false
        wrap?.layer.masksToBounds = false
        clipsToBounds = false
        layer.masksToBounds = false
        guard showsIllustrationShadow else {
            illustrationView.layer.shadowOpacity = 0
            illustrationView.layer.shadowPath = nil
            wrap?.layer.shadowOpacity = 0
            wrap?.layer.shadowPath = nil
            return
        }
        illustrationView.clipsToBounds = true
        illustrationView.layer.masksToBounds = true
        illustrationView.layer.shadowOpacity = 0
        illustrationView.layer.shadowPath = nil
        illustrationView.layer.cornerRadius = .adaptWidth(32)
        illustrationView.layer.cornerCurve = .continuous
        guard let wrap, wrap.bounds.width > 0, wrap.bounds.height > 0 else { return }
        OnboardingStyle.applyCardFallbackShadow(wrap.layer, traits: traitCollection)
        let radius = CGFloat.adaptWidth(32)
        wrap.layer.shadowPath = UIBezierPath(
            roundedRect: wrap.bounds,
            cornerRadius: radius
        ).cgPath
    }

    private func unclipAncestors() {
        clipsToBounds = false
        layer.masksToBounds = false
        subviews.forEach { child in
            guard child !== illustrationView else { return }
            child.clipsToBounds = false
            child.layer.masksToBounds = false
        }
        illustrationView?.superview?.clipsToBounds = false
        illustrationView?.superview?.layer.masksToBounds = false
        if showsIllustrationShadow {
            illustrationView?.clipsToBounds = true
            illustrationView?.layer.masksToBounds = true
        } else {
            illustrationView?.clipsToBounds = false
            illustrationView?.layer.masksToBounds = false
        }
    }

    private func configureMessageLabel(_ label: UILabel?, wraps: Bool) {
        guard let label else { return }
        label.contentMode = .redraw
        label.textAlignment = .center
        label.numberOfLines = wraps ? 0 : 1
        label.lineBreakMode = wraps ? .byWordWrapping : .byTruncatingTail
        label.adjustsFontSizeToFitWidth = false
        label.minimumScaleFactor = 1
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if let attributed = label.attributedText, attributed.length > 0 {
            let mutable = NSMutableAttributedString(attributedString: attributed)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = wraps ? .byWordWrapping : .byTruncatingTail
            mutable.addAttribute(
                .paragraphStyle,
                value: paragraph,
                range: NSRange(location: 0, length: mutable.length)
            )
            label.attributedText = mutable
            label.textAlignment = .center
        }
        let messageWidth = messageWidthConstraint?.constant ?? .adaptWidth(230)
        if messageWidth > 0 {
            label.preferredMaxLayoutWidth = messageWidth
        }
        label.invalidateIntrinsicContentSize()
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        embedNibContent()
        unclipAncestors()
        configureMessageLabel(titleLabel, wraps: true)
        configureMessageLabel(subtitleLabel, wraps: true)
        illustrationView.image = UIImage(named: "EmptyScreen")
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }
}
