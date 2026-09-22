import UIKit

final class FoodSearchResultRowView: UIView {
    @IBOutlet private weak var photoView: AdaptiveView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var detailLabel: AdaptiveLabel!
    @IBOutlet private weak var chevronButton: UIButton!
    @IBOutlet private weak var separatorView: UIView!

    private(set) var itemID: UUID?
    private(set) var isSkeleton = false
    var onSelect: ((UUID) -> Void)?

    private let photoLoadingIndicator = UIActivityIndicatorView(style: .medium)

    private let photoShimmer = ShimmerView()
    private let titleShimmer = ShimmerView()
    private let detailShimmer = ShimmerView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func configure(_ item: FoodSearchItem, showsSeparator: Bool, imageLoader: RemoteImageLoader = .shared) {
        isSkeleton = false
        isUserInteractionEnabled = true
        stopShimmers()
        itemID = item.id
        chevronButton.isHidden = false
        titleLabel.isHidden = false
        detailLabel.isHidden = false
        titleLabel.text = item.title
        detailLabel.text = item.subtitle
        setShowsSeparator(showsSeparator)
        OnboardingStyle.lockFigmaFont(titleLabel, size: 17, weight: .semibold, color: AppColor.labelsPrimary, kern: -0.43)
        OnboardingStyle.lockFigmaFont(detailLabel, size: 15, weight: .regular, color: AppColor.labelsSecondary, kern: -0.23)
        applySingleLineTruncation(titleLabel)
        applySingleLineTruncation(detailLabel)
        photoView.backgroundColor = AppColor.fillVibrantTertiary
        photoView.clipsToBounds = true
        photoImageView.clipsToBounds = true
        photoImageView.isHidden = false
        photoImageView.layer.cornerCurve = .continuous
        photoImageView.layer.cornerRadius = .adaptWidth(10)
        photoView.bringSubviewToFront(photoImageView)
        photoView.bringSubviewToFront(photoLoadingIndicator)
        photoLoadingIndicator.startAnimating()
        imageLoader.display(
            item.imageURL,
            data: item.imageData,
            in: photoImageView,
            placeholder: nil,
            onCompletion: { [weak self] loaded in
                guard let self else { return }
                self.photoLoadingIndicator.stopAnimating()
                if !loaded {
                    self.photoImageView.contentMode = .scaleAspectFit
                    self.photoImageView.image = OnboardingStyle.symbol("photo", pointSize: 16)
                    self.photoImageView.tintColor = AppColor.labelsSecondary
                }
            }
        )
    }

    func showSkeleton(showsSeparator: Bool) {
        photoLoadingIndicator.stopAnimating()
        isSkeleton = true
        itemID = nil
        onSelect = nil
        isUserInteractionEnabled = false
        chevronButton.isHidden = true
        titleLabel.attributedText = nil
        detailLabel.attributedText = nil
        titleLabel.text = " "
        detailLabel.text = " "
        titleLabel.textColor = .clear
        detailLabel.textColor = .clear
        setShowsSeparator(showsSeparator)
        photoImageView.isHidden = true
        RemoteImageLoader.shared.display(nil, in: photoImageView, placeholder: nil)
        photoView.backgroundColor = AppColor.fillVibrantTertiary
        photoShimmer.apply(cornerRadius: .adaptWidth(10))
        titleShimmer.apply(cornerRadius: .adaptWidth(6))
        detailShimmer.apply(cornerRadius: .adaptWidth(6))
        photoView.bringSubviewToFront(photoShimmer)
        titleShimmer.superview?.bringSubviewToFront(titleShimmer)
        detailShimmer.superview?.bringSubviewToFront(detailShimmer)
        photoShimmer.start()
        titleShimmer.start()
        detailShimmer.start()
    }

    func setShowsSeparator(_ showsSeparator: Bool) {
        separatorView.isHidden = !showsSeparator
    }

    @objc
    private func rowTapped() {
        guard let itemID else { return }
        Haptics.light()
        onSelect?(itemID)
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        let tap = UITapGestureRecognizer(target: self, action: #selector(rowTapped))
        addGestureRecognizer(tap)
        OnboardingStyle.stylePlainSymbolButton(
            chevronButton,
            systemName: "chevron.forward",
            foregroundColor: AppColor.iconSecondary
        )
        chevronButton?.isUserInteractionEnabled = false
        separatorView?.backgroundColor = AppColor.hairline
        titleLabel?.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel?.setContentHuggingPriority(.defaultLow, for: .horizontal)
        installShimmers()
        photoLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        photoLoadingIndicator.hidesWhenStopped = true
        photoLoadingIndicator.color = AppColor.labelsSecondary
        photoLoadingIndicator.isUserInteractionEnabled = false
        photoView.addSubview(photoLoadingIndicator)
        NSLayoutConstraint.activate([
            photoLoadingIndicator.centerXAnchor.constraint(equalTo: photoView.centerXAnchor),
            photoLoadingIndicator.centerYAnchor.constraint(equalTo: photoView.centerYAnchor)
        ])
    }

    private func installShimmers() {
        [photoShimmer, titleShimmer, detailShimmer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isUserInteractionEnabled = false
        }
        photoView.addSubview(photoShimmer)
        titleLabel.superview?.addSubview(titleShimmer)
        detailLabel.superview?.addSubview(detailShimmer)
        NSLayoutConstraint.activate([
            photoShimmer.topAnchor.constraint(equalTo: photoView.topAnchor),
            photoShimmer.leadingAnchor.constraint(equalTo: photoView.leadingAnchor),
            photoShimmer.trailingAnchor.constraint(equalTo: photoView.trailingAnchor),
            photoShimmer.bottomAnchor.constraint(equalTo: photoView.bottomAnchor),
            titleShimmer.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            titleShimmer.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            titleShimmer.heightAnchor.constraint(equalToConstant: .adaptHeight(14)),
            titleShimmer.widthAnchor.constraint(equalTo: titleLabel.widthAnchor, multiplier: 0.72),
            detailShimmer.leadingAnchor.constraint(equalTo: detailLabel.leadingAnchor),
            detailShimmer.centerYAnchor.constraint(equalTo: detailLabel.centerYAnchor),
            detailShimmer.heightAnchor.constraint(equalToConstant: .adaptHeight(12)),
            detailShimmer.widthAnchor.constraint(equalTo: detailLabel.widthAnchor, multiplier: 0.48)
        ])
        stopShimmers()
    }

    private func stopShimmers() {
        photoShimmer.stop()
        titleShimmer.stop()
        detailShimmer.stop()
    }

    private func applySingleLineTruncation(_ label: UILabel?) {
        guard let label else { return }
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontSizeToFitWidth = false
        label.minimumScaleFactor = 1
        guard let attributed = label.attributedText, attributed.length > 0 else { return }
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        mutable.addAttribute(
            .paragraphStyle,
            value: paragraph,
            range: NSRange(location: 0, length: mutable.length)
        )
        label.attributedText = mutable
    }
}
