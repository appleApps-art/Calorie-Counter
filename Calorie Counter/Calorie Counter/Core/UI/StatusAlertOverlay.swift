import UIKit

final class StatusAlertOverlay: UIView {
    @IBOutlet private weak var dimView: UIView!
    @IBOutlet private weak var alertCard: AdaptiveView!
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var okButton: UIButton!

    var onOK: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func attach(to host: UIView) {
        guard superview == nil else { return }
        translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: host.topAnchor),
            leadingAnchor.constraint(equalTo: host.leadingAnchor),
            trailingAnchor.constraint(equalTo: host.trailingAnchor),
            bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
        isHidden = true
        alpha = 0
        isUserInteractionEnabled = false
    }

    func configure(title: String) {
        titleLabel.text = title
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        titleLabel.textAlignment = .center
        iconView.image = OnboardingStyle.symbol("checkmark.circle", pointSize: 28)
        iconView.tintColor = AppColor.iconSecondary
        OnboardingStyle.stylePrimaryButton(okButton, title: L10n.tr("product.entry.ok"))
    }

    func setVisible(_ visible: Bool) {
        superview?.bringSubviewToFront(self)
        isHidden = false
        isUserInteractionEnabled = visible
        UIView.animate(withDuration: 0.22) {
            self.alpha = visible ? 1 : 0
        } completion: { _ in
            if !visible {
                self.isHidden = true
                self.isUserInteractionEnabled = false
            }
        }
        if visible {
            Haptics.success()
        }
    }

    @objc
    private func okTapped() {
        onOK?()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        alertCard.useLiveGlass = true
        alertCard.applyCardShadow = true
        alertCard.backgroundColor = .clear
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        okButton.addTarget(self, action: #selector(okTapped), for: .touchUpInside)
        isHidden = true
        alpha = 0
    }
}
