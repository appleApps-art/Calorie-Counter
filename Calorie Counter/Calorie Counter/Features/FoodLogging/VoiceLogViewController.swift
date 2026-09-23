import UIKit

final class VoiceLogViewController: BaseViewController, UITextViewDelegate {
    @IBOutlet private weak var backgroundImageView: UIImageView!
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet private weak var titleLabel: AdaptiveLabel!
    @IBOutlet private weak var waveformView: VoiceWaveformView!
    @IBOutlet private weak var inputCard: AdaptiveView!
    @IBOutlet private weak var statusLabel: AdaptiveLabel!
    @IBOutlet private weak var transcriptView: UITextView!
    @IBOutlet private weak var placeholderLabel: AdaptiveLabel!
    @IBOutlet private weak var cursorView: UIView!
    @IBOutlet private weak var clearButton: UIButton!
    @IBOutlet private weak var micButton: UIButton!
    @IBOutlet private weak var analyzeButton: UIButton!
    @IBOutlet private weak var dimView: UIView!
    @IBOutlet private weak var resultSheet: AdaptiveView!
    @IBOutlet private weak var resultCloseButton: UIButton!
    @IBOutlet private weak var resultTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var productCard: AdaptiveView!
    @IBOutlet private weak var productImageView: UIImageView!
    @IBOutlet private weak var productNameLabel: AdaptiveLabel!
    @IBOutlet private weak var productSubtitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreCard: AdaptiveView!
    @IBOutlet private weak var scoreCircleView: AdaptiveView!
    @IBOutlet private weak var scoreGradeLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var scoreSummaryLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var caloriesValueLabel: AdaptiveLabel!
    @IBOutlet private weak var proteinTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var proteinValueLabel: AdaptiveLabel!
    @IBOutlet private weak var carbsTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var carbsValueLabel: AdaptiveLabel!
    @IBOutlet private weak var fatTitleLabel: AdaptiveLabel!
    @IBOutlet private weak var fatValueLabel: AdaptiveLabel!
    @IBOutlet private var microCards: [AdaptiveView]!
    @IBOutlet private weak var detailsLabel: AdaptiveLabel!
    @IBOutlet private weak var addButton: UIButton!
    @IBOutlet private weak var detailsButton: UIButton!

    private let viewModel: VoiceFoodLoggingViewModel
    private let loadingOverlay = CustomLoadingOverlayView()
    private let micChrome = VoiceMicButtonChrome()
    private let resultSheetTint = UIView()
    private var resultSwipeDismissal: ResultPanelSwipeDismissal?
    private let productImageLoader = UIActivityIndicatorView(style: .medium)
    private var meterLink: CADisplayLink?
    private var cursorTimer: Timer?
    private var isApplyingTranscript = false
    private var lastVoicePhase: VoiceLogPhase?

