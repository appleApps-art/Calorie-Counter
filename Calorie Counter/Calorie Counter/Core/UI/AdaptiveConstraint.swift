import UIKit

final class AdaptiveConstraint: NSLayoutConstraint {
    private var storedDesignConstant: CGFloat?
    private var sizeObserver: NSObjectProtocol?

    @IBInspectable var adaptToWidth: Bool = false {
        didSet { refreshConstant() }
    }

    @IBInspectable var adaptToHeight: Bool = false {
        didSet { refreshConstant() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        storedDesignConstant = constant
        refreshConstant()
        startObservingSizeChanges()
    }

    deinit {
        if let sizeObserver {
            NotificationCenter.default.removeObserver(sizeObserver)
        }
    }

    func refreshConstant() {
        let designValue = storedDesignConstant ?? constant
        if storedDesignConstant == nil {
            storedDesignConstant = designValue
        }

        switch (adaptToWidth, adaptToHeight) {
        case (true, false):
            constant = .adaptWidth(designValue)
        case (false, true):
            constant = .adaptHeight(designValue)
        case (true, true):
            constant = .adaptWidth(designValue)
        case (false, false):
            constant = designValue
        }
    }

    private func startObservingSizeChanges() {
        sizeObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshConstant()
        }
    }
}
