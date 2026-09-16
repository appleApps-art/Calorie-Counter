import UIKit

enum OnboardingStyle {
    static var accentTeal: UIColor { AppColor.teal }
    static var glassFill: UIColor {
        AppColor.dynamic(
            light: UIColor.white.withAlphaComponent(0.5),
            dark: .black
        )
    }
    static var buttonGlassFill: UIColor {
        AppColor.dynamic(
            light: UIColor.white.withAlphaComponent(0.65),
            dark: UIColor.white.withAlphaComponent(0.18)
        )
    }
    static var labelPrimary: UIColor { AppColor.textPrimary }

    private static var glassFallbackFill: UIColor { buttonGlassFill }

    static func stylePrimaryButton(_ button: UIButton, title: String) {
        prepareForGlass(button)
        button.setAttributedTitle(nil, for: .normal)
        button.setTitle(title, for: .normal)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.title = title
        config.baseForegroundColor = AppColor.onAccent
        config.baseBackgroundColor = accentTeal
        config.background.backgroundColor = accentTeal
        config.titleTextAttributesTransformer = titleTransformer(size: 17, weight: .regular)
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        button.configuration = config
        button.tintColor = accentTeal
        button.layer.shadowOpacity = 0
        button.controlHaptic = .medium
        applyPressFeedback(button)
    }