    init(viewModel: VoiceFoodLoggingViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "VoiceLogViewController")
        hidesBottomBarWhenPushed = true
    }

    override var analyticsScreen: AnalyticsScreen? { .voiceLog }
    override var hidesFloatingTabBar: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.teal
        // voiceBackground is the teal field with the fruit outlines from the design, the same in both themes.
        backgroundImageView.image = UIImage(named: "voiceBackground")
        navigationItem.largeTitleDisplayMode = .never
        configureChrome()
        configureResultSheet()
        loadingOverlay.attach(to: view)
        applyPhase(viewModel.phase.value, animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        micChrome.layoutIfNeeded()
        RecognitionResultPanel.layout(tint: resultSheetTint, in: resultSheet)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            stopMeters()
            stopCursorBlink()
        }
    }

    override func bindViewModel() {
        viewModel.phase.bind { [weak self] phase in
            self?.applyPhase(phase, animated: true)
        }
        viewModel.statusText.bind { [weak self] value in
            self?.statusLabel.text = value
            OnboardingStyle.lockFigmaFont(
                self?.statusLabel,
                size: 17,
                weight: .regular,
                color: AppColor.iconSecondary,
                kern: -0.43
            )
        }
        viewModel.transcriptText.bind { [weak self] value in
            self?.applyTranscript(value)
        }
        viewModel.canAnalyze.bind { [weak self] canAnalyze in
            guard let self else { return }
            self.analyzeButton.isEnabled = canAnalyze
            self.applyPhase(self.viewModel.phase.value, animated: false)
        }
        viewModel.isAnalyzing.bind { [weak self] analyzing in
            self?.loadingOverlay.setVisible(analyzing)
        }
        viewModel.analysis.bind { [weak self] _ in
            self?.renderResult()
        }
        viewModel.resultImage.bind { [weak self] image in
            self?.productImageView.image = image
            self?.refreshProductImageLoader()
        }
        viewModel.isResultImageLoading.bind { [weak self] _ in
            self?.refreshProductImageLoader()
        }
        viewModel.showsFullDetails.bind { [weak self] visible in
            self?.detailsLabel.isHidden = !visible
        }
        viewModel.isRecording.bind { [weak self] recording in
            if recording {
                self?.startMeters()
            } else {
                self?.stopMeters()
            }
        }
        viewModel.isTranscribing.bind { [weak self] _ in
            guard let self else { return }
            self.applyPhase(self.viewModel.phase.value, animated: false)
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isApplyingTranscript else { return }
        viewModel.updateTranscript(textView.text ?? "")
        refreshPlaceholder()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }

    @objc
    private func backTapped() {
        viewModel.closeTapped()
    }

    @objc
    private func micTapped() {
        if viewModel.canAnalyze.value, viewModel.phase.value == .recorded {
            analyzeTapped()
            return
        }
        if viewModel.phase.value == .listening {
            viewModel.stopTapped()
        } else {
            viewModel.micTapped()
        }
    }

    @objc
    private func analyzeTapped() {
        transcriptView.resignFirstResponder()
        viewModel.analyzeTapped()
    }

    @objc
    private func clearTapped() {
        transcriptView.resignFirstResponder()
        viewModel.clearTapped()
    }

    @objc
    private func resultCloseTapped() {
        viewModel.dismissResultTapped()
    }

    @objc
    private func addTapped() {
        viewModel.confirmLogTapped()
    }

    @objc
    private func detailsTapped() {
        viewModel.viewDetailsTapped()
    }

    @objc
    private func tickMeters() {
        guard viewModel.isRecording.value else { return }
        waveformView.showListening(
            level: viewModel.normalizedPower(),
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        )
    }

    private func configureChrome() {
        titleLabel.text = L10n.tr("voice.title")
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

        inputCard.useLiveGlass = false
        inputCard.showsHairlineBorder = true
        inputCard.backgroundColor = AppColor.card
        statusLabel.text = L10n.tr("voice.tapAndSpeak")
        OnboardingStyle.lockFigmaFont(
            statusLabel,
            size: 17,
            weight: .regular,
            color: AppColor.iconSecondary,
            kern: -0.43
        )

        transcriptView.delegate = self
        transcriptView.backgroundColor = .clear
        transcriptView.textContainerInset = .zero
        transcriptView.textContainer.lineFragmentPadding = 0
        transcriptView.font = .systemFont(ofSize: 17, weight: .medium)
        transcriptView.textColor = AppColor.labelsPrimary
        transcriptView.tintColor = AppColor.teal
        transcriptView.returnKeyType = .done
        transcriptView.isScrollEnabled = true
        transcriptView.keyboardDismissMode = .interactive

        placeholderLabel.text = L10n.tr("voice.placeholderExample")
        placeholderLabel.numberOfLines = 0
        OnboardingStyle.lockFigmaFont(
            placeholderLabel,
            size: 17,
            weight: .medium,
            color: AppColor.iconSecondary,
            kern: -0.43
        )

        cursorView.backgroundColor = AppColor.teal
        cursorView.layer.cornerRadius = 1
        cursorView.isHidden = true

        OnboardingStyle.stylePlainSymbolButton(
            clearButton,
            systemName: "xmark.circle.fill",
            foregroundColor: AppColor.iconSecondary
        )
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)

        OnboardingStyle.styleGlassSymbolButton(
            micButton,
            systemName: "microphone.fill",
            foregroundColor: AppColor.labelVibrantPrimary
        )
        micChrome.attach(micButton)
        micButton.addTarget(self, action: #selector(micTapped), for: .touchUpInside)
        micButton.controlHaptic = .medium

        OnboardingStyle.styleGlassButton(
            analyzeButton,
            title: L10n.tr("voice.analyze"),
            foregroundColor: AppColor.labelVibrantPrimary,
            weight: .medium
        )
        analyzeButton.addTarget(self, action: #selector(analyzeTapped), for: .touchUpInside)
        waveformView.showIdle()
    }

    private func configureResultSheet() {
        RecognitionResultPanel.style(sheet: resultSheet, tint: resultSheetTint, cards: [productCard, scoreCard] + microCards)
        scoreCircleView.useLiveGlass = false
        scoreCircleView.backgroundColor = AppColor.accentMint
        productImageView.contentMode = .scaleAspectFill
        productImageView.clipsToBounds = true
        productImageView.layer.cornerRadius = .adaptWidth(12)
        productImageView.layer.cornerCurve = .continuous
        productImageView.backgroundColor = AppColor.fillSecondary

        resultTitleLabel.text = L10n.tr("photo.result.title")
        resultTitleLabel.textAlignment = .center
        OnboardingStyle.lockFigmaFont(
            resultTitleLabel,
            size: 17,
            weight: .semibold,
            color: AppColor.labelVibrantPrimary,
            kern: -0.43
        )
        OnboardingStyle.styleGlassSymbolButton(
            resultCloseButton,
            systemName: "xmark",
            foregroundColor: AppColor.iconSecondary
        )
        resultCloseButton.addTarget(self, action: #selector(resultCloseTapped), for: .touchUpInside)

        caloriesTitleLabel.text = L10n.tr("photo.result.calories")
        proteinTitleLabel.text = L10n.tr("home.protein")
        carbsTitleLabel.text = L10n.tr("home.carbs")
        fatTitleLabel.text = L10n.tr("photo.result.fat")
        [
            caloriesTitleLabel,
            proteinTitleLabel,
            carbsTitleLabel,
            fatTitleLabel
        ].forEach { label in
            OnboardingStyle.lockFigmaFont(
                label,
                size: 13,
                weight: .regular,
                color: AppColor.iconSecondary,
                kern: -0.08
            )
        }

        OnboardingStyle.stylePrimaryButton(
            addButton,
            title: L10n.tr("photo.result.addToDiary"),
            systemImage: "square.and.arrow.up"
        )
        addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        OnboardingStyle.styleGlassButton(
            detailsButton,
            title: L10n.tr("photo.result.viewDetails"),
            foregroundColor: AppColor.labelVibrantPrimary,
            weight: .medium
        )
        detailsButton.addTarget(self, action: #selector(detailsTapped), for: .touchUpInside)

        detailsLabel.numberOfLines = 0
        detailsLabel.isHidden = true
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        dimView.alpha = 0
        dimView.isHidden = true
        resultSheet.alpha = 0
        resultSheet.isHidden = true
        resultSheet.transform = CGAffineTransform(translationX: 0, y: 48)
        pinResultScrollContent()
        installResultSwipeDismissal()
    }

    private func refreshProductImageLoader() {
        RecognitionResultPanel.setImageLoading(
            viewModel.isResultImageLoading.value,
            spinner: productImageLoader,
            in: productImageView
        )
    }

    private func pinResultScrollContent() {
        guard let stack = productCard.superview, let scroll = stack.superview as? UIScrollView else { return }
        scroll.pinFilledContent(stack, hugHeight: true)
    }

    private func installResultSwipeDismissal() {
        let scroll = productCard.superview?.superview as? UIScrollView
        resultSwipeDismissal = ResultPanelSwipeDismissal(panel: resultSheet, scrollView: scroll) { [weak self] in
            self?.viewModel.dismissResultTapped()
        }
    }

    private func applyPhase(_ phase: VoiceLogPhase, animated: Bool) {
        let becameResult = phase == .result && lastVoicePhase != nil && lastVoicePhase != .result
        lastVoicePhase = phase
        let listening = phase == .listening
        let recorded = phase == .recorded || phase == .result
        let empty = (transcriptView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        transcriptView.isEditable = recorded && phase != .result
        clearButton.isHidden = empty && phase == .idle
        let showsConfirm = phase == .recorded && viewModel.canAnalyze.value
        micButton.isHidden = (recorded && !showsConfirm) || viewModel.isTranscribing.value
        analyzeButton.isHidden = !recorded
        micButton.isEnabled = phase == .idle || (phase == .listening && viewModel.isRecording.value) || showsConfirm
        if showsConfirm {
            micChrome.apply(isRecording: false, canConfirm: true)
            stopMeters()
            stopCursorBlink()
            waveformView.showRecorded()
        } else if listening {
            OnboardingStyle.styleGlassSymbolButton(
                micButton,
                systemName: "stop.fill",
                foregroundColor: AppColor.labelVibrantPrimary
            )
            if viewModel.isRecording.value {
                startMeters()
            } else {
                stopMeters()
                waveformView.showListening(level: 0.72, reduceMotion: true)
            }
            startCursorBlink()
        } else {
            OnboardingStyle.styleGlassSymbolButton(
                micButton,
                systemName: "microphone.fill",
                foregroundColor: AppColor.labelVibrantPrimary
            )
            stopMeters()
            stopCursorBlink()
            if recorded {
                waveformView.showRecorded()
            } else {
                waveformView.showIdle()
            }
        }
        refreshPlaceholder()
        setResultVisible(phase == .result, animated: animated)
        if phase == .result {
            transcriptView.resignFirstResponder()
            renderResult()
            resultSheet.layoutIfNeeded()
            if becameResult {
                Haptics.success()
            }
        }
    }

    private func applyTranscript(_ value: String) {
        isApplyingTranscript = true
        if transcriptView.text != value {
            transcriptView.text = value
        }
        isApplyingTranscript = false
        refreshPlaceholder()
    }

    private func refreshPlaceholder() {
        let empty = (transcriptView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let idle = viewModel.phase.value == .idle
        let listening = viewModel.phase.value == .listening
        placeholderLabel.isHidden = !empty || listening
        if idle, empty {
            placeholderLabel.text = L10n.tr("voice.placeholderExample")
        }
        cursorView.isHidden = !(listening && empty)
        clearButton.isHidden = empty && idle
    }

    private func startMeters() {
        guard meterLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tickMeters))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 45)
        link.add(to: .main, forMode: .common)
        meterLink = link
    }

    private func stopMeters() {
        meterLink?.invalidate()
        meterLink = nil
    }

    private func startCursorBlink() {
        stopCursorBlink()
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { [weak self] _ in
            guard let self else { return }
            let empty = (self.transcriptView.text ?? "").isEmpty
            guard empty else {
                self.cursorView.isHidden = true
                return
            }
            self.cursorView.isHidden.toggle()
        }
        cursorView.isHidden = false
    }

    private func stopCursorBlink() {
        cursorTimer?.invalidate()
        cursorTimer = nil
        cursorView.isHidden = true
    }

    private func setResultVisible(_ visible: Bool, animated: Bool) {
        dimView.isHidden = false
        resultSheet.isHidden = false
        let updates = {
            self.dimView.alpha = visible ? 1 : 0
            self.resultSheet.alpha = visible ? 1 : 0
            self.resultSheet.transform = visible ? .identity : CGAffineTransform(translationX: 0, y: 48)
        }
        let finish = {
            if !visible {
                self.dimView.isHidden = true
                self.resultSheet.isHidden = true
            }
        }
        if animated {
            UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: updates) { _ in
                finish()
            }
        } else {
            updates()
            finish()
        }
    }

    private func renderResult() {
        guard let result = viewModel.analysis.value else { return }
        productNameLabel.text = result.name
        OnboardingStyle.lockFigmaFont(
            productNameLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        productSubtitleLabel.text = viewModel.productSubtitleText
        OnboardingStyle.lockFigmaFont(
            productSubtitleLabel,
            size: 15,
            weight: .regular,
            color: AppColor.iconSecondary,
            kern: -0.23
        )
        let facts = result.nutritionFacts
        scoreGradeLabel.text = facts.grade.rawValue
        OnboardingStyle.lockFigmaFont(scoreGradeLabel, size: 17, weight: .semibold, color: .white)
        scoreTitleLabel.text = viewModel.healthScoreTitleText
        OnboardingStyle.lockFigmaFont(
            scoreTitleLabel,
            size: 17,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.43
        )
        scoreSummaryLabel.text = facts.summary
        OnboardingStyle.lockFigmaFont(
            scoreSummaryLabel,
            size: 13,
            weight: .regular,
            color: AppColor.iconSecondary,
            kern: -0.08
        )
        caloriesValueLabel.text = viewModel.caloriesValueText
        proteinValueLabel.text = viewModel.proteinValueText
        carbsValueLabel.text = viewModel.carbsValueText
        fatValueLabel.text = viewModel.fatValueText
        [
            caloriesValueLabel,
            proteinValueLabel,
            carbsValueLabel,
            fatValueLabel
        ].forEach { label in
            OnboardingStyle.lockFigmaFont(
                label,
                size: 17,
                weight: .regular,
                color: AppColor.labelsPrimary,
                kern: -0.43
            )
        }
        detailsLabel.text = viewModel.fullDetailsText
        OnboardingStyle.lockFigmaFont(
            detailsLabel,
            size: 15,
            weight: .regular,
            color: AppColor.labelsPrimary,
            kern: -0.23
        )
        productNameLabel.applyWrapping()
        productSubtitleLabel.applyWrapping()
        scoreTitleLabel.applyWrapping()
        scoreSummaryLabel.applyWrapping()
        [
            caloriesValueLabel,
            proteinValueLabel,
            carbsValueLabel,
            fatValueLabel
        ].forEach { $0.applyLineTruncation(lines: 1) }
    }
}
