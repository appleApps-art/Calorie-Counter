import UIKit

/// The three Premium benefits: a dark rounded tile with a symbol, then the benefit.
final class PaywallBenefitsView: UIStackView {
    private static let benefits: [(symbol: String, key: String)] = [
        ("infinity", "paywall.benefit.scanning"),
        ("sparkles", "paywall.benefit.memory"),
        ("heart.text.square", "paywall.benefit.insights")
    ]

    init(tileColor: UIColor, spacing: CGFloat) {
        super.init(frame: .zero)
        axis = .vertical
        self.spacing = spacing
        for benefit in Self.benefits {
            addArrangedSubview(Self.row(symbol: benefit.symbol, title: L10n.tr(benefit.key), tileColor: tileColor))
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func row(symbol: String, title: String, tileColor: UIColor) -> UIView {
        let tile = UIView()
        tile.backgroundColor = tileColor
        tile.layer.cornerRadius = .adaptWidth(8)
        tile.layer.cornerCurve = .continuous
        let icon = UIImageView(image: OnboardingStyle.symbol(symbol, pointSize: .adaptFont(17), weight: .regular)?
            .withRenderingMode(.alwaysTemplate))
        icon.tintColor = AppColor.dynamic(light: .white, dark: UIColor(white: 138 / 255, alpha: 1))
        icon.contentMode = .center
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: .adaptFont(17), weight: .regular)
        label.textColor = AppColor.labelsPrimary
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.textAlignment = .natural

        let row = UIView()
        row.isAccessibilityElement = true
        row.accessibilityLabel = title
        [tile, label].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }
        icon.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            tile.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            tile.topAnchor.constraint(equalTo: row.topAnchor),
            tile.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            tile.widthAnchor.constraint(equalToConstant: .adaptWidth(38)),
            tile.heightAnchor.constraint(equalToConstant: .adaptWidth(38)),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: tile.trailingAnchor, constant: .adaptWidth(16)),
            label.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            label.centerYAnchor.constraint(equalTo: tile.centerYAnchor)
        ])
        return row
    }
}

/// Today nothing is charged, a reminder before the trial ends, then the subscription starts: teal
/// tiles joined by a thin line, as the onboarding paywall shows it.
final class PaywallTimelineCardView: UIView {
    private let card = AdaptiveView()
    private let rowsStack = UIStackView()
    private let line = UIView()
    private var lineConstraints: [NSLayoutConstraint] = []

    init(fillColor: UIColor) {
        super.init(frame: .zero)
        card.useLiveGlass = false
        card.applyCardShadow = true
        card.cardFillColor = fillColor
        card.adaptCornerRadius = true
        card.designCornerRadius = 24
        rowsStack.axis = .vertical
        line.backgroundColor = AppColor.teal
        [card, line, rowsStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowsStack.topAnchor.constraint(equalTo: topAnchor, constant: .adaptHeight(4)),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -.adaptHeight(4)),
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: .adaptWidth(16)),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -.adaptWidth(16))
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ steps: [PaywallTimelineStep]) {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        NSLayoutConstraint.deactivate(lineConstraints)
        var tiles: [UIView] = []
        for (index, step) in steps.enumerated() {
            let (row, tile) = Self.row(step, showsSeparator: index > 0)
            tiles.append(tile)
            rowsStack.addArrangedSubview(row)
        }
        // The line runs from the first tile down to the last one, through the tiles between.
        guard let first = tiles.first, let last = tiles.last, tiles.count > 1 else {
            lineConstraints = []
            line.isHidden = true
            return
        }
        line.isHidden = false
        lineConstraints = [
            line.centerXAnchor.constraint(equalTo: first.centerXAnchor),
            line.topAnchor.constraint(equalTo: first.bottomAnchor),
            line.bottomAnchor.constraint(equalTo: last.topAnchor),
            line.widthAnchor.constraint(equalToConstant: 1)
        ]
        NSLayoutConstraint.activate(lineConstraints)
    }

    private static func row(_ step: PaywallTimelineStep, showsSeparator: Bool) -> (UIView, UIView) {
        let tile = UIView()
        tile.backgroundColor = AppColor.teal
        tile.layer.cornerRadius = .adaptWidth(8)
        tile.layer.cornerCurve = .continuous
        let icon = UIImageView(image: OnboardingStyle.symbol(step.symbol, pointSize: .adaptFont(17), weight: .regular)?
            .withRenderingMode(.alwaysTemplate))
        icon.tintColor = .white
        icon.contentMode = .center
        let title = UILabel()
        title.text = step.title
        title.font = .systemFont(ofSize: .adaptFont(17), weight: .regular)
        title.textColor = AppColor.labelsPrimary
        title.setContentHuggingPriority(.required, for: .horizontal)
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        let detail = UILabel()
        detail.text = step.detail
        detail.font = .systemFont(ofSize: .adaptFont(17), weight: .regular)
        detail.textColor = AppColor.labelsSecondary
        detail.textAlignment = .trailing
        detail.adjustsFontSizeToFitWidth = true
        detail.minimumScaleFactor = 0.7
        let separator = UIView()
        separator.backgroundColor = AppColor.separatorOnCard
        separator.isHidden = !showsSeparator

        let row = UIView()
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(step.title), \(step.detail)"
        [tile, title, detail, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview($0)
        }
        icon.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(icon)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: .adaptHeight(52)),
            tile.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            tile.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            tile.widthAnchor.constraint(equalToConstant: .adaptWidth(36)),
            tile.heightAnchor.constraint(equalToConstant: .adaptWidth(36)),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
            title.leadingAnchor.constraint(equalTo: tile.trailingAnchor, constant: .adaptWidth(16)),
            title.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            detail.leadingAnchor.constraint(greaterThanOrEqualTo: title.trailingAnchor, constant: .adaptWidth(12)),
            detail.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            detail.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            separator.topAnchor.constraint(equalTo: row.topAnchor),
            separator.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
        return (row, tile)
    }
}

