import Foundation

enum BarcodeCameraPhase: Equatable {
    case idle
    case identifying
    case recognized
}

final class BarcodeFoodLoggingViewModel {
    let statusText = Observable(L10n.tr("barcode.camera.hint"))
    let phase = Observable(BarcodeCameraPhase.idle)
    let isLoading = Observable(false)

    var onClose: (() -> Void)?
    var onSwitchMode: ((HomeQuickLogAction) -> Void)?
    var onProductReady: ((ProductDetailsDraft) -> Void)?
    /// Asked before each lookup: a free account that used its scan gets the paywall instead.
    var allowsLookup: () -> Bool = { true }
    var onLimitReached: (() -> Void)?

    private let lookupBarcodeProductUseCase: LookupBarcodeProductUseCase
    private let selectedMealType: MealType
    private let diaryDate: Date
    private var lookupTask: Task<Void, Never>?
    private var recognizedTask: Task<Void, Never>?
    private var lookupGeneration = 0

    init(
        lookupBarcodeProductUseCase: LookupBarcodeProductUseCase,
        mealType: MealType = .snacks,
        date: Date = Date()
    ) {
        self.lookupBarcodeProductUseCase = lookupBarcodeProductUseCase
        selectedMealType = mealType
        diaryDate = date
    }

    func closeTapped() {
        cancelLookups()
        onClose?()
    }

    func switchMode(_ action: HomeQuickLogAction) {
        cancelLookups()
        onSwitchMode?(action)
    }

    func resumeIdleIfNeeded() {
        guard phase.value == .recognized else { return }
        resetToIdle()
    }

    func captureFailed(_ error: Error) {
        fail(with: error.localizedDescription)
    }

    func showIdleMessage(_ message: String) {
        fail(with: message)
    }

    func lookup(barcode: String) {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let normalized = BarcodeNormalization.normalize(trimmed) else {
            fail(with: L10n.tr("barcode.error.invalid"))
            return
        }
        guard allowsLookup() else {
            resetToIdle()
            onLimitReached?()
            return
        }

        cancelLookups()
        lookupGeneration += 1
        let generation = lookupGeneration
        isLoading.value = true
        statusText.value = L10n.tr("barcode.camera.identifying")
        phase.value = .identifying

        lookupTask = Task { @MainActor in
            do {
                let product = try await lookupBarcodeProductUseCase.execute(barcode: normalized)
                guard generation == lookupGeneration, !Task.isCancelled else { return }
                Analytics.tracker.track(.recognized("barcode"))
                let draft = await makeDraft(from: product)
                guard generation == lookupGeneration, !Task.isCancelled else { return }
                statusText.value = L10n.tr("barcode.camera.recognized")
                phase.value = .recognized
                isLoading.value = false
                scheduleProductPresentation(draft)
            } catch {
                guard generation == lookupGeneration, !Task.isCancelled else { return }
                Analytics.tracker.track(.foodLogFailed(method: "barcode"))
                Analytics.tracker.track(.recognitionFailed("barcode", error: error))
                fail(with: error.localizedDescription)
            }
        }
    }

    func beginCapture() {
        cancelLookups()
        isLoading.value = true
        statusText.value = L10n.tr("barcode.camera.identifying")
        phase.value = .identifying
    }

    private func scheduleProductPresentation(_ draft: ProductDetailsDraft) {
        recognizedTask?.cancel()
        recognizedTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled, phase.value == .recognized else { return }
            onProductReady?(draft)
        }
    }

    private func makeDraft(from product: BarcodeProduct) async -> ProductDetailsDraft {
        var imageData: Data?
        if let url = product.imageURL {
            imageData = try? await URLSession.shared.data(from: url).0
            if imageData?.isEmpty == true {
                imageData = nil
            }
        }
        return ProductDetailsMath.draft(
            from: product,
            imageData: imageData,
            mealType: selectedMealType,
            date: diaryDate
        )
    }

    private func fail(with message: String) {
        isLoading.value = false
        statusText.value = message
        phase.value = .idle
    }

    private func resetToIdle() {
        cancelLookups()
        isLoading.value = false
        statusText.value = L10n.tr("barcode.camera.hint")
        phase.value = .idle
    }

    private func cancelLookups() {
        lookupGeneration += 1
        lookupTask?.cancel()
        recognizedTask?.cancel()
        lookupTask = nil
        recognizedTask = nil
    }
}
