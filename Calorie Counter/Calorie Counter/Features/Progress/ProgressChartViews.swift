import UIKit

private enum ProgressChartLayout {
    static var yGutter: CGFloat { .adaptWidth(34) }
    static var yLabelGap: CGFloat { .adaptWidth(4) }
    static var xLabelHeight: CGFloat { .adaptHeight(13) }
    static var designBarGap: CGFloat { .adaptWidth(8) }
    static var designBarWidth: CGFloat { .adaptWidth(37) }
    static var capRadius: CGFloat { .adaptWidth(12) }
    static var pointSize: CGFloat { .adaptWidth(16) }
    static var selectedAlpha: CGFloat { 1 }
    static var dimmedAlpha: CGFloat { 0.35 }
    static var axisFontSize: CGFloat { .adaptFont(11) }

    static func plotRect(in bounds: CGRect, scale: ProgressChartScale) -> CGRect {
        plotRect(in: bounds, yGutter: gutter(for: scale))
    }

    static func plotRect(in bounds: CGRect, yGutter gutter: CGFloat) -> CGRect {
        CGRect(
            x: gutter,
            y: 0,
            width: max(0, bounds.width - gutter),
            height: max(0, bounds.height - xLabelHeight)
        )
    }

    static func gutter(for scale: ProgressChartScale) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: axisFontSize, weight: .regular),
            .kern: 0.06
        ]
        let maxWidth = (ProgressChartMath.axisNumber(scale.max) as NSString).size(withAttributes: attributes).width
        let minWidth = (ProgressChartMath.axisNumber(scale.min) as NSString).size(withAttributes: attributes).width
        return max(yGutter, ceil(max(maxWidth, minWidth)) + yLabelGap)
    }

    static func barLayout(count: Int, plotWidth: CGFloat) -> (width: CGFloat, gap: CGFloat) {
        let bars = max(count, 1)
        if bars == 1 {
            return (min(designBarWidth, plotWidth), 0)
        }
        let gap = designBarGap
        let width = max(1, (plotWidth - gap * CGFloat(bars - 1)) / CGFloat(bars))
        return (width, gap)
    }

    static func roundedTopPath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        guard rect.width > 0, rect.height > 0 else { return path }
        let radius = min(capRadius, rect.width / 2, rect.height)
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        path.move(to: CGPoint(x: minX, y: maxY))
        if radius <= 0 {
            path.addLine(to: CGPoint(x: minX, y: minY))
            path.addLine(to: CGPoint(x: maxX, y: minY))
            path.addLine(to: CGPoint(x: maxX, y: maxY))
            path.close()
            return path
        }
        path.addLine(to: CGPoint(x: minX, y: minY + radius))
        path.addArc(
            withCenter: CGPoint(x: minX + radius, y: minY + radius),
            radius: radius,
            startAngle: .pi,
            endAngle: 3 * .pi / 2,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: maxX - radius, y: minY))
        path.addArc(
            withCenter: CGPoint(x: maxX - radius, y: minY + radius),
            radius: radius,
            startAngle: 3 * .pi / 2,
            endAngle: 0,
            clockwise: true
        )
        path.addLine(to: CGPoint(x: maxX, y: maxY))
        path.close()
        return path
    }
}

final class ProgressStackedBarChartView: UIView {
    var columns: [ProgressMacroColumn] = [] {
        didSet { setNeedsDisplay(); refreshCallout() }
    }
    var target: Double = 0 {
        didSet { setNeedsDisplay() }
    }
    var selectedIndex: Int? {
        didSet { setNeedsDisplay(); refreshCallout() }
    }
    var onSelect: ((Int?) -> Void)?

