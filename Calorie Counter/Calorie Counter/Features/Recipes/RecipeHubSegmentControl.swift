import UIKit

final class RecipeHubSegmentControl: UIView {
    @IBOutlet private weak var trackView: UIView!
    @IBOutlet private weak var stackView: UIStackView!
    @IBOutlet private weak var allLabel: AdaptiveLabel!
    @IBOutlet private weak var savedLabel: AdaptiveLabel!
    @IBOutlet private weak var mealPlansLabel: AdaptiveLabel!

    private let indicatorView = UIView()
    private let tapRecognizer = UITapGestureRecognizer()
    private weak var indicatedLabel: UILabel?
    private var indicatorConstraints: [NSLayoutConstraint] = []

    var selectedTab: RecipeHubTab = .all {
        didSet { refresh() }
    }
    var onSelect: ((RecipeHubTab) -> Void)?
    var onSelectIndex: ((Int) -> Void)?
    private var customTitles: [String]?

    var selectedIndex: Int {
        get { RecipeHubTab.allCases.firstIndex(of: selectedTab) ?? 0 }
        set {
            guard RecipeHubTab.allCases.indices.contains(newValue) else { return }
            selectedTab = RecipeHubTab.allCases[newValue]
        }
    }

    func configure(titles: [String], selectedIndex: Int) {
        guard titles.count == RecipeHubTab.allCases.count else { return }
        customTitles = titles
        configureLabels()
        self.selectedIndex = selectedIndex
    }

    func selectSegment(at index: Int) {
        guard RecipeHubTab.allCases.indices.contains(index) else { return }
        Haptics.selection()
        selectedIndex = index
        onSelect?(selectedTab)
        onSelectIndex?(index)
    }

    override func accessibilityIncrement() {
        selectSegment(at: min(selectedIndex + 1, RecipeHubTab.allCases.count - 1))
    }