/// The sitting mascot among teal fruit and vegetable silhouettes, placed and turned as in the
/// 328 x 163 design frame and scaled to the screen.
final class PaywallIllustrationView: UIView {
    private struct Piece {
        let name: String
        let center: CGPoint
        let size: CGSize
        let degrees: CGFloat
    }

    static let designSize = CGSize(width: 328.606, height: 163.277)

    private static let pieces: [Piece] = [
        Piece(name: "PaywallObject07", center: CGPoint(x: 93.8, y: 61.6), size: CGSize(width: 46.01, height: 45.78), degrees: -26.97),
        Piece(name: "PaywallObject06", center: CGPoint(x: 220.8, y: 67.4), size: CGSize(width: 25.05, height: 32.76), degrees: 47.63),
        Piece(name: "PaywallObject05", center: CGPoint(x: 247.9, y: 115.6), size: CGSize(width: 44.46, height: 48.76), degrees: 58.09),
        Piece(name: "PaywallObject04", center: CGPoint(x: 94.3, y: 115.9), size: CGSize(width: 34.05, height: 32.85), degrees: -24.71),
        Piece(name: "PaywallObject03", center: CGPoint(x: 44.7, y: 50.9), size: CGSize(width: 24.13, height: 29.53), degrees: -40.72),
        Piece(name: "PaywallObject02", center: CGPoint(x: 42.7, y: 97.5), size: CGSize(width: 73.52, height: 72.42), degrees: 78.69),
        Piece(name: "PaywallObject01", center: CGPoint(x: 279.8, y: 48.1), size: CGSize(width: 60.80, height: 76.43), degrees: 48.64)
    ]

    private var pieceViews: [(UIImageView, Piece)] = []
    private let dogView = UIImageView(image: UIImage(named: "PaywallMascotSitting"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        for piece in Self.pieces {
            let view = UIImageView(image: UIImage(named: piece.name))
            view.contentMode = .scaleToFill
            addSubview(view)
            pieceViews.append((view, piece))
        }
        dogView.contentMode = .scaleAspectFit
        addSubview(dogView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = min(bounds.width / Self.designSize.width, bounds.height / Self.designSize.height)
        let origin = CGPoint(
            x: (bounds.width - Self.designSize.width * scale) / 2,
            y: (bounds.height - Self.designSize.height * scale) / 2
        )
        for (view, piece) in pieceViews {
            view.transform = .identity
            view.bounds = CGRect(x: 0, y: 0, width: piece.size.width * scale, height: piece.size.height * scale)
            view.center = CGPoint(x: origin.x + piece.center.x * scale, y: origin.y + piece.center.y * scale)
            view.transform = CGAffineTransform(rotationAngle: piece.degrees * .pi / 180)
        }
        dogView.frame = CGRect(
            x: origin.x + 92.93 * scale,
            y: origin.y + 6.82 * scale,
            width: 134.678 * scale,
            height: 156.46 * scale
        )
    }
}
