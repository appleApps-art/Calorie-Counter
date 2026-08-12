import UIKit

final class AdaptiveLabel: UILabel {
    private var storedDesignFontSize: CGFloat?

    @IBInspectable var adaptFontSize: Bool = true {
        didSet { refreshFont() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        storedDesignFontSize = font?.pointSize
        refreshFont()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshFont()
    }

    private func refreshFont() {
        guard adaptFontSize, let currentFont = font else { return }
        let designSize = storedDesignFontSize ?? currentFont.pointSize
        storedDesignFontSize = designSize
        font = currentFont.withSize(.adaptFont(designSize))
    }
}