    private let callout = ProgressChartCalloutView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        configureChartCanvas()
        addSubview(callout)
        callout.hide()
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let scale = barScale
        let plot = ProgressChartLayout.plotRect(in: bounds, scale: scale)
        drawGrid(in: plot)
        drawTarget(in: plot, scale: scale)
        drawStacks(in: plot, scale: scale, context: context)
        drawYAxis(scale: scale)
        drawXAxis(in: plot)
        if let selectedIndex, columns.indices.contains(selectedIndex) {
            let layout = ProgressChartLayout.barLayout(count: columns.count, plotWidth: plot.width)
            let barX = plot.minX + CGFloat(selectedIndex) * (layout.width + layout.gap) + layout.width / 2
            drawSelectionIndicator(atX: barX, in: plot)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshCallout()
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let plot = ProgressChartLayout.plotRect(in: bounds, scale: barScale)
        guard !columns.isEmpty, plot.width > 0 else { return }
        let layout = ProgressChartLayout.barLayout(count: columns.count, plotWidth: plot.width)
        let x = location.x - plot.minX
        let index = Int((x / (layout.width + layout.gap)).rounded(.down))
        guard columns.indices.contains(index) else {
            selectedIndex = nil
            onSelect?(nil)
            return
        }
        selectedIndex = selectedIndex == index ? nil : index
        onSelect?(selectedIndex)
        Haptics.selection()
    }

    private var barScale: ProgressChartScale {
        .bars(values: columns.map(\.plotValue), target: target)
    }

    private func drawStacks(in plot: CGRect, scale: ProgressChartScale, context: CGContext) {
        let layout = ProgressChartLayout.barLayout(count: columns.count, plotWidth: plot.width)
        for (index, column) in columns.enumerated() {
            let x = plot.minX + CGFloat(index) * (layout.width + layout.gap)
            let dimmed = selectedIndex != nil && selectedIndex != index
            let alpha = dimmed ? ProgressChartLayout.dimmedAlpha : ProgressChartLayout.selectedAlpha
            let segments: [(CGFloat, UIColor)] = [
                (scale.height(for: column.proteinKcal, in: plot), AppColor.accentBlue),
                (scale.height(for: column.carbsKcal, in: plot), AppColor.accentMint),
                (scale.height(for: column.fatsKcal, in: plot), AppColor.accentIndigo)
            ]
            let totalHeight = segments.reduce(CGFloat(0)) { $0 + max(0, $1.0) }
            guard totalHeight > 0.5 else { continue }
            let barRect = CGRect(
                x: x,
                y: plot.maxY - totalHeight,
                width: layout.width,
                height: totalHeight
            )
            context.saveGState()
            context.addPath(ProgressChartLayout.roundedTopPath(in: barRect).cgPath)
            context.clip()
            var y = plot.maxY
            for segment in segments {
                let height = max(0, segment.0)
                y -= height
                context.setFillColor(segment.1.withAlphaComponent(alpha).resolvedColor(with: traitCollection).cgColor)
                context.fill(CGRect(x: x, y: y, width: layout.width, height: height))
            }
            context.restoreGState()
        }
    }

    private func refreshCallout() {
        guard let selectedIndex, columns.indices.contains(selectedIndex) else {
            callout.hide()
            return
        }
        let column = columns[selectedIndex]
        callout.showStacked(
            title: ProgressChartMath.columnKcalText(column.calories, dayCount: column.aggregationDayCount),
            fats: ProgressChartMath.macroCalloutText(L10n.tr("home.fats"), grams: column.fatsKcal / 9),
            carbs: ProgressChartMath.macroCalloutText(L10n.tr("home.carbs"), grams: column.carbsKcal / 4),
            protein: ProgressChartMath.macroCalloutText(L10n.tr("home.protein"), grams: column.proteinKcal / 4)
        )
        layoutCallout(
            at: selectedIndex,
            count: columns.count,
            value: column.calories,
            scale: barScale
        )
    }
}

final class ProgressBarChartView: UIView {
    var columns: [ProgressValueColumn] = [] {
        didSet { setNeedsDisplay(); refreshCallout() }
    }
    var target: Double = 0 {
        didSet { setNeedsDisplay() }
    }
    var selectedIndex: Int? {
        didSet { setNeedsDisplay(); refreshCallout() }
    }
    var onSelect: ((Int?) -> Void)?

