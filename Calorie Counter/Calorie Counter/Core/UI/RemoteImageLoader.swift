import ImageIO
import UIKit

private var remoteImageTokenKey: UInt8 = 0

final class RemoteImageLoader {
    static let shared = RemoteImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession
    private let retryDelayNanoseconds: UInt64
    private let maximumWait: TimeInterval
    private let failureCooldown: TimeInterval
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    private var recentFailures: [String: Date] = [:]

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "User-Agent": "BityCalorieCounter/1.0 (iOS)",
            "Accept": "image/jpeg,image/png,image/webp,image/gif,image/*;q=0.8"
        ]
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 80 * 1024 * 1024
        )
        return URLSession(configuration: configuration)
    }

    init(session: URLSession? = nil, retryDelayNanoseconds: UInt64 = 700_000_000,
         maximumWait: TimeInterval = 30, failureCooldown: TimeInterval = 20) {
        self.session = session ?? Self.makeSession()
        self.retryDelayNanoseconds = retryDelayNanoseconds
        self.maximumWait = maximumWait
        self.failureCooldown = failureCooldown
        cache.totalCostLimit = 40 * 1024 * 1024
    }

    func cached(_ url: URL) -> UIImage? {
        cached(url, pixelWidth: FoodImageURL.detailPixelWidth)
            ?? cached(url, pixelWidth: FoodImageURL.thumbnailPixelWidth)
    }

    func display(
        _ url: URL?,
        data: Data? = nil,
        in imageView: UIImageView,
        placeholder: UIImage?,
        fallbackURL: URL? = nil,
        onCompletion: ((Bool) -> Void)? = nil
    ) {
        let token = UUID()
        objc_setAssociatedObject(imageView, &remoteImageTokenKey, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        if let data, let image = UIImage(data: data) {
            applyFilledImage(image, to: imageView)
            if let url {
                cache.setObject(image, forKey: url as NSURL, cost: cacheCost(image))
            }
            onCompletion?(true)
            return
        }
        applyPlaceholder(placeholder, to: imageView)
        guard let url = correctedFoodImageURL(url, fallbackURL: fallbackURL) ?? fallbackURL else {
            onCompletion?(false)
            return
        }
        let pixelWidth = pixelWidth(for: imageView)
        if let cached = cached(url, pixelWidth: pixelWidth) {
            applyFilledImage(cached, to: imageView)
            onCompletion?(true)
            return
        }
        Task { [weak imageView] in
            let deadline = Date().addingTimeInterval(maximumWait)
            var image = await fetch(url, pixelWidth: pixelWidth)
            if image == nil, !Task.isCancelled, deadline.timeIntervalSinceNow > 0,
               let fallbackURL, fallbackURL != url {
                image = await fetch(fallbackURL, pixelWidth: pixelWidth, deadline: deadline)
            }
            let resolvedImage = image
            await MainActor.run {
                guard let imageView else { return }
                let current = objc_getAssociatedObject(imageView, &remoteImageTokenKey) as? UUID
                guard current == token else { return }
                if let image = resolvedImage {
                    applyFilledImage(image, to: imageView)
                }
                onCompletion?(resolvedImage != nil)
            }
        }
    }

    private func correctedFoodImageURL(_ url: URL?, fallbackURL: URL?) -> URL? {
        guard let fallbackURL,
              URLComponents(url: fallbackURL, resolvingAgainstBaseURL: false)?.queryItems?
                .contains(where: { $0.name == "v" && $0.value == "broth-2" }) == true else { return url }
        return fallbackURL
    }

    func fetch(_ url: URL) async -> UIImage? {
        await fetch(url, pixelWidth: FoodImageURL.detailPixelWidth)
    }

    func fetch(_ url: URL?, fallbackURL: URL?) async -> UIImage? {
        let deadline = Date().addingTimeInterval(maximumWait)
        let url = correctedFoodImageURL(url, fallbackURL: fallbackURL)
        if let url, let image = await fetch(url, pixelWidth: FoodImageURL.detailPixelWidth, deadline: deadline) {
            return image
        }
        guard let fallbackURL, fallbackURL != url, deadline.timeIntervalSinceNow > 0 else { return nil }
        return await fetch(fallbackURL, pixelWidth: FoodImageURL.detailPixelWidth, deadline: deadline)
    }

    func fetch(_ url: URL, pixelWidth: Int) async -> UIImage? {
        await fetch(url, pixelWidth: pixelWidth, deadline: Date().addingTimeInterval(maximumWait))
    }

    private func fetch(_ url: URL, pixelWidth: Int, deadline: Date) async -> UIImage? {
        if let cached = cached(url, pixelWidth: pixelWidth) {
            return cached
        }
        let requestURL = FoodImageURL.displayURL(url, pixelWidth: pixelWidth)
        let key = "\(pixelWidth):\(requestURL.absoluteString)"
        if let failure = recentFailures[key], Date().timeIntervalSince(failure) < failureCooldown {
            return nil
        }
        if let task = inFlight[key] {
            return await task.value
        }
        let task = Task {
            var image = await self.download(requestURL, pixelWidth: pixelWidth, deadline: deadline)
            if image == nil, requestURL != url, deadline.timeIntervalSinceNow > 0 {
                image = await self.download(url, pixelWidth: pixelWidth, deadline: deadline)
            }
            if let image {
                self.store(image, for: requestURL)
                self.recentFailures.removeValue(forKey: key)
            } else {
                if self.recentFailures.count >= 100 { self.recentFailures.removeAll() }
                self.recentFailures[key] = Date()
            }
            return image
        }
        inFlight[key] = task
        defer { inFlight.removeValue(forKey: key) }
        return await task.value
    }

    private func cached(_ url: URL, pixelWidth: Int) -> UIImage? {
        let requestURL = FoodImageURL.displayURL(url, pixelWidth: pixelWidth)
        return cache.object(forKey: requestURL as NSURL)
    }

    private func download(_ url: URL, pixelWidth: Int, deadline: Date) async -> UIImage? {
        let configuration = AIAssistantAPIConfiguration.production
        let workerImage = url.host == configuration.baseURL.host
            && url.scheme == configuration.baseURL.scheme
            && url.port == configuration.baseURL.port
            && (url.path.hasPrefix("/v1/generated-images/") || url.path == "/v1/food/image")
        let attempts = workerImage ? 12 : 1
        var delayNs = retryDelayNanoseconds
        var transientFailures = 0
        for attempt in 0..<attempts {
            guard !Task.isCancelled, deadline.timeIntervalSinceNow > 0 else { return nil }
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = min(workerImage ? 26 : 8, deadline.timeIntervalSinceNow)
                if workerImage, let apiKey = configuration.apiKey, !apiKey.isEmpty {
                    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                }
                let data: Data
                let response: URLResponse
                if let cached = session.configuration.urlCache?.cachedResponse(for: request),
                   (cached.response as? HTTPURLResponse)?.statusCode == 200,
                   let storedAt = cached.userInfo?["storedAt"] as? Date,
                   let lifetime = cacheLifetime(cached.response),
                   Date().timeIntervalSince(storedAt) < lifetime,
                   let image = await decodedImage(cached.data, pixelWidth: pixelWidth) {
                    return image
                }
                (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse,
                   http.statusCode == 202 || !(200...299).contains(http.statusCode) {
                    guard workerImage, http.value(forHTTPHeaderField: "x-image-status") != "failed" else { return nil }
                    if http.statusCode != 202 { transientFailures += 1 }
                    let retryable = http.statusCode == 202
                        || ([408, 429, 500, 502, 503, 504].contains(http.statusCode) && transientFailures < 3)
                    if retryable, attempt < attempts - 1 {
                        let serverDelay = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 0
                        let delay = max(Double(delayNs) / 1_000_000_000, serverDelay)
                        guard delay < deadline.timeIntervalSinceNow else { return nil }
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        delayNs = min(delayNs * 2, 2_500_000_000)
                        continue
                    }
                    return nil
                }
                guard let image = await decodedImage(data, pixelWidth: pixelWidth) else { return nil }
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   cacheLifetime(response) != nil {
                    session.configuration.urlCache?.storeCachedResponse(
                        CachedURLResponse(response: response, data: data, userInfo: ["storedAt": Date()], storagePolicy: .allowed),
                        for: request
                    )
                }
                return image
            } catch {
                transientFailures += 1
                let delay = Double(delayNs) / 1_000_000_000
                if workerImage, transientFailures < 3, attempt < attempts - 1,
                   !Task.isCancelled, delay < deadline.timeIntervalSinceNow {
                    do { try await Task.sleep(nanoseconds: delayNs) } catch { return nil }
                    delayNs = min(delayNs * 2, 2_500_000_000)
                    continue
                }
                return nil
            }
        }
        return nil
    }

    private func decodedImage(_ data: Data, pixelWidth: Int) async -> UIImage? {
        let cgImage = await Task.detached(priority: .userInitiated) {
            Self.decodedCGImage(from: data, maxPixelWidth: pixelWidth)
        }.value
        guard let cgImage else { return nil }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    private func cacheLifetime(_ response: URLResponse) -> TimeInterval? {
        guard let http = response as? HTTPURLResponse,
              let header = http.value(forHTTPHeaderField: "Cache-Control")?.lowercased(),
              !header.contains("no-store"), !header.contains("no-cache") else { return nil }
        let directives = header.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let maxAge = directives.first(where: { $0.hasPrefix("max-age=") }),
              let lifetime = TimeInterval(maxAge.dropFirst(8)), lifetime > 0 else { return nil }
        return lifetime
    }

    nonisolated private static func decodedCGImage(from data: Data, maxPixelWidth: Int) -> CGImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let downsample = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(maxPixelWidth, 1)
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, downsample)
    }

    private func applyFilledImage(_ image: UIImage, to imageView: UIImageView) {
        imageView.preferredSymbolConfiguration = nil
        imageView.clipsToBounds = true
        imageView.layer.masksToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.image = image
    }

    private func applyPlaceholder(_ placeholder: UIImage?, to imageView: UIImageView) {
        imageView.clipsToBounds = true
        imageView.layer.masksToBounds = true
        imageView.contentMode = placeholder?.isSymbolImage == true ? .scaleAspectFit : .scaleAspectFill
        imageView.image = placeholder
    }

    private func pixelWidth(for imageView: UIImageView) -> Int {
        let side = max(imageView.bounds.width, imageView.bounds.height)
        let points = side > 1 ? side : 80
        let scale = max(imageView.traitCollection.displayScale, 2)
        return FoodImageURL.snappedPixelWidth(Int(ceil(points * scale)))
    }

    private func store(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL, cost: cacheCost(image))
    }

    private func cacheCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