    override func accessibilityDecrement() {
        selectSegment(at: max(selectedIndex - 1, 0))
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: .adaptHeight(32, in: self))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private var labels: [AdaptiveLabel?] {
        [allLabel, savedLabel, mealPlansLabel]
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        layer.masksToBounds = false
        isUserInteractionEnabled = true
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        embedNibContent()
        configureTrack()
        configureIndicator()
        configureLabels()
        configureTap()
        refresh()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: RecipeHubSegmentControl, _) in
            view.refresh()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refresh()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutNestedContent()
        refreshChrome()
        layoutIndicator()
    }

    private func configureTrack() {
        guard let trackView else { return }
        trackView.backgroundColor = AppColor.backgroundsPrimaryElevated
        trackView.clipsToBounds = true
        trackView.layer.masksToBounds = true
        trackView.layer.cornerCurve = .continuous
        trackView.isUserInteractionEnabled = true
        stackView?.alignment = .center
        stackView?.distribution = .fillEqually
        stackView?.spacing = .adaptWidth(4)
        stackView?.isUserInteractionEnabled = false
    }

    private func configureIndicator() {
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.accessibilityIdentifier = "recipeHub.selectionIndicator"
        indicatorView.isUserInteractionEnabled = false
        indicatorView.layer.cornerCurve = .continuous
        indicatorView.clipsToBounds = true
        trackView?.insertSubview(indicatorView, at: 0)
    }

    private func configureLabels() {
        zip(labels, RecipeHubTab.allCases).forEach { label, tab in
            guard let label else { return }
            label.adaptFontSize = false
            label.textAlignment = .center
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            label.text = title(for: tab)
        }
    }

    private func configureTap() {
        tapRecognizer.removeTarget(self, action: #selector(handleTap(_:)))
        tapRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        if tapRecognizer.view !== self {
            addGestureRecognizer(tapRecognizer)
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: trackView)
        guard let index = segmentIndex(at: location) else { return }
        selectSegment(at: index)
    }

    private func refresh() {
        accessibilityLabel = RecipeHubTab.allCases.map { title(for: $0) }.joined(separator: ", ")
        accessibilityValue = title(for: selectedTab)
        zip(labels, RecipeHubTab.allCases).forEach { label, tab in
            guard let label else { return }
            let selected = tab == selectedTab
            OnboardingStyle.lockFigmaFont(
                label,
                size: 13,
                weight: selected ? .semibold : .medium,
                color: selected ? AppColor.onAccent : AppColor.labelsPrimary,
                kern: -0.08
            )
            label.textAlignment = .center
        }
        trackView?.backgroundColor = AppColor.backgroundsPrimaryElevated
        indicatorView.backgroundColor = AppColor.teal
        layoutIndicator()
        setNeedsLayout()
        layoutIfNeeded()
    }

    private func segmentIndex(at point: CGPoint) -> Int? {
        let frames = segmentFrames()
        guard !frames.isEmpty else { return nil }
        if let index = frames.firstIndex(where: { $0.contains(point) }) {
            return index
        }
        if point.y < 0 || point.y > (trackView?.bounds.height ?? bounds.height) {
            return nil
        }
        return frames.enumerated().min(by: {
            abs($0.element.midX - point.x) < abs($1.element.midX - point.x)
        })?.offset
    }

    private func segmentFrames() -> [CGRect] {
        guard let trackView, let stackView else { return [] }
        layoutNestedContent()
        let stackFrame = stackView.convert(stackView.bounds, to: trackView)
        return labels.compactMap { label in
            guard let label else { return nil }
            let frame = label.convert(label.bounds, to: trackView)
            return CGRect(x: frame.minX, y: stackFrame.minY, width: frame.width, height: stackFrame.height)
        }
    }

    private func layoutNestedContent() {
        let spacing = CGFloat.adaptWidth(4, in: self)
        if stackView?.spacing != spacing { stackView?.spacing = spacing }
        // The embedded nib lays out after its host. Resolve that subtree before reading its frames.
        subviews.forEach { $0.layoutIfNeeded() }
    }

    private func layoutIndicator() {
        guard let index = RecipeHubTab.allCases.firstIndex(of: selectedTab),
              labels.indices.contains(index), let label = labels[index],
              let stackView else { return }
        if indicatedLabel !== label {
            NSLayoutConstraint.deactivate(indicatorConstraints)
            indicatorConstraints = [
                indicatorView.leadingAnchor.constraint(equalTo: label.leadingAnchor),
                indicatorView.trailingAnchor.constraint(equalTo: label.trailingAnchor),
                indicatorView.topAnchor.constraint(equalTo: stackView.topAnchor),
                indicatorView.bottomAnchor.constraint(equalTo: stackView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(indicatorConstraints)
            indicatedLabel = label
        }
        // Auto Layout keeps the pill under the selected label throughout window resizing.
        indicatorView.layer.cornerRadius = max(0, bounds.height - CGFloat.adaptHeight(4, in: self)) / 2
        if let trackView, stackView.superview === trackView,
           let indicatorIndex = trackView.subviews.firstIndex(of: indicatorView),
           let stackIndex = trackView.subviews.firstIndex(of: stackView), indicatorIndex > stackIndex {
            trackView.insertSubview(indicatorView, belowSubview: stackView)
        }
    }

    private func refreshChrome() {
        let radius = bounds.height / 2
        layer.cornerRadius = radius
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
        OnboardingStyle.applyCardFallbackShadow(layer, traits: traitCollection, radius: 8)
        layer.shadowOpacity = 0.1
        if bounds.width > 0, bounds.height > 0 {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        }
        let trackHeight = trackView?.bounds.height ?? bounds.height
        trackView?.layer.cornerRadius = trackHeight / 2
        trackView?.layer.cornerCurve = .continuous
    }

    private func title(for tab: RecipeHubTab) -> String {
        if let customTitles, let index = RecipeHubTab.allCases.firstIndex(of: tab) {
            return customTitles[index]
        }
        switch tab {
        case .all: return L10n.tr("recipes.tab.all")
        case .saved: return L10n.tr("recipes.tab.saved")
        case .mealPlans: return L10n.tr("recipes.tab.mealPlans")
        }
    }
}
