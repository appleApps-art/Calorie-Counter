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

    @IBInspectable var designConstant: CGFloat = .greatestFiniteMagnitude {
        didSet {
            storedDesignConstant = designConstant
            refreshConstant()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        if storedDesignConstant == nil {
            storedDesignConstant = constant
        }
        refreshConstant()
        startObservingSizeChanges()
    }

    deinit {
        if let sizeObserver {
            NotificationCenter.default.removeObserver(sizeObserver)
        }
    }

    func refreshConstant(in container: UIView? = nil) {
        guard let designValue = resolvedDesignConstant else { return }
        let view = container ?? owningView(firstItem) ?? owningView(secondItem)
        let adapted: CGFloat

        switch (adaptToWidth, adaptToHeight) {
        case (true, false):
            adapted = .adaptWidth(designValue, in: view)
        case (false, true):
            adapted = .adaptHeight(designValue, in: view)
        case (true, true):
            adapted = .adaptWidth(designValue, in: view)
        case (false, false):
            adapted = designValue
        }
        // A 44-point tap target must not become smaller because the display is shorter.
        let isControlSize = secondItem == nil && firstItem is UIControl
            && (firstAttribute == .width || firstAttribute == .height)
            && designValue >= 44
        let value = isControlSize ? max(44, adapted) : adapted
        if constant != value { constant = value }
    }

    private func owningView(_ item: AnyObject?) -> UIView? {
        (item as? UIView) ?? (item as? UILayoutGuide)?.owningView
    }

    private var resolvedDesignConstant: CGFloat? {
        if designConstant != .greatestFiniteMagnitude {
            return designConstant
        }
        return storedDesignConstant
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