    private let callout = ProgressChartCalloutView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        configureChartCanvas()
        addSubview(callout)
        callout.hide()
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    override func draw(_ rect: CGRect) {
        let scale = barScale
        let plot = ProgressChartLayout.plotRect(in: bounds, scale: scale)
        drawGrid(in: plot)
        drawTarget(in: plot, scale: scale)
        let layout = ProgressChartLayout.barLayout(count: columns.count, plotWidth: plot.width)
        for (index, column) in columns.enumerated() {
            let x = plot.minX + CGFloat(index) * (layout.width + layout.gap)
            let height = scale.height(for: column.value, in: plot)
            guard height > 0.5 else { continue }
            let dimmed = selectedIndex != nil && selectedIndex != index
            let alpha = dimmed ? ProgressChartLayout.dimmedAlpha : ProgressChartLayout.selectedAlpha
            let bar = CGRect(x: x, y: plot.maxY - height, width: layout.width, height: height)
            let path = ProgressChartLayout.roundedTopPath(in: bar)
            AppColor.teal.withAlphaComponent(alpha).setFill()
            path.fill()
        }
        drawYAxis(scale: scale)
        drawXAxis(in: plot)
        if let selectedIndex, columns.indices.contains(selectedIndex) {
            let layout = ProgressChartLayout.barLayout(count: columns.count, plotWidth: plot.width)
            let barX = plot.minX + CGFloat(selectedIndex) * (layout.width + layout.gap) + layout.width / 2
            drawSelectionIndicator(atX: barX, in: plot)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshCallout()
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let plot = ProgressChartLayout.plotRect(in: bounds, scale: barScale)
        guard !columns.isEmpty, plot.width > 0 else { return }
        let layout = ProgressChartLayout.barLayout(count: columns.count, plotWidth: plot.width)
        let index = Int(((location.x - plot.minX) / (layout.width + layout.gap)).rounded(.down))
        guard columns.indices.contains(index) else {
            selectedIndex = nil
            onSelect?(nil)
            return
        }
        selectedIndex = selectedIndex == index ? nil : index
        onSelect?(selectedIndex)
        Haptics.selection()
    }

    private func refreshCallout() {
        guard let selectedIndex, columns.indices.contains(selectedIndex) else {
            callout.hide()
            return
        }
        let column = columns[selectedIndex]
        callout.showCompact(title: ProgressChartMath.columnKcalText(column.value, dayCount: column.aggregationDayCount))
        layoutCallout(
            at: selectedIndex,
            count: columns.count,
            value: column.value,
            scale: barScale
        )
    }

    private var barScale: ProgressChartScale {
        .bars(values: columns.map(\.value), target: target)
    }
}

final class ProgressLineChartView: UIView {
    var columns: [ProgressValueColumn] = [] {
        didSet { setNeedsDisplay(); refreshCallout() }
    }
    var selectedIndex: Int? {
        didSet { setNeedsDisplay(); refreshCallout() }
    }
    var onSelect: ((Int?) -> Void)?

