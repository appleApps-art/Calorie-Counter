import UIKit

final class ProgressPhotosViewController: BaseViewController {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var sectionsStackView: UIStackView!
    @IBOutlet private weak var logNewButton: UIButton!

    var onBack: (() -> Void)?
    var onLogNew: (() -> Void)?
    var onAppear: (() -> Void)?

    private var photoPreview: ProgressPhotoPreviewView?

    private var sections: [ProgressPhotoDaySection]

    init(sections: [ProgressPhotoDaySection]) {
        self.sections = sections
        super.init(nibName: "ProgressPhotosViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .progressPhotos }

    func update(sections: [ProgressPhotoDaySection]) {
        self.sections = sections
        guard isViewLoaded else { return }
        render()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        backgroundImageView.image = UIImage(named: "appBackground")
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.isHidden = false
        view.sendSubviewToBack(backgroundImageView)
        titleLabel.text = L10n.tr("progress.photosTitle")
        titleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            titleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.styleGlassSymbolButton(
            backButton,
            systemName: "chevron.backward",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        OnboardingStyle.stylePrimaryButton(
            logNewButton,
            title: L10n.tr("progress.logNewPhoto"),
            systemImage: "plus"
        )
        logNewButton.addTarget(self, action: #selector(logNewTapped), for: .touchUpInside)
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        onAppear?()
    }

    private func render() {
        sectionsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        sections.forEach { section in
            let row = ProgressPhotoDateSectionView()
            row.configure(section)
            row.onPhotoTap = { [weak self] imageView, date in
                self?.showPhotoPreview(from: imageView, date: date)
            }
            sectionsStackView.addArrangedSubview(row)
        }
    }

    private func showPhotoPreview(from source: UIImageView, date: String) {
        guard photoPreview == nil, let image = source.image else { return }
        let preview = ProgressPhotoPreviewView(image: image, date: date, source: source)
        photoPreview = preview
        preview.onDismiss = { [weak self] in self?.photoPreview = nil }
        preview.frame = view.bounds
        preview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(preview)
        preview.show()
    }

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func logNewTapped() {
        onLogNew?()
    }
}


/// An in-place lightbox; it never pushes or presents another screen.
final class ProgressPhotoPreviewView: UIView {
    var onDismiss: (() -> Void)?
    private let backdrop = UIControl()
    private let photoView: UIImageView
    private let dateLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private weak var source: UIImageView?
    private var transitioning = false
    private var isClosing = false

    init(image: UIImage, date: String, source: UIImageView) {
        photoView = UIImageView(image: image)
        self.source = source
        super.init(frame: .zero)
        accessibilityViewIsModal = true
        backdrop.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        backdrop.addTarget(self, action: #selector(dismissPreview), for: .touchUpInside)
        addSubview(backdrop)
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.layer.cornerRadius = 16
        photoView.isUserInteractionEnabled = true
        photoView.isAccessibilityElement = true
        photoView.accessibilityLabel = source.accessibilityLabel
        addSubview(photoView)
        dateLabel.text = date
        dateLabel.font = .preferredFont(forTextStyle: .headline)
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textColor = .white
        dateLabel.textAlignment = .center
        dateLabel.numberOfLines = 0
        addSubview(dateLabel)
        OnboardingStyle.styleGlassSymbolButton(closeButton, systemName: "xmark", foregroundColor: .white)
        closeButton.accessibilityLabel = L10n.tr("common.close")
        closeButton.addTarget(self, action: #selector(dismissPreview), for: .touchUpInside)
        addSubview(closeButton)
        accessibilityElements = [closeButton, photoView, dateLabel]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        backdrop.frame = bounds
        closeButton.frame = CGRect(x: bounds.width - safeAreaInsets.right - 60, y: safeAreaInsets.top + 12, width: 44, height: 44)
        guard !transitioning else { return }
        layoutPhoto()
    }

    private func layoutPhoto() {
        let dateHeight = dateLabel.sizeThatFits(CGSize(width: max(1, bounds.width - 32), height: .greatestFiniteMagnitude)).height
        let top = safeAreaInsets.top + 72
        let width = max(1, bounds.width - safeAreaInsets.left - safeAreaInsets.right - 32)
        let height = max(1, bounds.height - top - safeAreaInsets.bottom - dateHeight - 44)
        let size = photoView.image?.size ?? CGSize(width: 1, height: 1)
        let scale = min(width / max(1, size.width), height / max(1, size.height))
        let photoSize = CGSize(width: size.width * scale, height: size.height * scale)
        photoView.frame = CGRect(x: (bounds.width - photoSize.width) / 2, y: top + (height - photoSize.height) / 2, width: photoSize.width, height: photoSize.height)
        dateLabel.frame = CGRect(x: 16, y: photoView.frame.maxY + 16, width: bounds.width - 32, height: dateHeight)
    }

    func show() {
        layoutIfNeeded()
        let target = photoView.frame
        photoView.frame = source.map { $0.convert($0.bounds, to: self) } ?? target
        source?.alpha = 0
        backdrop.alpha = 0
        dateLabel.alpha = 0
        closeButton.alpha = 0
        transitioning = true
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.32, delay: 0, options: [.curveEaseInOut]) {
            self.photoView.frame = target
            self.backdrop.alpha = 1
            self.dateLabel.alpha = 1
            self.closeButton.alpha = 1
        } completion: { _ in
            guard !self.isClosing else { return }
            self.transitioning = false
            self.setNeedsLayout()
            UIAccessibility.post(notification: .screenChanged, argument: self.closeButton)
        }
    }

    @objc func dismissPreview() {
        guard !isClosing else { return }
        isClosing = true
        transitioning = true
        let target = source.flatMap { $0.window != nil ? $0.convert($0.bounds, to: self) : nil }
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.25, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut]) {
            if let target { self.photoView.frame = target } else { self.photoView.alpha = 0 }
            self.backdrop.alpha = 0
            self.dateLabel.alpha = 0
            self.closeButton.alpha = 0
        } completion: { _ in
            self.source?.alpha = 1
            self.removeFromSuperview()
            self.onDismiss?()
            UIAccessibility.post(notification: .screenChanged, argument: self.source)
        }
    }

    override func accessibilityPerformEscape() -> Bool {
        dismissPreview()
        return true
    }
}
