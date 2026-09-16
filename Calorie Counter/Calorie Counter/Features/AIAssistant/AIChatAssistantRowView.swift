import UIKit

final class AIChatAssistantRowView: UIView {
    @IBOutlet private weak var avatarView: UIImageView!
    @IBOutlet private weak var contentContainer: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func embed(_ content: UIView) {
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        content.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            content.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            content.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        applyAvatar()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyAvatar()
    }

    private func applyAvatar() {
        avatarView.image = UIImage(named: "BityAIAssistant")?.withRenderingMode(.alwaysOriginal)
        avatarView.backgroundColor = .clear
        avatarView.contentMode = .scaleAspectFit
        avatarView.clipsToBounds = false
        avatarView.layer.masksToBounds = false
        avatarView.layer.cornerRadius = 0
        avatarView.isHidden = false
        avatarView.alpha = 1
        avatarView.setContentHuggingPriority(.required, for: .horizontal)
        avatarView.setContentCompressionResistancePriority(.required, for: .horizontal)
        avatarView.setContentHuggingPriority(.required, for: .vertical)
        avatarView.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func commonInit() {
        backgroundColor = .clear
        embedNibContent()
        applyAvatar()
    }
}
