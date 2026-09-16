import UIKit

final class ProgressPhotoDateSectionView: UIView {
    @IBOutlet private weak var dateLabel: AdaptiveLabel!
    @IBOutlet private weak var frontImageView: UIImageView!
    @IBOutlet private weak var sideImageView: UIImageView!

    var onPhotoTap: ((UIImageView, String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        [frontImageView, sideImageView].forEach { imageView in
            imageView?.isUserInteractionEnabled = true
            imageView?.isAccessibilityElement = true
            imageView?.accessibilityTraits = [.image, .button]
            imageView?.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(photoTapped(_:))))
        }
    }

    func configure(_ section: ProgressPhotoDaySection) {
        dateLabel.text = section.dateText
        OnboardingStyle.lockFigmaFont(dateLabel, size: 15, weight: .semibold, color: AppColor.labelVibrantPrimary, kern: -0.23)
        apply(section.pair.front, to: frontImageView)
        apply(section.pair.side, to: sideImageView)
    }

    @objc private func photoTapped(_ gesture: UITapGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView, imageView.image != nil else { return }
        onPhotoTap?(imageView, dateLabel.text ?? "")
    }

    private func apply(_ photo: ProgressPhoto?, to imageView: UIImageView) {
        imageView.backgroundColor = AppColor.fillSecondary
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = .adaptWidth(16)
        imageView.layer.cornerCurve = .continuous
        if let url = photo?.fileURL, let image = UIImage(contentsOfFile: url.path) {
            imageView.accessibilityLabel = "\(photo?.pose.title ?? "") · \(dateLabel.text ?? "")"
            imageView.image = image
            imageView.isHidden = false
        } else {
            imageView.image = nil
            imageView.isHidden = true
        }
    }
}
