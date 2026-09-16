import UIKit

final class OnboardingPagerViewController: UIViewController {
    private let pageController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal
    )
    private var pages: [UIViewController] = []
    private var currentIndex = 0

    var onFinished: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.backgroundsPrimary
        addChild(pageController)
        pageController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageController.view)
        NSLayoutConstraint.activate([
            pageController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        pageController.didMove(toParent: self)
        view.clipsToBounds = false
        pageController.view.clipsToBounds = false
        applyCurrentPage(animated: false, direction: .forward)
        disablePagingScroll()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        disablePagingScroll()
    }

    func setPages(_ pages: [UIViewController]) {
        self.pages = pages
        currentIndex = 0
        if isViewLoaded {
            applyCurrentPage(animated: false, direction: .forward)
        }
    }

    func goForward(animated: Bool = true) {
        let next = currentIndex + 1
        guard next < pages.count else {
            onFinished?()
            return
        }
        currentIndex = next
        applyCurrentPage(animated: animated, direction: .forward)
    }

    func goBack(steps: Int = 1) {
        let previous = currentIndex - steps
        guard previous >= 0 else { return }
        currentIndex = previous
        applyCurrentPage(animated: true, direction: .reverse)
    }

    private func applyCurrentPage(
        animated: Bool,
        direction: UIPageViewController.NavigationDirection
    ) {
        guard pages.indices.contains(currentIndex) else { return }
        pages[currentIndex].view.clipsToBounds = false
        pageController.setViewControllers(
            [pages[currentIndex]],
            direction: direction,
            animated: animated
        )
        disablePagingScroll()
    }

    private func disablePagingScroll() {
        pageController.view.subviews
            .compactMap { $0 as? UIScrollView }
            .forEach { $0.isScrollEnabled = false }
    }
}
