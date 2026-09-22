import UIKit

class BaseViewController: UIViewController {
    private var lastAdaptiveBounds: CGSize = .zero
    private let scrollEdgeFades = ScrollEdgeFadeBinder()
    private let keyboardDismissBinder = KeyboardDismissBinder()

    var analyticsScreen: AnalyticsScreen? { nil }
    var keyboardDismissExcludedViews: [UIView] { [] }

    init(nibName: String) {
        super.init(nibName: nibName, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardDismissBinder.attach(to: self, excluding: { [weak self] in
            self?.keyboardDismissExcludedViews ?? []
        })
        bindViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as? MainTabBarController)?.refreshTabBarChrome(for: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (tabBarController as? MainTabBarController)?.refreshTabBarChrome(for: self)
        if let analyticsScreen {
            Analytics.tracker.track(.screenViewed(analyticsScreen))
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let leftForGood = isBeingDismissed || isMovingFromParent
            || navigationController?.isBeingDismissed == true
        if leftForGood, let analyticsScreen {
            Analytics.hub.journey.leave(analyticsScreen.rawValue)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        compensateHiddenTabBarSafeArea()
        keyboardDismissBinder.refreshScrollViews(in: view)
        scrollEdgeFades.refresh(in: view)
        let boundsSize = view.bounds.size
        guard boundsSize != lastAdaptiveBounds else { return }
        lastAdaptiveBounds = boundsSize
        view.refreshAdaptiveLayout()
    }

    private func compensateHiddenTabBarSafeArea() {
        let tabBarIsHidden = hidesBottomBarWhenPushed
            && navigationController?.viewControllers.first !== self
        let isPresented = presentingViewController != nil
        guard tabBarIsHidden || isPresented else {
            if additionalSafeAreaInsets.bottom != 0 {
                additionalSafeAreaInsets.bottom = 0
            }
            return
        }
        let windowBottom = view.window?.safeAreaInsets.bottom ?? 0
        let rawBottom = view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom
        let needed = min(0, windowBottom - rawBottom)
        if abs(additionalSafeAreaInsets.bottom - needed) > 0.5 {
            additionalSafeAreaInsets.bottom = needed
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        view.refreshAdaptiveLayout()
    }

    func bindViewModel() {}
}

/// Applies a fixed viewport fade without taking over list or table delegates.
final class ScrollEdgeFadeBinder {
    private var bindings: [ObjectIdentifier: ScrollEdgeFadeBinding] = [:]

    func refresh(in root: UIView) {
        var scrolls: [UIScrollView] = []
        func collect(_ view: UIView) {
            if let scroll = view as? UIScrollView {
                let horizontalCollection = (scroll as? UICollectionView).flatMap {
                    $0.collectionViewLayout as? UICollectionViewFlowLayout
                }?.scrollDirection == .horizontal
                if !(scroll is UITextView), !scroll.isPagingEnabled,
                   !scroll.alwaysBounceHorizontal, !horizontalCollection {
                    scrolls.append(scroll)
                }
                return // Nested carousels and cell content keep their own appearance.
            }
            view.subviews.forEach(collect)
        }
        collect(root)
        let ids = Set(scrolls.map(ObjectIdentifier.init))
        bindings = bindings.filter { ids.contains($0.key) }
        for scroll in scrolls {
            let id = ObjectIdentifier(scroll)
            if bindings[id] == nil, scroll.layer.mask == nil {
                bindings[id] = ScrollEdgeFadeBinding(scrollView: scroll)
            }
            bindings[id]?.update()
        }
    }
}

private final class ScrollEdgeFadeBinding {
    private weak var scrollView: UIScrollView?
    private let gradient = CAGradientLayer()
    private var observations: [NSKeyValueObservation] = []

    init(scrollView: UIScrollView) {
        self.scrollView = scrollView
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        scrollView.layer.mask = gradient
        observations = [
            scrollView.observe(\.frame, options: [.new]) { [weak self] _, _ in self?.update() },
            scrollView.observe(\.bounds, options: [.new]) { [weak self] _, _ in self?.update() },
            scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, _ in self?.update() }
        ]
        update()
    }

    deinit {
        if scrollView?.layer.mask === gradient { scrollView?.layer.mask = nil }
    }

    func update() {
        guard let scrollView, scrollView.bounds.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // bounds.origin changes during scrolling; the fade must stay at the viewport edge.
        gradient.frame = scrollView.bounds
        let insets = scrollView.adjustedContentInset
        let fitsVertically = scrollView.contentSize.height + insets.top + insets.bottom
            <= scrollView.bounds.height + 1
        let horizontalOnly = scrollView.contentSize.width > scrollView.bounds.width + 1 && fitsVertically
        // Content that fits has nothing hidden past the edge; fading it would only eat into visible
        // cards (the scan result's nutrient tiles dissolved at the bottom).
        let noFade = horizontalOnly || fitsVertically
        let edge = noFade ? 0 : min(CGFloat.adaptHeight(16), scrollView.bounds.height / 2)
        let fraction = Double(edge / scrollView.bounds.height)
        gradient.locations = [0, NSNumber(value: fraction), NSNumber(value: 1 - fraction), 1]
        gradient.colors = noFade
            ? [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
            : [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        CATransaction.commit()
    }
}
