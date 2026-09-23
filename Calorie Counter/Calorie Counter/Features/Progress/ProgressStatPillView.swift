import UIKit

final class ProgressStatPillView: UIView {
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var valueLabel: AdaptiveLabel!
    @IBOutlet private weak var symbolView: UIImageView!

    /// Free tier: the value (and its arrow) shows blurred under a sharp title, as in the design.
    var isRedacted = false {
        didSet {
            guard isRedacted != oldValue else { return }
            setNeedsLayout()
        }
    }
    private let redactedView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        redactedView.isUserInteractionEnabled = false
        redactedView.isHidden = true
        addSubview(redactedView)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ProgressStatPillView, _) in
            view.setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshRedaction()
    }

    private func refreshRedaction() {
        guard let row = valueLabel.superview else { return }
        row.accessibilityElementsHidden = isRedacted
        guard isRedacted else {
            row.alpha = 1
            redactedView.isHidden = true
            redactedView.image = nil
            return
        }
        subviews.first?.layoutIfNeeded()
        // The row is drawn with room around it so the blur can spread instead of being cut off.
        let padding = ProgressLockedBlur.radius * 2
        let frame = row.convert(row.bounds, to: self).insetBy(dx: -padding, dy: -padding)
        guard frame.width > 0, frame.height > 0 else { return }
        row.alpha = 1
        let format = UIGraphicsImageRendererFormat()
        format.scale = traitCollection.displayScale
        format.opaque = false
        let snapshot = UIGraphicsImageRenderer(size: frame.size, format: format).image { renderer in
            renderer.cgContext.translateBy(x: padding, y: padding)
            row.layer.render(in: renderer.cgContext)
        }
        row.alpha = 0
        redactedView.image = ProgressLockedBlur.blurred(snapshot)
        redactedView.frame = frame
        redactedView.isHidden = false
        bringSubviewToFront(redactedView)
    }

    func configure(title: String, value: String, valueColor: UIColor = AppColor.labelsPrimary, symbolName: String? = nil) {
        titleLabel.text = title
        valueLabel.text = value
        OnboardingStyle.lockFigmaFont(titleLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary)
        OnboardingStyle.lockFigmaFont(valueLabel, size: 17, weight: .semibold, color: valueColor, kern: -0.43)
        if let symbolName {
            symbolView.isHidden = false
            symbolView.image = UIImage(systemName: symbolName)
            symbolView.tintColor = valueColor
        } else {
            symbolView.isHidden = true
        }
        setNeedsLayout()
    }
}
