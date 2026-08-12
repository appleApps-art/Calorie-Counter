import UIKit

final class AdaptiveView: UIView {
    private var storedCornerRadius: CGFloat = 0

    @IBInspectable var adaptCornerRadius: Bool = false
    @IBInspectable var designCornerRadius: CGFloat = 0 {
        didSet {
            storedCornerRadius = designCornerRadius
            refreshCornerRadius()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        if designCornerRadius == 0, layer.cornerRadius > 0 {
            storedCornerRadius = layer.cornerRadius
        } else {
            storedCornerRadius = designCornerRadius
        }
        refreshCornerRadius()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshCornerRadius()
    }

    private func refreshCornerRadius() {
        guard adaptCornerRadius else { return }
        layer.cornerRadius = .adaptWidth(storedCornerRadius)
    }
}
