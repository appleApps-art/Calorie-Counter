import UIKit

final class ProgressPeriodControl: UIView {
    @IBOutlet private weak var trackView: UIView!
    @IBOutlet private weak var stackView: UIStackView!
    @IBOutlet private weak var weekLabel: AdaptiveLabel!
    @IBOutlet private weak var monthLabel: AdaptiveLabel!
    @IBOutlet private weak var threeMonthsLabel: AdaptiveLabel!
    @IBOutlet private weak var sixMonthsLabel: AdaptiveLabel!

    private let indicatorView = UIView()
    private let tapRecognizer = UITapGestureRecognizer()
    private weak var indicatedLabel: UILabel?
    private var indicatorConstraints: [NSLayoutConstraint] = []

    var selectedPeriod: ProgressChartPeriod = .month {
        didSet { refresh() }
    }
    var onSelect: ((ProgressChartPeriod) -> Void)?

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
        [weekLabel, monthLabel, threeMonthsLabel, sixMonthsLabel]
    }

    private func commonInit() {
        backgroundColor = .clear
        clipsToBounds = false
        layer.masksToBounds = false
        isUserInteractionEnabled = true
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        embedNibContent()
        configureTrack()
        configureIndicator()
        configureLabels()
        configureTap()
        refresh()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: ProgressPeriodControl, _) in
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
        trackView.backgroundColor = AppColor.backgroundsPrimary
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
        indicatorView.accessibilityIdentifier = "progressPeriod.selectionIndicator"
        indicatorView.isUserInteractionEnabled = false
        indicatorView.layer.cornerCurve = .continuous
        indicatorView.clipsToBounds = true
        trackView?.insertSubview(indicatorView, at: 0)
    }

    private func configureLabels() {
        zip(labels, ProgressChartPeriod.allCases).forEach { label, period in
            guard let label else { return }
            label.adaptFontSize = false
            label.textAlignment = .center
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            label.text = period.title
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
        let period = ProgressChartPeriod.allCases[index]
        Haptics.selection()
        selectedPeriod = period
        onSelect?(period)
    }

    private func refresh() {
        zip(labels, ProgressChartPeriod.allCases).forEach { label, period in
            guard let label else { return }
            let selected = period == selectedPeriod
            OnboardingStyle.lockFigmaFont(
                label,
                size: 13,
                weight: selected ? .semibold : .medium,
                color: selected ? AppColor.onAccent : AppColor.labelsPrimary,
                kern: -0.08
            )
            label.textAlignment = .center
        }
        trackView?.backgroundColor = AppColor.backgroundsPrimary
        indicatorView.backgroundColor = AppColor.labelsPrimary
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
        subviews.forEach { $0.layoutIfNeeded() }
    }

    private func layoutIndicator() {
        guard let index = ProgressChartPeriod.allCases.firstIndex(of: selectedPeriod),
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
        OnboardingStyle.applyCardFallbackShadow(layer, traits: traitCollection)
        if bounds.width > 0, bounds.height > 0 {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        }
        let trackHeight = trackView?.bounds.height ?? bounds.height
        trackView?.layer.cornerRadius = trackHeight / 2
        trackView?.layer.cornerCurve = .continuous
    }
}
