import UIKit

final class EditMealFoodRowView: UIView, UIGestureRecognizerDelegate {
    @IBOutlet private weak var photoView: UIView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var photoLoadingIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var detailLabel: AdaptiveLabel!
    @IBOutlet private weak var deleteButton: UIButton!

    private(set) var itemID: UUID?
    var onDelete: ((UUID) -> Void)?
    var onSelect: ((UUID) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ item: EditMealItem) {
        itemID = item.id
        titleLabel.text = item.name
        detailLabel.text = item.detailText
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .regular, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(detailLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        titleLabel.applyLineTruncation(lines: 1)
        detailLabel.applyLineTruncation(lines: 1)
        stylePhoto()
        displayPhoto(item)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        photoView?.layer.cornerRadius = .adaptWidth(11)
    }

    @objc
    private func rowTapped() {
        guard let itemID else { return }
        Haptics.light()
        onSelect?(itemID)
    }

    @objc
    private func deleteTapped() {
        guard let itemID else { return }
        onDelete?(itemID)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let view = touch.view, let deleteButton else { return true }
        return !view.isDescendant(of: deleteButton)
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        OnboardingStyle.stylePlainSymbolButton(
            deleteButton,
            systemName: "trash",
            foregroundColor: AppColor.accentRed
        )
        deleteButton.setImage(UIImage(systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)), for: .normal)
        deleteButton?.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        deleteButton?.controlHaptic = .warning
        let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        addGestureRecognizer(tap)
        stylePhoto()
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func stylePhoto() {
        guard let photoView, let photoImageView else { return }
        photoView.backgroundColor = UIColor(red: 240 / 255, green: 239 / 255, blue: 239 / 255, alpha: 1)
        photoView.clipsToBounds = true
        photoView.layer.masksToBounds = true
        photoView.layer.cornerCurve = .continuous
        photoView.layer.cornerRadius = .adaptWidth(11)
        photoImageView.clipsToBounds = true
        photoImageView.contentMode = .scaleAspectFill
        photoView.bringSubviewToFront(photoImageView)
        if let photoLoadingIndicator {
            photoView.bringSubviewToFront(photoLoadingIndicator)
        }
    }

    private func displayPhoto(_ item: EditMealItem) {
        guard let photoImageView else { return }
        photoImageView.isHidden = true
        photoLoadingIndicator.startAnimating()
        RemoteImageLoader.shared.display(
            item.imageURL,
            data: item.imageData,
            in: photoImageView,
            placeholder: OnboardingStyle.symbol("fork.knife", pointSize: .adaptFont(16))?.withTintColor(
                AppColor.labelsSecondary,
                renderingMode: .alwaysOriginal
            ),
            fallbackURL: item.fallbackImageURL,
            onCompletion: { [weak self] _ in
                self?.photoLoadingIndicator.stopAnimating()
                self?.photoImageView.isHidden = false
            }
        )
    }
}
