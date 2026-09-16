import Foundation

@MainActor
final class FetchRecipeBrowseSectionsUseCase {
    private let service: RecipeSectionsFetching
    private var cache: (locale: String, sections: [RecipeBrowseSection])?
    private var inflight: Task<[RecipeBrowseSection], Never>?
    private var pageCache: [String: (page: RecipeSectionPage, storedAt: Date)] = [:]
    private var pageInflight: [String: Task<RecipeSectionPage, Never>] = [:]

    init(service: RecipeSectionsFetching) {
        self.service = service
    }

    func peek(locale: String? = nil) -> [RecipeBrowseSection]? {
        let locale = locale ?? Locale.deviceIdentifier
        guard let cache, cache.locale == locale, !cache.sections.isEmpty else { return nil }
        return cache.sections
    }

    func execute(force: Bool = false) async -> [RecipeBrowseSection] {
        let locale = Locale.deviceIdentifier
        if !force, let cache, cache.locale == locale, !cache.sections.isEmpty {
            return cache.sections
        }
        if let inflight {
            return await inflight.value
        }
        let service = service
        let lastGood = cache?.locale == locale ? cache?.sections : nil
        let task = Task { @MainActor in
            var sections = (try? await service.fetchSections(locale: locale)) ?? []
            if sections.isEmpty {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                sections = (try? await service.fetchSections(locale: locale)) ?? []
            }
            if sections.isEmpty, let lastGood, !lastGood.isEmpty {
                return lastGood
            }
            return sections
        }
        inflight = task
        let sections = await task.value
        inflight = nil
        if !sections.isEmpty {
            cache = (locale, sections)
        }
        return sections
    }

    func recipes(in kind: RecipeBrowseSectionKind) async -> [Recipe] {
        await execute().first(where: { $0.id == kind })?.recipes ?? []
    }

    func recipesPage(in kind: RecipeBrowseSectionKind, offset: Int, limit: Int = 20) async -> RecipeSectionPage {
        let locale = Locale.deviceIdentifier
        if offset == 0, limit <= 2, let recipes = peek(locale: locale)?.first(where: { $0.id == kind })?.recipes,
           !recipes.isEmpty {
            let preview = Array(recipes.prefix(limit))
            return RecipeSectionPage(recipes: preview, nextOffset: preview.count, hasMore: recipes.count >= limit)
        }
        let key = "\(locale):\(kind.rawValue):\(offset):\(limit)"
        if let cached = pageCache[key], Date().timeIntervalSince(cached.storedAt) < 600 { return cached.page }
        if let pending = pageInflight[key] { return await pending.value }
        let service = service
        let cached = pageCache[key]
        let task = Task { @MainActor in
            for attempt in 0..<2 {
                guard !Task.isCancelled else { break }
                if let page = try? await service.fetchSectionPage(id: kind, locale: locale, offset: offset, limit: limit),
                   !page.isRetryableFailure {
                    self.pageCache[key] = (page, Date())
                    return page
                }
                if attempt == 0 { try? await Task.sleep(nanoseconds: 500_000_000) }
            }
            if let cached, Date().timeIntervalSince(cached.storedAt) < 86_400 { return cached.page }
            return RecipeSectionPage(recipes: [], nextOffset: offset, hasMore: false, isRetryableFailure: true)
        }
        pageInflight[key] = task
        let page = await task.value
        pageInflight[key] = nil
        return page
    }
}