    private let callout = ProgressChartCalloutView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        configureChartCanvas()
        addSubview(callout)
        callout.hide()
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    override func draw(_ rect: CGRect) {
        let scale = lineScale
        let plot = ProgressChartLayout.plotRect(in: bounds, scale: scale)
        guard columns.count >= 1 else {
            drawGrid(in: plot)
            drawYAxis(scale: scale)
            return
        }
        drawGrid(in: plot)
        let inset = ProgressChartLayout.pointSize / 2
        let linePlot = plot.insetBy(dx: inset, dy: inset)
        let points = pointPositions(in: linePlot, scale: scale)
        let path = UIBezierPath()
        path.lineWidth = 2
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        points.enumerated().forEach { index, point in
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        AppColor.teal.setStroke()
        path.stroke()
        let point = ProgressChartLayout.pointSize
        let radius = point / 2
        for (index, origin) in points.enumerated() {
            let dimmed = selectedIndex != nil && selectedIndex != index
            let alpha = dimmed ? ProgressChartLayout.dimmedAlpha : ProgressChartLayout.selectedAlpha
            let dot = UIBezierPath(ovalIn: CGRect(x: origin.x - radius, y: origin.y - radius, width: point, height: point))
            AppColor.teal.withAlphaComponent(alpha).setFill()
            dot.fill()
        }
        drawYAxis(scale: scale)
        drawXAxis(in: plot)
        if let selectedIndex, points.indices.contains(selectedIndex) {
            drawSelectionIndicator(atX: points[selectedIndex].x, in: plot)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshCallout()
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        guard !columns.isEmpty else { return }
        let scale = lineScale
        let plot = ProgressChartLayout.plotRect(in: bounds, scale: scale)
        let inset = ProgressChartLayout.pointSize / 2
        let linePlot = plot.insetBy(dx: inset, dy: inset)
        let points = pointPositions(in: linePlot, scale: scale)
        guard let nearest = points.enumerated().min(by: {
            abs($0.element.x - location.x) < abs($1.element.x - location.x)
        }) else { return }
        selectedIndex = selectedIndex == nearest.offset ? nil : nearest.offset
        onSelect?(selectedIndex)
        Haptics.selection()
    }

    private var lineScale: ProgressChartScale {
        .line(values: columns.map(\.value))
    }

    private func pointPositions(in linePlot: CGRect, scale: ProgressChartScale) -> [CGPoint] {
        columns.enumerated().map { index, column in
            let x: CGFloat
            if columns.count == 1 {
                x = linePlot.midX
            } else {
                x = linePlot.minX + CGFloat(index) / CGFloat(columns.count - 1) * linePlot.width
            }
            return CGPoint(x: x, y: scale.y(for: column.value, in: linePlot))
        }
    }

    private func refreshCallout() {
        guard let selectedIndex, columns.indices.contains(selectedIndex) else {
            callout.hide()
            return
        }
        let column = columns[selectedIndex]
        let title = "\(String(format: "%.1f %@", locale: .current, column.value, AppUnits.current.weightSymbol))\n\(ProgressChartMath.axisDateText(column.date))"
        callout.showCompact(title: title, lines: 2)
        layoutCallout(
            at: selectedIndex,
            count: columns.count,
            value: column.value,
            scale: lineScale,
            usesLineSpacing: true
        )
    }
}

private final class ProgressChartYAxisView: UIView {
    private let maxLabel = UILabel()
    private let minLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = false
        [maxLabel, minLabel].forEach { label in
            label.numberOfLines = 1
            label.textAlignment = .right
            addSubview(label)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(scale: ProgressChartScale, plot: CGRect, traits: UITraitCollection) {
        let font = UIFont.monospacedDigitSystemFont(ofSize: ProgressChartLayout.axisFontSize, weight: .regular)
        let color = AppColor.labelsSecondary.resolvedColor(with: traits)
        maxLabel.font = font
        minLabel.font = font
        maxLabel.textColor = color
        minLabel.textColor = color
        maxLabel.attributedText = Self.axisText(ProgressChartMath.axisNumber(scale.max), font: font, color: color)
        minLabel.attributedText = Self.axisText(ProgressChartMath.axisNumber(scale.min), font: font, color: color)
        maxLabel.sizeToFit()
        minLabel.sizeToFit()
        let right = plot.minX - ProgressChartLayout.yLabelGap
        maxLabel.frame.origin = CGPoint(
            x: right - maxLabel.bounds.width,
            y: plot.minY - 5
        )
        minLabel.frame.origin = CGPoint(
            x: right - minLabel.bounds.width,
            y: plot.maxY - minLabel.bounds.height
        )
    }

    private static func axisText(_ string: String, font: UIFont, color: UIColor) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .kern: 0.06
            ]
        )
    }
}

private extension UIView {
    func configureChartCanvas() {
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = false
        contentMode = .redraw
        if subviews.contains(where: { $0 is ProgressChartYAxisView }) == false {
            let axis = ProgressChartYAxisView()
            axis.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            insertSubview(axis, at: 0)
        }
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _) in
            view.setNeedsDisplay()
        }
    }

    func drawGrid(in plot: CGRect) {
        let color = AppColor.hairline.resolvedColor(with: traitCollection)
        let path = UIBezierPath()
        path.lineWidth = 1
        for step in 0..<4 {
            let y = plot.minY + CGFloat(step) / 3 * plot.height
            path.move(to: CGPoint(x: plot.minX, y: y))
            path.addLine(to: CGPoint(x: plot.maxX, y: y))
        }
        color.setStroke()
        path.stroke()
    }

    func drawTarget(in plot: CGRect, scale: ProgressChartScale) {
        guard scale.range > 0, targetValue > 0 else { return }
        let y = scale.y(for: targetValue, in: plot)
        guard y >= plot.minY - 0.5, y <= plot.maxY + 0.5 else { return }
        let path = UIBezierPath()
        path.lineWidth = 1
        let dash: [CGFloat] = [4, 4]
        path.setLineDash(dash, count: 2, phase: 0)
        path.move(to: CGPoint(x: plot.minX, y: y))
        path.addLine(to: CGPoint(x: plot.maxX, y: y))
        AppColor.labelsPrimary.setStroke()
        path.stroke()
    }

    var targetValue: Double {
        (self as? ProgressStackedBarChartView)?.target
            ?? (self as? ProgressBarChartView)?.target
            ?? 0
    }

    func drawYAxis(scale: ProgressChartScale) {
        let plot = ProgressChartLayout.plotRect(in: bounds, scale: scale)
        let axis = subviews.compactMap { $0 as? ProgressChartYAxisView }.first
            ?? {
                let view = ProgressChartYAxisView()
                view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                insertSubview(view, at: 0)
                return view
            }()
        axis.frame = bounds
        axis.apply(scale: scale, plot: plot, traits: traitCollection)
    }

    func drawXAxis(in plot: CGRect) {
        let dates: [Date]
        if let stacked = self as? ProgressStackedBarChartView {
            dates = stacked.columns.map(\.date)
        } else if let bars = self as? ProgressBarChartView {
            dates = bars.columns.map(\.date)
        } else if let line = self as? ProgressLineChartView {
            dates = line.columns.map(\.date)
        } else {
            dates = []
        }
        guard !dates.isEmpty else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: ProgressChartLayout.axisFontSize, weight: .regular),
            .foregroundColor: AppColor.labelsSecondary,
            .kern: 0.06
        ]
        let labels = axisLabels(from: dates)
        let last = max(labels.count - 1, 1)
        for (position, item) in labels.enumerated() {
            let text = ProgressChartMath.axisDateText(item.1) as NSString
            let size = text.size(withAttributes: attributes)
            let x: CGFloat
            if labels.count == 1 {
                x = plot.midX - size.width / 2
            } else {
                let fraction = CGFloat(position) / CGFloat(last)
                let minX = plot.minX
                let maxX = plot.maxX - size.width
                x = minX + fraction * max(maxX - minX, 0)
            }
            text.draw(
                at: CGPoint(x: x, y: bounds.height - size.height),
                withAttributes: attributes
            )
        }
    }

    func axisLabels(from dates: [Date]) -> [(Int, Date)] {
        guard dates.count > 4 else {
            return dates.enumerated().map { ($0.offset, $0.element) }
        }
        let last = dates.count - 1
        let steps = [0, last / 3, (2 * last) / 3, last]
        return steps.map { ($0, dates[$0]) }
    }

    func drawSelectionIndicator(atX x: CGFloat, in plot: CGRect) {
        let path = UIBezierPath()
        path.lineWidth = 1
        path.move(to: CGPoint(x: x, y: plot.minY))
        path.addLine(to: CGPoint(x: x, y: plot.maxY))
        AppColor.labelsPrimary.setStroke()
        path.stroke()
    }

    func layoutCallout(
        at index: Int,
        count: Int,
        value: Double,
        scale: ProgressChartScale,
        usesLineSpacing: Bool = false
    ) {
        guard let callout = subviews.compactMap({ $0 as? ProgressChartCalloutView }).first else { return }
        callout.isHidden = false
        let plot = ProgressChartLayout.plotRect(in: bounds, scale: scale)
        let layout = ProgressChartLayout.barLayout(count: max(count, 1), plotWidth: plot.width)
        let barX: CGFloat
        let yPlot: CGRect
        if usesLineSpacing {
            let inset = ProgressChartLayout.pointSize / 2
            yPlot = plot.insetBy(dx: inset, dy: inset)
            if count > 1 {
                barX = yPlot.minX + CGFloat(index) / CGFloat(count - 1) * yPlot.width
            } else {
                barX = yPlot.midX
            }
        } else {
            yPlot = plot
            barX = plot.minX + CGFloat(index) * (layout.width + layout.gap) + layout.width / 2
        }
        callout.layoutIfNeeded()
        let size = callout.systemLayoutSizeFitting(
            UIView.layoutFittingCompressedSize,
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        let width = max(size.width, .adaptWidth(55))
        let height = max(size.height, .adaptHeight(21))
        var x = barX - width / 2
        x = min(max(0, x), max(0, bounds.width - width))
        let barTop = scale.y(for: value, in: yPlot)
        var y = barTop - height - .adaptHeight(6)
        y = min(max(-.adaptHeight(16), y), max(0, plot.maxY - height))
        callout.frame = CGRect(x: x, y: y, width: width, height: height)
        bringSubviewToFront(callout)
    }
}
