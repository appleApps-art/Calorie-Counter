import UIKit

final class CustomLoadingOverlayView: UIView {
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

    private var isVisible = false

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

    func setVisible(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
        if visible {
            superview?.bringSubviewToFront(self)
            isHidden = false
            isUserInteractionEnabled = true
            activityIndicator.startAnimating()
            UIView.animate(withDuration: 0.18) {
                self.alpha = 1
            }
        } else {
            isUserInteractionEnabled = false
            UIView.animate(withDuration: 0.18) {
                self.alpha = 0
            } completion: { _ in
                if !self.isVisible {
                    self.isHidden = true
                    self.activityIndicator.stopAnimating()
                }
            }
        }
    }

    private func commonInit() {
        isOpaque = false
        backgroundColor = AppColor.overlayDefault
        embedNibContent()
        subviews.forEach { content in
            content.isOpaque = false
            content.backgroundColor = .clear
        }
        activityIndicator?.hidesWhenStopped = false
        // The scrim only dims what is behind it, so the spinner follows the theme: dark on the
        // light screen, light on the dark one.
        activityIndicator?.color = AppColor.labelsPrimary
        isHidden = true
        alpha = 0
    }
}
