import UIKit

class BaseViewController: UIViewController {
    private var lastAdaptiveBounds: CGSize = .zero

    init(nibName: String) {
        super.init(nibName: nibName, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let boundsSize = view.bounds.size
        guard boundsSize != lastAdaptiveBounds else { return }
        lastAdaptiveBounds = boundsSize
        view.refreshAdaptiveLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        view.refreshAdaptiveLayout()
    }

    func bindViewModel() {}
}
