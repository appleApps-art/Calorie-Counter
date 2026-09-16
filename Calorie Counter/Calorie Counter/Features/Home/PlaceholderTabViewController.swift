import UIKit

final class PlaceholderTabViewController: BaseViewController {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!

    private let placeholderTab: Tab

    init(tab: Tab) {
        self.placeholderTab = tab
        super.init(nibName: "PlaceholderTabViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundImageView.image = UIImage(named: "appBackground")
        backgroundImageView.contentMode = .scaleAspectFill
        title = placeholderTab.title
        titleLabel.isHidden = true
        navigationItem.title = placeholderTab.title
        navigationItem.largeTitleDisplayMode = .always
    }

    override var analyticsScreen: AnalyticsScreen? {
        placeholderTab == .recipes ? .recipes : nil
    }
}
