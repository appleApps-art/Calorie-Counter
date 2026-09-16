import ObjectiveC
import UIKit

enum ControlHaptic: Int {
    case none
    case light
    case medium
    case rigid
    case selection
    case warning
}

enum Haptics {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static var didInstall = false

    static func install() {
        guard !didInstall else { return }
        didInstall = true
        swizzleSendActions()
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionGenerator.prepare()
    }

    static func light() {
        play(.light)
    }

    static func medium() {
        play(.medium)
    }

    static func rigid() {
        play(.rigid)
    }

    static func selection() {
        play(.selection)
    }

    static func success() {
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    static func warning() {
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    static func error() {
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }

    static func play(_ haptic: ControlHaptic) {
        switch haptic {
        case .none:
            return
        case .light:
            lightImpact.impactOccurred()
            lightImpact.prepare()
        case .medium:
            mediumImpact.impactOccurred()
            mediumImpact.prepare()
        case .rigid:
            rigidImpact.impactOccurred()
            rigidImpact.prepare()
        case .selection:
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        case .warning:
            warning()
        }
    }

    fileprivate static func interpret(_ control: UIControl, events: UIControl.Event) {
        guard control.isEnabled, !isTabBarControl(control) else { return }
        if events.contains(.valueChanged) {
            playValueChanged(control)
            return
        }
        if events.contains(.touchUpInside) || events.contains(.primaryActionTriggered) {
            playTap(control)
        }
    }

    private static func playTap(_ control: UIControl) {
        if control is UITextField || control is UISlider || control is UISwitch { return }
        play(resolvedTapHaptic(for: control))
    }

    private static func playValueChanged(_ control: UIControl) {
        if control is UITextField || control is UISlider || control is UIDatePicker || control is UIRefreshControl {
            return
        }
        if let haptic = control.controlHaptic {
            play(haptic)
            return
        }
        if control is UISwitch {
            play(.light)
            return
        }
        play(.selection)
    }

    private static func resolvedTapHaptic(for control: UIControl) -> ControlHaptic {
        if let haptic = control.controlHaptic { return haptic }
        if control is UIButton { return .light }
        return .selection
    }

    private static func isTabBarControl(_ control: UIControl) -> Bool {
        var node: UIView? = control
        while let view = node {
            if view is UITabBar { return true }
            node = view.superview
        }
        return false
    }

    private static func swizzleSendActions() {
        let original = #selector(UIControl.sendActions(for:))
        let swizzled = #selector(UIControl.haptics_sendActions(for:))
        guard
            let originalMethod = class_getInstanceMethod(UIControl.self, original),
            let swizzledMethod = class_getInstanceMethod(UIControl.self, swizzled)
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

private var controlHapticKey: UInt8 = 0

extension UIControl {
    var controlHaptic: ControlHaptic? {
        get {
            guard let raw = objc_getAssociatedObject(self, &controlHapticKey) as? NSNumber else {
                return nil
            }
            return ControlHaptic(rawValue: raw.intValue)
        }
        set {
            objc_setAssociatedObject(
                self,
                &controlHapticKey,
                newValue.map { NSNumber(value: $0.rawValue) },
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    @objc
    fileprivate func haptics_sendActions(for controlEvents: UIControl.Event) {
        haptics_sendActions(for: controlEvents)
        Haptics.interpret(self, events: controlEvents)
    }
}
