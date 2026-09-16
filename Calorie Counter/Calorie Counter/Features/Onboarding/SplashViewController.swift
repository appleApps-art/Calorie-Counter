import Lottie
import UIKit

final class SplashViewController: BaseViewController {
    @IBOutlet private weak var animationView: LottieAnimationView!

    var onFinished: (() -> Void)?
    private var didFinish = false
    private var loadedAnimationName: String?

    private static let holdFrame: AnimationFrameTime = 137
    private static let fallbackDuration: TimeInterval = 1.6

    init() {
        super.init(nibName: "SplashViewController")
    }

    override var analyticsScreen: AnalyticsScreen? { .splash }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        #if DEBUG
        if QALaunchConfiguration.skipSplash {
            view.backgroundColor = AppColor.canvas
            return
        }
        #endif
        view.backgroundColor = AppColor.canvas
        animationView.backgroundColor = .clear
        animationView.isOpaque = false
        animationView.contentMode = .scaleAspectFill
        animationView.loopMode = .playOnce
        animationView.backgroundBehavior = .pauseAndRestore
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: SplashViewController, _) in
            controller.applySplashAnimation(playIfNeeded: true)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        #if DEBUG
        if QALaunchConfiguration.skipSplash {
            setNeedsStatusBarAppearanceUpdate()
            return
        }
        #endif
        applySplashAnimation(playIfNeeded: false)
        setNeedsStatusBarAppearanceUpdate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if DEBUG
        if QALaunchConfiguration.skipSplash {
            finish()
            return
        }
        #endif
        applySplashAnimation(playIfNeeded: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.fallbackDuration) { [weak self] in
            self?.finish()
        }
    }

    private var splashAnimationName: String {
        let style = view.window?.traitCollection.userInterfaceStyle ?? traitCollection.userInterfaceStyle
        return style == .dark ? "SplashAnimationBlack" : "SplashAnimationWhite"
    }

    private func applySplashAnimation(playIfNeeded: Bool) {
        let name = splashAnimationName
        if loadedAnimationName != name {
            loadedAnimationName = name
            animationView.animation = LottieAnimation.named(name)
            playUntilHold()
            return
        }
        guard playIfNeeded, animationView.isAnimationPlaying == false else { return }
        playUntilHold()
    }

    private func playUntilHold() {
        animationView.play(fromFrame: 0, toFrame: Self.holdFrame, loopMode: .playOnce) { [weak self] finished in
            guard let self, finished else { return }
            self.animationView.currentFrame = Self.holdFrame
            self.finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinished?()
    }
}
