import Foundation

final class RecipesViewModel {
    let titleText = Observable(L10n.tr("recipes.title"))
    let queryText = Observable("")
    let selectedTab = Observable(RecipeHubTab.all)
    let browseSections = Observable<[RecipeBrowseSection]>([])
    let savedRecipes = Observable<[Recipe]>([])
    let mealPlans = Observable<[MealPlan]>([])
    let resultRecipes = Observable<[Recipe]>([])
    let suggestionTitles = Observable<[String]>([])
    let filterChips = Observable<[RecipeFilterChip]>([])
    let isLoading = Observable(false)
    let isRecording = Observable(false)
    let canConfirmQuery = Observable(false)
    let showsFilterResults = Observable(false)
    let showsEmptyResults = Observable(false)

    var onSelectRecipe: ((Recipe) -> Void)?
    var onSelectMealPlan: ((MealPlan) -> Void)?
    var onOpenSection: ((RecipeBrowseSectionKind, String) -> Void)?
    var onOpenPantry: (() -> Void)?
    var onOpenFilters: ((RecipeSearchFilters) -> Void)?
    var onOpenCreateSheet: (() -> Void)?
    var onCreateRecipe: (() -> Void)?
    var onCreateMealPlan: (() -> Void)?

    private let searchRecipesUseCase: SearchRecipesUseCase
    private let fetchBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase
    private let recipeRepository: RecipeRepositoryProtocol
    private let fetchMealPlansUseCase: FetchMealPlansUseCase
    private let voiceRecorder: VoiceFoodAudioRecording
    private let transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase
    private var filters = RecipeSearchFilters.empty
    private var searchTask: Task<Void, Never>?
    private var browseTask: Task<Void, Never>?
    private var receivedLiveVoice = false
    private var speechEndTask: Task<Void, Never>?

    init(
        searchRecipesUseCase: SearchRecipesUseCase,
        fetchBrowseSectionsUseCase: FetchRecipeBrowseSectionsUseCase,
        recipeRepository: RecipeRepositoryProtocol,
        fetchMealPlansUseCase: FetchMealPlansUseCase,
        voiceRecorder: VoiceFoodAudioRecording,
        transcribeFoodVoiceUseCase: TranscribeFoodVoiceUseCase
    ) {
        self.searchRecipesUseCase = searchRecipesUseCase
        self.fetchBrowseSectionsUseCase = fetchBrowseSectionsUseCase
        self.recipeRepository = recipeRepository
        self.fetchMealPlansUseCase = fetchMealPlansUseCase
        self.voiceRecorder = voiceRecorder
        self.transcribeFoodVoiceUseCase = transcribeFoodVoiceUseCase
    }

    func viewDidLoad() {
        reloadLocal()
        loadBrowse()
    }

    func reloadVisible() {
        reloadLocal()
        if showsFilterResults.value {
            searchTapped()
        } else if selectedTab.value == .all, browseLooksInvalid {
            loadBrowse()
        }
    }

    func selectTab(_ tab: RecipeHubTab) {
        selectedTab.value = tab
        if !showsFilterResults.value {
            suggestionTitles.value = []
        }
        reloadLocal()
    }

    func updateQuery(_ text: String) {
        queryText.value = text
        if canConfirmQuery.value, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            canConfirmQuery.value = false
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, !filters.hasActiveConstraints {
            showsFilterResults.value = false
            showsEmptyResults.value = false
            resultRecipes.value = []
            filterChips.value = []
            suggestionTitles.value = []
            return
        }
        suggestionTitles.value = []
        if filters.hasActiveConstraints {
            debounceSearch()
        }
    }

    func searchTapped() {
        cancelVoice()
        canConfirmQuery.value = false
        searchTask?.cancel()
        let query = queryText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty || filters.hasActiveConstraints else { return }
        showsFilterResults.value = true
        filterChips.value = filters.resultChips
        showsEmptyResults.value = false
        resultRecipes.value = []
        isLoading.value = true
        suggestionTitles.value = []
        searchTask = Task { @MainActor in
            let recipes = (try? await searchRecipesUseCase.execute(query: query, filters: filters)) ?? []
            guard !Task.isCancelled else { return }
            resultRecipes.value = recipes
            showsEmptyResults.value = recipes.isEmpty
            isLoading.value = false
            Analytics.tracker.track(.foodSearchPerformed(queryLength: query.count, resultCount: recipes.count))
        }
    }

    func applyFilters(_ filters: RecipeSearchFilters) {
        self.filters = filters
        filterChips.value = filters.resultChips
        showsFilterResults.value = filters.hasActiveConstraints || !queryText.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if showsFilterResults.value {
            searchTapped()
        } else {
            resultRecipes.value = []
            showsEmptyResults.value = false
        }
    }

    func removeFilterChip(_ chip: RecipeFilterChip) {
        filters.remove(chip: chip)
        applyFilters(filters)
    }

    func selectSuggestion(_ title: String) {
        queryText.value = title
        suggestionTitles.value = []
        searchTapped()
    }

    func selectRecipe(_ recipe: Recipe) {
        onSelectRecipe?(recipe)
    }

