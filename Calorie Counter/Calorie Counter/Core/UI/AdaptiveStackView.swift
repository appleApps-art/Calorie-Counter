import UIKit

final class AdaptiveStackView: UIStackView {
    private var storedDesignSpacing: CGFloat?

    @IBInspectable var adaptSpacing: Bool = true {
        didSet { refreshSpacing() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        storedDesignSpacing = spacing
        refreshSpacing()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshSpacing()
    }

    func refreshSpacing() {
        guard adaptSpacing else { return }
        let designValue = storedDesignSpacing ?? spacing
        storedDesignSpacing = designValue
        spacing = .adaptHeight(designValue)
    }
}
