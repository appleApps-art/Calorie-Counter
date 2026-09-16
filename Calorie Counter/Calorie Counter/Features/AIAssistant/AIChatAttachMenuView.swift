import UIKit

final class AIChatAttachMenuView: UIView {
    @IBOutlet private weak var menuView: AdaptiveView!
    @IBOutlet private weak var cameraButton: UIButton!
    @IBOutlet private weak var galleryButton: UIButton!
    @IBOutlet private weak var filesButton: UIButton!

    var onCamera: (() -> Void)?
    var onGallery: (() -> Void)?
    var onFiles: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    @objc
    private func cameraTapped() {
        onCamera?()
    }

    @objc
    private func galleryTapped() {
        onGallery?()
    }

    @objc
    private func filesTapped() {
        onFiles?()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        menuView?.applyButtonGlass = true
        menuView?.applyCardShadow = true
        menuView?.showsDropShadow = true
        menuView?.useLiveGlass = true
        applyRowChrome()
        cameraButton?.addTarget(self, action: #selector(cameraTapped), for: .touchUpInside)
        galleryButton?.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
        filesButton?.addTarget(self, action: #selector(filesTapped), for: .touchUpInside)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: AIChatAttachMenuView, _) in
            view.applyRowChrome()
        }
    }

    private func applyRowChrome() {
        styleRow(
            cameraButton,
            symbol: "camera",
            title: L10n.tr("ai.chat.attach.camera")
        )
        styleRow(
            galleryButton,
            symbol: "photo.on.rectangle.angled",
            title: L10n.tr("ai.chat.attach.gallery")
        )
        styleRow(
            filesButton,
            symbol: "folder.badge.plus",
            title: L10n.tr("ai.chat.attach.files")
        )
    }

    private func styleRow(_ button: UIButton?, symbol: String, title: String) {
        guard let button else { return }
        var config = UIButton.Configuration.plain()
        config.image = Self.leadingSymbol(symbol)
        config.imagePlacement = .leading
        config.imagePadding = .adaptWidth(8)
        config.contentInsets = NSDirectionalEdgeInsets(
            top: .adaptHeight(10),
            leading: .adaptWidth(6),
            bottom: .adaptHeight(10),
            trailing: .adaptWidth(8)
        )
        var attributes = AttributeContainer()
        attributes.font = UIFont.systemFont(ofSize: .adaptFont(17), weight: .regular)
        attributes.foregroundColor = AppColor.labelVibrantPrimary
        attributes.kern = -0.43
        config.attributedTitle = AttributedString(title, attributes: attributes)
        config.titleAlignment = .leading
        button.configuration = config
        button.contentHorizontalAlignment = .leading
        button.contentVerticalAlignment = .center
        button.backgroundColor = .clear
    }

    private static func leadingSymbol(_ name: String) -> UIImage? {
        let pointSize = CGFloat.adaptFont(17)
        let slotWidth = CGFloat.adaptWidth(28)
        guard let symbol = OnboardingStyle.symbol(name, pointSize: pointSize)?.withTintColor(
            AppColor.iconSecondary,
            renderingMode: .alwaysOriginal
        ) else {
            return nil
        }
        let drawSize = CGSize(
            width: min(symbol.size.width, slotWidth),
            height: symbol.size.height * min(1, slotWidth / max(symbol.size.width, 1))
        )
        let canvas = CGSize(width: slotWidth, height: max(drawSize.height, pointSize))
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
        return renderer.image { _ in
            let origin = CGPoint(
                x: ((canvas.width - drawSize.width) / 2).rounded(.toNearestOrAwayFromZero),
                y: ((canvas.height - drawSize.height) / 2).rounded(.toNearestOrAwayFromZero)
            )
            symbol.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
