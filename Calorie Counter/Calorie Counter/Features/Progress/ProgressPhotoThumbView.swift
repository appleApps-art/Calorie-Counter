import UIKit

final class ProgressPhotoThumbView: UIView {
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var dateLabel: AdaptiveLabel!
    @IBOutlet private weak var dateTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var dateHeightConstraint: NSLayoutConstraint!

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
    }

    func configure(image: UIImage?, dateText: String, showsDate: Bool = true) {
        imageView.image = image
        imageView.backgroundColor = AppColor.fillSecondary
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = .adaptWidth(16)
        imageView.layer.cornerCurve = .continuous
        dateLabel.isHidden = !showsDate
        dateLabel.text = showsDate ? dateText : nil
        dateTopConstraint.constant = showsDate ? .adaptHeight(8) : 0
        dateHeightConstraint.constant = showsDate ? .adaptHeight(13) : 0
        if showsDate {
            OnboardingStyle.lockFigmaFont(dateLabel, size: 11, weight: .regular, color: AppColor.labelsSecondary, kern: 0.06)
        }
    }
}
