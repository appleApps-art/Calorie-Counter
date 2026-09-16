import UIKit

enum RecipeShareCardRenderer {
    private static let canvasWidth = CGFloat(804)

    static func render(
        title: String,
        photo: UIImage?,
        chips: [RecipeMetaChip],
        ingredients: [FoodIngredient],
        steps: [String]
    ) -> UIImage? {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let canvas = AppColor.canvas.resolvedColor(with: light)
        let width = canvasWidth
        let inset: CGFloat = 24
        let gutter: CGFloat = 16

        let root = UIView()
        root.backgroundColor = canvas
        root.overrideUserInterfaceStyle = .light
        root.translatesAutoresizingMaskIntoConstraints = false

        let header = PhotoHeaderView(photo: photo, fadeColor: canvas)
        header.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(header)

        let chipsRow = UIStackView()
        chipsRow.axis = .horizontal
        chipsRow.alignment = .center
        chipsRow.spacing = 8
        chipsRow.translatesAutoresizingMaskIntoConstraints = false
        chips.forEach { chipsRow.addArrangedSubview(makeChip($0, traits: light)) }
        chipsRow.isHidden = chips.isEmpty
        header.addSubview(chipsRow)

        let titleLabel = UILabel()
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .center
        titleLabel.text = title
        styleLabel(titleLabel, size: 22, weight: .bold, color: AppColor.labelsPrimary.resolvedColor(with: light), kern: -0.26, wraps: true)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        let columns = UIStackView()
        columns.axis = .horizontal
        columns.alignment = .top
        columns.distribution = .fillEqually
        columns.spacing = gutter
        columns.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(columns)

        if !ingredients.isEmpty {
            columns.addArrangedSubview(
                makeColumn(
                    title: L10n.tr("product.details.ingredients"),
                    content: makeIngredientsList(ingredients, traits: light)
                )
            )
        }
        if !steps.isEmpty {
            columns.addArrangedSubview(
                makeColumn(
                    title: L10n.tr("recipes.details.instructions"),
                    content: makeStepsList(steps, traits: light)
                )
            )
        }
        columns.isHidden = columns.arrangedSubviews.isEmpty
        let brand = UILabel()
        brand.text = "Bity"
        brand.font = .systemFont(ofSize: 15, weight: .semibold)
        brand.textColor = UIColor(red: 0, green: 0.5, blue: 0.55, alpha: 1)
        brand.textAlignment = .center
        brand.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(brand)

        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalToConstant: width),
            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            header.heightAnchor.constraint(greaterThanOrEqualToConstant: photo == nil ? 112 : 240),
            chipsRow.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: inset),
            chipsRow.topAnchor.constraint(equalTo: header.topAnchor, constant: 16),
            chipsRow.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -inset),
            titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: inset),
            titleLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -inset),
            titleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16),
            titleLabel.topAnchor.constraint(greaterThanOrEqualTo: chipsRow.bottomAnchor, constant: photo == nil ? 16 : 100),
            columns.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            columns.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: inset),
            columns.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -inset),
            columns.bottomAnchor.constraint(equalTo: brand.topAnchor, constant: -24),
            brand.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            brand.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20)
        ])

        let height = fittedHeight(for: root, width: width)
        root.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        root.layoutIfNeeded()
        applyPreferredMaxLayoutWidths(in: root)
        let finalHeight = fittedHeight(for: root, width: width)
        root.bounds = CGRect(x: 0, y: 0, width: width, height: finalHeight)
        root.layoutIfNeeded()
        return snapshot(root, canvas: canvas)
    }

    private static func fittedHeight(for root: UIView, width: CGFloat) -> CGFloat {
        root.refreshAdaptiveLayout()
        let fitting = root.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return max(ceil(fitting.height), 1)
    }

    private static func applyPreferredMaxLayoutWidths(in view: UIView) {
        if let label = view as? UILabel, label.numberOfLines != 1 {
            let width = label.bounds.width
            if width > 0 {
                label.preferredMaxLayoutWidth = width
            }
        }
        view.subviews.forEach { applyPreferredMaxLayoutWidths(in: $0) }
    }

    private static func styleLabel(
        _ label: UILabel,
        size: CGFloat,
        weight: UIFont.Weight,
        color: UIColor,
        kern: CGFloat,
        wraps: Bool
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = wraps ? .byWordWrapping : .byTruncatingTail
        paragraph.alignment = label.textAlignment
        let text = label.text ?? ""
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .kern: kern,
                .paragraphStyle: paragraph
            ]
        )
        label.numberOfLines = wraps ? 0 : 1
        label.lineBreakMode = wraps ? .byWordWrapping : .byTruncatingTail
        label.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private static func makeChip(_ chip: RecipeMetaChip, traits: UITraitCollection) -> UIView {
        let pill = UIView()
        pill.backgroundColor = AppColor.labelsPrimary.resolvedColor(with: traits)
        pill.layer.cornerRadius = 17
        pill.layer.cornerCurve = .continuous
        pill.clipsToBounds = true

        let icon = UIImageView(
            image: UIImage(
                systemName: chip.symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            )?.withTintColor(UIColor.white, renderingMode: .alwaysOriginal)
        )
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = chip.title
        styleLabel(
            label,
            size: 15,
            weight: .regular,
            color: UIColor.white,
            kern: -0.23,
            wraps: false
        )
        label.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: pill.topAnchor, constant: 7),
            row.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -7),
            pill.heightAnchor.constraint(equalToConstant: 34)
        ])
        return pill
    }

    private static func makeColumn(title: String, content: UIView) -> UIView {
        let header = UILabel()
        header.text = title
        styleLabel(
            header,
            size: 15,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)),
            kern: -0.23,
            wraps: false
        )

        let card = makeCard(content)
        let column = UIStackView(arrangedSubviews: [header, card])
        column.axis = .vertical
        column.alignment = .fill
        column.spacing = 8
        column.setContentHuggingPriority(.required, for: .vertical)
        column.setContentCompressionResistancePriority(.required, for: .vertical)
        return column
    }

    private static func makeCard(_ content: UIView) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 24
        card.layer.cornerCurve = .continuous
        card.clipsToBounds = true
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])

        let wrap = UIView()
        wrap.backgroundColor = .clear
        OnboardingStyle.applyCardFallbackShadow(wrap.layer, traits: UITraitCollection(userInterfaceStyle: .light))
        wrap.setContentHuggingPriority(.required, for: .vertical)
        wrap.setContentCompressionResistancePriority(.required, for: .vertical)
        card.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: wrap.topAnchor),
            card.leadingAnchor.constraint(equalTo: wrap.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: wrap.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: wrap.bottomAnchor)
        ])
        return wrap
    }

    private static func makeIngredientsList(_ items: [FoodIngredient], traits: UITraitCollection) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        items.enumerated().forEach { index, item in
            stack.addArrangedSubview(
                makeIngredientRow(
                    name: item.name,
                    amount: ProductDetailsMath.formatIngredientAmount(item),
                    showsSeparator: index > 0,
                    traits: traits
                )
            )
        }
        return stack
    }

    private static func makeIngredientRow(
        name: String,
        amount: String,
        showsSeparator: Bool,
        traits: UITraitCollection
    ) -> UIView {
        let row = UIView()
        let color = AppColor.labelsPrimary.resolvedColor(with: traits)

        let nameLabel = UILabel()
        nameLabel.text = name
        styleLabel(nameLabel, size: 15, weight: .regular, color: color, kern: -0.23, wraps: true)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let amountLabel = UILabel()
        amountLabel.textAlignment = .right
        amountLabel.text = amount
        styleLabel(amountLabel, size: 15, weight: .regular, color: color, kern: -0.23, wraps: false)
        amountLabel.setContentHuggingPriority(.required, for: .horizontal)
        amountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let line = UIStackView(arrangedSubviews: amount.isEmpty ? [nameLabel] : [nameLabel, amountLabel])
        line.axis = .horizontal
        line.alignment = .top
        line.spacing = 8
        line.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(line)

        let separator = UIView()
        separator.backgroundColor = AppColor.hairline.resolvedColor(with: traits)
        separator.isHidden = !showsSeparator
        separator.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(separator)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: row.topAnchor),
            separator.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            separator.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            separator.heightAnchor.constraint(equalToConstant: 1),
            line.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            line.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            line.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            line.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10)
        ])
        row.setContentCompressionResistancePriority(.required, for: .vertical)
        return row
    }

    private static func makeStepsList(_ steps: [String], traits: UITraitCollection) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        steps.enumerated().forEach { index, step in
            stack.addArrangedSubview(makeStepRow(index: index + 1, text: step, showsSeparator: index > 0, traits: traits))
        }
        return stack
    }

    private static func makeStepRow(index: Int, text: String, showsSeparator: Bool, traits: UITraitCollection) -> UIView {
        let row = UIView()
        let circle = UIView()
        circle.backgroundColor = UIColor(red: 0, green: 0.65, blue: 0.68, alpha: 1)
        circle.layer.cornerRadius = 11
        circle.clipsToBounds = true
        circle.translatesAutoresizingMaskIntoConstraints = false

        let number = UILabel()
        number.textAlignment = .center
        number.text = "\(index)"
        styleLabel(
            number,
            size: 13,
            weight: .semibold,
            color: UIColor.white,
            kern: 0,
            wraps: false
        )
        number.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(number)

        let textLabel = UILabel()
        textLabel.text = text
        styleLabel(
            textLabel,
            size: 15,
            weight: .regular,
            color: AppColor.labelsPrimary.resolvedColor(with: traits),
            kern: -0.23,
            wraps: true
        )
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        let separator = UIView()
        separator.backgroundColor = AppColor.hairline.resolvedColor(with: traits)
        separator.isHidden = !showsSeparator
        separator.translatesAutoresizingMaskIntoConstraints = false

        row.addSubview(separator)
        row.addSubview(circle)
        row.addSubview(textLabel)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: row.topAnchor),
            separator.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            separator.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            separator.heightAnchor.constraint(equalToConstant: 1),
            circle.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 14),
            circle.topAnchor.constraint(equalTo: row.topAnchor, constant: 10),
            circle.widthAnchor.constraint(equalToConstant: 22),
            circle.heightAnchor.constraint(equalToConstant: 22),
            circle.bottomAnchor.constraint(lessThanOrEqualTo: row.bottomAnchor, constant: -10),
            number.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            number.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            textLabel.leadingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 10),
            textLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -14),
            textLabel.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
            textLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -10)
        ])
        row.setContentCompressionResistancePriority(.required, for: .vertical)
        return row
    }

    private static func snapshot(_ view: UIView, canvas: UIColor) -> UIImage? {
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        if let host = snapshotHost() {
            let holder = UIView(frame: CGRect(origin: .zero, size: size))
            holder.backgroundColor = canvas
            holder.isUserInteractionEnabled = false
            holder.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: holder.topAnchor),
                view.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
                view.widthAnchor.constraint(equalToConstant: size.width),
                view.heightAnchor.constraint(equalToConstant: size.height)
            ])
            host.addSubview(holder)
            holder.layoutIfNeeded()
            applyPreferredMaxLayoutWidths(in: view)
            holder.layoutIfNeeded()
            let image = renderer.image { _ in
                holder.drawHierarchy(in: holder.bounds, afterScreenUpdates: true)
            }
            holder.removeFromSuperview()
            return image
        }
        return renderer.image { context in
            canvas.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            view.layer.render(in: context.cgContext)
        }
    }

    private static func snapshotHost() -> UIView? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        return windows.first(where: { $0.isKeyWindow }) ?? windows.first
    }
}

private final class PhotoHeaderView: UIView {
    private let imageView = UIImageView()
    private let fadeView = UIView()
    private let fadeLayer = CAGradientLayer()

    init(photo: UIImage?, fadeColor: UIColor) {
        super.init(frame: .zero)
        clipsToBounds = true
        backgroundColor = fadeColor
        imageView.image = photo
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        fadeView.isUserInteractionEnabled = false
        fadeView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        addSubview(fadeView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fadeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fadeView.trailingAnchor.constraint(equalTo: trailingAnchor),
            fadeView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fadeView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.45)
        ])
        fadeLayer.colors = [fadeColor.withAlphaComponent(0).cgColor, fadeColor.cgColor]
        fadeLayer.locations = [0, 1]
        fadeLayer.startPoint = CGPoint(x: 0.5, y: 0)
        fadeLayer.endPoint = CGPoint(x: 0.5, y: 1)
        fadeView.layer.addSublayer(fadeLayer)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fadeLayer.frame = fadeView.bounds
    }
}