    func selectMealPlan(_ plan: MealPlan) {
        onSelectMealPlan?(plan)
    }

    func seeMoreTapped(_ kind: RecipeBrowseSectionKind) {
        onOpenSection?(kind, L10n.tr(kind.titleKey))
    }

    func pantryTapped() {
        onOpenPantry?()
    }

    func addTapped() {
        onOpenCreateSheet?()
    }

    func createRecipeTapped() {
        onCreateRecipe?()
    }

    func createMealPlanTapped() {
        onCreateMealPlan?()
    }

    func reloadAfterCreate() {
        savedRecipes.value = (try? recipeRepository.fetchSaved()) ?? []
    }

    func reloadAfterMealPlanCreate() {
        mealPlans.value = (try? fetchMealPlansUseCase.execute()) ?? []
        selectedTab.value = .mealPlans
    }

    func filtersTapped() {
        cancelVoice()
        onOpenFilters?(filters)
    }

    func trailingActionTapped() {
        if canConfirmQuery.value {
            confirmQueryTapped()
        } else {
            toggleVoiceTapped()
        }
    }

    func toggleVoiceTapped() {
        if isRecording.value {
            finishVoiceForConfirm()
        } else {
            startVoice()
        }
    }

    static func calorieBadgeText(for recipe: Recipe) -> String? {
        guard let calories = recipe.calories, calories > 0 else { return nil }
        return L10n.format("recipes.kcal", Int(calories.rounded()))
    }

    private var browseLooksInvalid: Bool {
        let sections = browseSections.value
        if sections.isEmpty { return true }
        return sections.contains { section in
            section.recipes.contains(where: \.looksLikeListingPage)
        }
    }

    private func reloadLocal() {
        savedRecipes.value = (try? recipeRepository.fetchSaved()) ?? []
        mealPlans.value = (try? fetchMealPlansUseCase.execute()) ?? []
    }

    private func debounceSearch() {
        searchTask?.cancel()
        let query = queryText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            suggestionTitles.value = []
            if filters.hasActiveConstraints {
                searchTapped()
            }
            return
        }
        searchTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            let recipes = (try? await searchRecipesUseCase.execute(query: query, filters: filters)) ?? []
            guard !Task.isCancelled else { return }
            suggestionTitles.value = Array(recipes.prefix(4).map(\.title))
            if filters.hasActiveConstraints {
                showsFilterResults.value = true
                filterChips.value = filters.resultChips
                resultRecipes.value = recipes
                showsEmptyResults.value = recipes.isEmpty
            }
        }
    }

    private func loadBrowse() {
        browseTask?.cancel()
        browseTask = Task { @MainActor in
            if let cached = fetchBrowseSectionsUseCase.peek(), !cached.isEmpty {
                browseSections.value = cached
                isLoading.value = false
            } else {
                isLoading.value = true
            }
            let sections = await fetchBrowseSectionsUseCase.execute(force: true)
            guard !Task.isCancelled else { return }
            if !sections.isEmpty {
                browseSections.value = sections
            }
            isLoading.value = false
        }
    }

    private func startVoice() {
        Task { @MainActor in
            let granted = await voiceRecorder.requestPermission()
            guard granted else { return }
            do {
                receivedLiveVoice = false
                canConfirmQuery.value = false
                voiceRecorder.onPartialTranscript = { [weak self] live in
                    let text = live.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let self, !text.isEmpty else { return }
                    self.receivedLiveVoice = true
                    self.queryText.value = text
                    self.scheduleSpeechEnd()
                }
                voiceRecorder.onUtteranceFinal = { [weak self] in
                    self?.finishVoiceForConfirm()
                }
                try voiceRecorder.startRecording()
                isRecording.value = true
            } catch {
                clearVoiceCallbacks()
            }
        }
    }

    private func scheduleSpeechEnd() {
        speechEndTask?.cancel()
        speechEndTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }
            self?.finishVoiceForConfirm()
        }
    }

    private func finishVoiceForConfirm() {
        guard isRecording.value else { return }
        speechEndTask?.cancel()
        speechEndTask = nil

        var audio = Data()
        do {
            audio = try voiceRecorder.stopRecording()
        } catch {}
        clearVoiceCallbacks()

        let live = queryText.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty {
            canConfirmQuery.value = true
            isRecording.value = false
            return
        }

        isRecording.value = false
        guard !audio.isEmpty else { return }
        Task { @MainActor in
            let result = try? await transcribeFoodVoiceUseCase.execute(audioData: audio)
            let text = result?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty {
                queryText.value = text
                canConfirmQuery.value = true
            }
        }
    }

    private func confirmQueryTapped() {
        searchTapped()
    }

    private func cancelVoice() {
        speechEndTask?.cancel()
        speechEndTask = nil
        if isRecording.value {
            voiceRecorder.cancelRecording()
            isRecording.value = false
        }
        clearVoiceCallbacks()
    }

    private func clearVoiceCallbacks() {
        voiceRecorder.onPartialTranscript = nil
        voiceRecorder.onUtteranceFinal = nil
    }
}
