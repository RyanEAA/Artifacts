import SwiftUI
import UIKit

@MainActor
final class CachedRemoteImageLoader: ObservableObject {
    @Published var image: UIImage?

    private static let memoryCache = NSCache<NSURL, UIImage>()
    private static var inFlightTasks: [NSURL: Task<UIImage?, Never>] = [:]

    private var currentURL: NSURL?

    func load(from url: URL?) {
        guard let url else {
            currentURL = nil
            image = nil
            return
        }

        let nsURL = url as NSURL
        currentURL = nsURL

        if let cached = Self.memoryCache.object(forKey: nsURL) {
            image = cached
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
           let cachedImage = UIImage(data: cachedResponse.data) {
            Self.memoryCache.setObject(cachedImage, forKey: nsURL)
            image = cachedImage
            return
        }

        if let existingTask = Self.inFlightTasks[nsURL] {
            Task {
                let loaded = await existingTask.value
                guard self.currentURL == nsURL else { return }
                self.image = loaded
            }
            return
        }

        let task = Task<UIImage?, Never> {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let loadedImage = UIImage(data: data) else {
                    await MainActor.run { Self.inFlightTasks[nsURL] = nil }
                    return nil
                }

                let cachedResponse = CachedURLResponse(response: response, data: data)
                URLCache.shared.storeCachedResponse(cachedResponse, for: request)

                await MainActor.run {
                    Self.memoryCache.setObject(loadedImage, forKey: nsURL)
                    Self.inFlightTasks[nsURL] = nil
                }
                return loadedImage
            } catch {
                await MainActor.run {
                    Self.inFlightTasks[nsURL] = nil
                }
                return nil
            }
        }

        Self.inFlightTasks[nsURL] = task

        Task {
            let loaded = await task.value
            guard self.currentURL == nsURL else { return }
            self.image = loaded
        }
    }
}

struct CachedRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @StateObject private var loader = CachedRemoteImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            loader.load(from: url)
        }
    }
}