    static func stylePrimaryButton(_ button: UIButton, title: String, systemImage: String) {
        stylePrimaryButton(button, title: title)
        button.configuration?.image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        )
        button.configuration?.imagePadding = 8
        button.configuration?.imagePlacement = .leading
    }

    static func styleGlassSymbolButton(
        _ button: UIButton,
        systemName: String?,
        foregroundColor: UIColor = labelPrimary,
        liveGlass: Bool = true
    ) {
        let image = symbolImage(systemName)
        if liveGlass, #available(iOS 26.0, *) {
            prepareForGlass(button)
            var config = buttonGlassConfiguration()
            config.image = image?.withTintColor(foregroundColor, renderingMode: .alwaysOriginal)
            config.baseForegroundColor = foregroundColor
            config.contentInsets = .zero
            button.configuration = config
            button.tintColor = foregroundColor
            button.clipsToBounds = false
            button.layer.masksToBounds = false
        } else {
            applyFilledSymbolButton(button, image: image, foregroundColor: foregroundColor)
        }
    }

    static func applyFilledSymbolButton(
        _ button: UIButton,
        image: UIImage?,
        foregroundColor: UIColor
    ) {
        button.configuration = nil
        button.setTitle(nil, for: .normal)
        button.setImage(image?.withTintColor(foregroundColor, renderingMode: .alwaysOriginal), for: .normal)
        button.tintColor = foregroundColor
        button.backgroundColor = glassFallbackFill
        button.clipsToBounds = false
        button.layer.cornerRadius = .adaptWidth(22)
        button.layer.cornerCurve = .continuous
        applyButtonFallbackShadow(button.layer)
        applyPressFeedback(button)
    }

    static func symbolImage(_ systemName: String?) -> UIImage? {
        guard let systemName, !systemName.isEmpty else { return nil }
        return UIImage(
            systemName: systemName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        )
    }

    static func styleChatCategoryChip(
        _ button: UIButton,
        emoji: String,
        title: String,
        selected: Bool
    ) {
        prepareForGlass(button)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        config.imagePadding = 6
        if emoji.isEmpty {
            config.title = title
        } else {
            config.title = "\(emoji)  \(title)"
        }
        config.titleTextAttributesTransformer = titleTransformer(size: 15, weight: .regular)
        if selected {
            config.baseForegroundColor = AppColor.onAccent
            config.baseBackgroundColor = AppColor.labelsPrimary
        } else {
            config.baseForegroundColor = AppColor.labelsPrimary
            config.baseBackgroundColor = fillQuaternary
        }
        config.titleLineBreakMode = .byClipping
        button.configuration = config
        button.backgroundColor = .clear
        button.layer.shadowOpacity = 0
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.controlHaptic = .selection
        applyPressFeedback(button)
    }

    static func configureChatChipsCarousel(_ scrollView: UIScrollView) {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.clipsToBounds = true
    }

    static func applyChatChipsEdgeFade(to scrollView: UIScrollView) {
        let size = scrollView.bounds.size
        guard size.width > 0, size.height > 0 else {
            scrollView.layer.mask = nil
            return
        }
        let fade: CAGradientLayer
        if let existing = scrollView.layer.mask as? CAGradientLayer {
            fade = existing
        } else {
            fade = CAGradientLayer()
            fade.startPoint = CGPoint(x: 0, y: 0.5)
            fade.endPoint = CGPoint(x: 1, y: 0.5)
            fade.colors = [
                UIColor.clear.cgColor,
                UIColor.black.cgColor,
                UIColor.black.cgColor,
                UIColor.clear.cgColor
            ]
            fade.locations = [0, 0.04, 0.96, 1]
            scrollView.layer.mask = fade
        }
        fade.frame = CGRect(origin: scrollView.contentOffset, size: size)
    }

    static func pinChipCarouselFullBleed(_ scrollView: UIScrollView, to host: UIView) {
        configureChatChipsCarousel(scrollView)
        let inset = CGFloat.adaptWidth(16)
        scrollView.contentInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
        if scrollView.superview?.accessibilityIdentifier == Self.chipBleedPlaceholderID {
            return
        }
        guard let stack = scrollView.superview as? UIStackView,
              let index = stack.arrangedSubviews.firstIndex(of: scrollView) else {
            return
        }
        let placeholder = UIView()
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.backgroundColor = .clear
        placeholder.accessibilityIdentifier = Self.chipBleedPlaceholderID
        stack.insertArrangedSubview(placeholder, at: index)
        scrollView.removeFromSuperview()
        placeholder.addSubview(scrollView)
        var node: UIView? = placeholder
        while let current = node, current !== host {
            current.clipsToBounds = false
            node = current.superview
        }
        NSLayoutConstraint.activate([
            placeholder.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            scrollView.topAnchor.constraint(equalTo: placeholder.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: placeholder.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: host.trailingAnchor)
        ])
    }

    private static let chipBleedPlaceholderID = "chipCarouselBleedPlaceholder"

    static func styleTealSymbolButton(_ button: UIButton, systemName: String) {
        prepareForGlass(button)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.baseForegroundColor = AppColor.onAccent
        config.baseBackgroundColor = accentTeal
        config.background.backgroundColor = accentTeal
        config.image = symbolImage(systemName)?.withTintColor(AppColor.onAccent, renderingMode: .alwaysOriginal)
        config.contentInsets = .zero
        button.configuration = config
        button.tintColor = AppColor.onAccent
        button.layer.shadowOpacity = 0
        button.controlHaptic = .medium
        applyPressFeedback(button)
    }

    static func styleSelectionChip(_ button: UIButton, title: String, selected: Bool) {
        prepareForGlass(button)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.title = title
        config.titleTextAttributesTransformer = titleTransformer(size: 15, weight: .regular)
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        if selected {
            config.baseForegroundColor = AppColor.onAccent
            config.baseBackgroundColor = accentTeal
        } else {
            config.baseForegroundColor = labelPrimary
            config.baseBackgroundColor = fillQuaternary
        }
        button.configuration = config
        button.backgroundColor = .clear
        button.layer.shadowOpacity = 0
        button.controlHaptic = .selection
        applyPressFeedback(button)
    }

    static var fillQuaternary: UIColor { AppColor.fillQuaternary }

    static func styleGlassButton(
        _ button: UIButton,
        title: String,
        foregroundColor: UIColor = labelPrimary,
        weight: UIFont.Weight = .regular
    ) {
        prepareForGlass(button)
        button.setAttributedTitle(nil, for: .normal)
        button.setTitle(title, for: .normal)
        if #available(iOS 26.0, *) {
            var config = buttonGlassConfiguration()
            config.buttonSize = .large
            config.title = title
            config.baseForegroundColor = foregroundColor
            config.titleTextAttributesTransformer = titleTransformer(size: 17, weight: weight)
            button.configuration = config
        } else {
            button.configuration = nil
            button.setTitle(title, for: .normal)
            button.setTitleColor(foregroundColor, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 17, weight: weight)
            button.backgroundColor = glassFallbackFill
            button.layer.cornerRadius = 25
            button.layer.cornerCurve = .continuous
            applyButtonFallbackShadow(button.layer)
            applyPressFeedback(button)
        }
    }

    static func stylePlainSymbolButton(
        _ button: UIButton,
        systemName: String,
        foregroundColor: UIColor = labelPrimary
    ) {
        button.configuration = nil
        button.setTitle(nil, for: .normal)
        button.setImage(
            symbolImage(systemName)?.withTintColor(foregroundColor, renderingMode: .alwaysOriginal),
            for: .normal
        )
        button.tintColor = foregroundColor
        button.backgroundColor = .clear
        button.clipsToBounds = true
        button.layer.shadowOpacity = 0
    }

    static func styleDestructiveButton(_ button: UIButton, title: String, systemImage: String) {
        prepareForGlass(button)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.title = title
        config.baseForegroundColor = AppColor.accentRed
        config.baseBackgroundColor = AppColor.fillVibrantTertiary
        config.background.backgroundColor = AppColor.fillVibrantTertiary
        config.image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        )
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.titleTextAttributesTransformer = titleTransformer(size: 17, weight: .regular)
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        button.configuration = config
        button.tintColor = AppColor.accentRed
        button.layer.shadowOpacity = 0
        button.controlHaptic = .medium
        applyPressFeedback(button)
    }

    static func styleSecondaryButton(_ button: UIButton, title: String) {
        button.configuration = nil
        button.setTitle(title, for: .normal)
        button.setTitleColor(AppColor.iconSecondary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        button.backgroundColor = .clear
        button.controlHaptic = .light
        applyPressFeedback(button)
    }

    static func styleTertiaryButton(_ button: UIButton, title: String) {
        prepareForGlass(button)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.buttonSize = .large
        config.title = title
        config.baseForegroundColor = AppColor.tabSelected
        config.baseBackgroundColor = AppColor.fillSecondary
        config.titleTextAttributesTransformer = titleTransformer(size: 17, weight: .semibold)
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        button.configuration = config
        button.backgroundColor = .clear
        button.layer.shadowOpacity = 0
        applyPressFeedback(button)
    }

    static func styleBorderlessButton(_ button: UIButton, title: String) {
        button.configuration = nil
        button.setTitle(title, for: .normal)
        button.setTitleColor(AppColor.tabSelected, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        button.backgroundColor = .clear
        applyPressFeedback(button)
    }

    static func styleTitle(_ titleLabel: UILabel) {
        lockFigmaFont(titleLabel, size: 34, weight: .bold, color: labelPrimary, kern: 0.4)
    }

    static func styleHeading(_ titleLabel: UILabel, _ subtitleLabel: UILabel?) {
        styleTitle(titleLabel)
        guard let subtitleLabel else { return }
        lockFigmaFont(subtitleLabel, size: 15, weight: .medium, color: AppColor.iconSecondary, kern: -0.25)
    }

    static func lockFigmaFont(
        _ label: UILabel?,
        size: CGFloat,
        weight: UIFont.Weight,
        color: UIColor? = nil,
        kern: CGFloat? = nil
    ) {
        guard let label else { return }
        (label as? AdaptiveLabel)?.adaptFontSize = false
        if let color {
            label.textColor = color
        }
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        let text = label.text ?? ""
        let alignment = label.textAlignment
        if let kern, !text.isEmpty {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            paragraph.lineBreakMode = label.lineBreakMode
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .kern: kern,
                .paragraphStyle: paragraph
            ]
            if let color {
                attributes[.foregroundColor] = color
            } else if let textColor = label.textColor {
                attributes[.foregroundColor] = textColor
            }
            let attributed = NSMutableAttributedString(string: text, attributes: attributes)
            label.attributedText = attributed
            label.textAlignment = alignment
        } else {
            label.font = font
            label.textAlignment = alignment
        }
    }

    static func pickerRowLabel(reusing view: UIView?, text: String) -> UILabel {
        let label = (view as? UILabel) ?? UILabel()
        label.textAlignment = .center
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .regular),
                .foregroundColor: AppColor.textPrimary,
                .kern: -0.45
            ]
        )
        return label
    }

    static func styleBackButton(_ button: UIButton) {
        button.controlHaptic = .none
        prepareForGlass(button)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        let image = UIImage(systemName: "chevron.backward", withConfiguration: symbolConfig)
        if #available(iOS 26.0, *) {
            var config = buttonGlassConfiguration()
            config.image = image
            config.baseForegroundColor = labelPrimary
            button.configuration = config
        } else {
            button.configuration = nil
            button.setTitle(nil, for: .normal)
            button.setImage(image?.withTintColor(labelPrimary, renderingMode: .alwaysOriginal), for: .normal)
            button.backgroundColor = glassFallbackFill
            button.layer.cornerRadius = 22
            button.layer.cornerCurve = .continuous
            applyButtonFallbackShadow(button.layer)
            applyPressFeedback(button)
        }
    }

    static func stylePageControl(_ pageControl: UIPageControl, pages: Int, current: Int) {
        pageControl.numberOfPages = pages
        pageControl.currentPage = current
        pageControl.currentPageIndicatorTintColor = accentTeal
        pageControl.pageIndicatorTintColor = accentTeal.withAlphaComponent(0.3)
        pageControl.isUserInteractionEnabled = false
        pageControl.hidesForSinglePage = false
        pageControl.allowsContinuousInteraction = false
    }

    static func styleWheelPicker(_ picker: UIPickerView) {
        picker.backgroundColor = .clear
        picker.clipsToBounds = true
        picker.superview?.clipsToBounds = true
        picker.subviews.forEach { subview in
            subview.backgroundColor = .clear
        }
    }

    static func symbol(_ names: String..., pointSize: CGFloat, weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        let aliases: [String: [String]] = [
            "gauge.with.dots.needle.67percent": ["gauge", "speedometer"],
            "photo.on.rectangle.angled": ["photo.on.rectangle", "photo"],
            "folder.badge.plus": ["folder"],
            "figure.seated.side.right": ["figure.seated.side"],
            "figure.run.treadmill": ["figure.run"],
            "chart.line.text.clipboard": ["list.clipboard", "clipboard"],
            "arrow.trianglehead.2.clockwise.rotate.90": ["arrow.triangle.2.circlepath"],
            "arrow.triangle.2.circlepath.circle": ["arrow.clockwise.circle"],
            "figure.yoga": ["figure.flexibility", "figure.cooldown"],
            "figure.basketball": ["sportscourt", "figure.run"]
        ]
        var resolved: [String] = []
        for name in names {
            resolved.append(name)
            resolved.append(contentsOf: aliases[name] ?? [])
        }
        for name in resolved {
            if let image = UIImage(systemName: name, withConfiguration: config) {
                return image
            }
        }
        return nil
    }

    static func applyCardFallbackShadow(
        _ layer: CALayer,
        traits: UITraitCollection? = nil,
        radius: CGFloat = 16
    ) {
        let style = (traits ?? .current).userInterfaceStyle
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = style == .dark ? 115 / 255 : 26 / 255
        layer.shadowRadius = radius
        layer.shadowOffset = CGSize(width: 3, height: 4)
    }

    static func applyButtonFallbackShadow(_ layer: CALayer) {
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 40
        layer.shadowOffset = CGSize(width: 0, height: 8)
    }

    static func applyFallbackShadow(_ layer: CALayer) {
        applyCardFallbackShadow(layer)
    }

    private static func prepareForGlass(_ button: UIButton) {
        button.backgroundColor = .clear
        button.clipsToBounds = false
        button.layer.masksToBounds = false
        button.viewWithTag(glassBevelTag)?.removeFromSuperview()
    }

    @available(iOS 26.0, *)
    static func buttonGlassConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.glass()
        config.cornerStyle = .capsule
        config.background.shadowProperties.opacity = 0.12
        config.background.shadowProperties.radius = 40
        config.background.shadowProperties.offset = CGSize(width: 0, height: 8)
        return config
    }

    private static let glassBevelTag = 871421

    static func applyPressFeedback(_ button: UIButton) {
        button.addAction(UIAction { [weak button] _ in
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
            ) {
                button?.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            }
        }, for: .touchDown)
        let release = UIAction { [weak button] _ in
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]
            ) {
                button?.transform = .identity
            }
        }
        button.addAction(release, for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    private static func titleTransformer(size: CGFloat, weight: UIFont.Weight) -> UIConfigurationTextAttributesTransformer {
        UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: size, weight: weight)
            return outgoing
        }
    }
}
