//
//  Created by Lorenzo Fiamingo on 04/11/20. Copyright (c) 2021 Lorenzo Fiamingo
// MODIFIED
//

import SwiftUI
import CoreGraphics

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct CachedAsyncImageCore<Content>: View where Content: View {
    
    @State private var phase: AsyncImagePhase
    @State private var isMonochromeIcon = false
    
    private let urlRequest: URLRequest?
    
    private let urlSession: URLSession
    
    private let scale: CGFloat
    
    private let transaction: Transaction
    
    private let content: (AsyncImagePhase, Bool) -> Content
    
    public var body: some View {
        content(phase, isMonochromeIcon)
            .task(id: urlRequest, load)
    }
    

    public init(url: URL?, urlCache: URLCache = .shared,  scale: CGFloat = 1) where Content == Image {
        let urlRequest = url.map { URLRequest(url: $0) }
        self.init(urlRequest: urlRequest, urlCache: urlCache, scale: scale)
    }

    public init(urlRequest: URLRequest?, urlCache: URLCache = .shared,  scale: CGFloat = 1) where Content == Image {
        self.init(urlRequest: urlRequest, urlCache: urlCache, scale: scale) { phase, _ in
#if os(macOS)
            phase.image ?? Image(universalImage: .init())
#else
            phase.image ?? Image(uiImage: .init())
#endif
        }
    }

    public init<I, P>(url: URL?, urlCache: URLCache = .shared,  scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P) where Content == _ConditionalContent<I, P>, I : View, P : View {
        let urlRequest = url.map { URLRequest(url: $0) }
        self.init(urlRequest: urlRequest, urlCache: urlCache, scale: scale, content: content, placeholder: placeholder)
    }
    

    public init<I, P>(urlRequest: URLRequest?, urlCache: URLCache = .shared,  scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P) where Content == _ConditionalContent<I, P>, I : View, P : View {
        self.init(urlRequest: urlRequest, urlCache: urlCache, scale: scale) { phase, _ in
            if let image = phase.image {
                content(image)
            } else {
                placeholder()
            }
        }
    }
 
    public init(url: URL?, urlCache: URLCache = .shared, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        let urlRequest = url.map { URLRequest(url: $0) }
        self.init(urlRequest: urlRequest, urlCache: urlCache, scale: scale, transaction: transaction, content: content)
    }

    public init(url: URL?, urlCache: URLCache = .shared, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase, Bool) -> Content) {
        let urlRequest = url.map { URLRequest(url: $0) }
        self.init(urlRequest: urlRequest, urlCache: urlCache, scale: scale, transaction: transaction, content: content)
    }
  
    public init(urlRequest: URLRequest?, urlCache: URLCache = .shared, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.init(urlRequest: urlRequest, urlCache: urlCache, scale: scale, transaction: transaction) { phase, _ in
            content(phase)
        }
    }

    public init(urlRequest: URLRequest?, urlCache: URLCache = .shared, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase, Bool) -> Content) {
        self.urlRequest = urlRequest
        if urlCache === URLCache.shared {
            self.urlSession = .shared
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.urlCache = urlCache
            self.urlSession = URLSession(configuration: configuration)
        }
        self.scale = scale
        self.transaction = transaction
        self.content = content
        
        self._phase = State(wrappedValue: .empty)
        do {
            if let urlRequest = urlRequest, let (image, isMonochromeIcon) = try cachedImage(from: urlRequest, cache: urlCache) {
                self._phase = State(wrappedValue: .success(image))
                self._isMonochromeIcon = State(wrappedValue: isMonochromeIcon)
            }
        } catch {
            self._phase = State(wrappedValue: .failure(error))
        }
    }
    
    @Sendable
    private func load() async {
        do {
            if let urlRequest = urlRequest {
                let ((image, isMonochromeIcon), metrics) = try await remoteImage(from: urlRequest, session: urlSession)
                if metrics?.transactionMetrics.last?.resourceFetchType == .localCache {
                    // WARNING: This does not behave well when the url is changed with another
                    self.isMonochromeIcon = isMonochromeIcon
                    phase = .success(image)
                } else {
                    withAnimation(transaction.animation) {
                        self.isMonochromeIcon = isMonochromeIcon
                        phase = .success(image)
                    }
                }
            } else {
                withAnimation(transaction.animation) {
                    phase = .empty
                }
            }
        } catch {
            withAnimation(transaction.animation) {
                phase = .failure(error)
            }
        }
    }
}

// MARK: - LoadingError

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
private extension AsyncImage {
    
    struct LoadingError: Error {
    }
}

// MARK: - Helpers

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
private extension CachedAsyncImageCore {
    private func remoteImage(
        from request: URLRequest,
        session: URLSession
    ) async throws -> ((Image, Bool), URLSessionTaskMetrics?) {
        
        let (data, response, metrics) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        if let metrics,
           metrics.redirectCount > 0,
           let lastResponse = metrics.transactionMetrics.last?.response {
            
            let requests = metrics.transactionMetrics.map { $0.request }
            
            if let cache = session.configuration.urlCache {
                requests.forEach(cache.removeCachedResponse)
                let lastCachedResponse = CachedURLResponse(
                    response: lastResponse,
                    data: data
                )
                cache.storeCachedResponse(lastCachedResponse, for: request)
            }
        }

        return (try image(from: data), metrics)
    }
    
    private func cachedImage(from request: URLRequest, cache: URLCache) throws -> (Image, Bool)? {
        guard let cachedResponse = cache.cachedResponse(for: request) else { return nil }
        return try image(from: cachedResponse.data)
    }
    
    private func image(from data: Data) throws -> (Image, Bool) {
#if os(macOS)
        if let image = UniversalImage(data: data) {
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            return (Image(universalImage: image), cgImage.map(isTransparentMonochrome) ?? false)
        } else {
            throw AsyncImage<Content>.LoadingError()
        }
#else
        if let uiImage = UIImage(data: data, scale: scale) {
            return (Image(uiImage: uiImage), uiImage.cgImage.map(isTransparentMonochrome) ?? false)
        } else {
            throw AsyncImage<Content>.LoadingError()
        }
#endif
    }

    private func isTransparentMonochrome(_ image: CGImage) -> Bool {
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drewImage = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drewImage else { return false }

        var transparent = 0
        var visible = 0
        var vivid = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Int(pixels[index + 3])
            if alpha < 32 {
                transparent += 1
                continue
            }
            visible += 1
            let red = Int(pixels[index])
            let green = Int(pixels[index + 1])
            let blue = Int(pixels[index + 2])
            let spread = max(red, max(green, blue)) - min(red, min(green, blue))
            if spread * 255 > 35 * alpha { vivid += 1 }
        }
        return transparent > side * side / 5 && visible > 0 && vivid * 20 < visible
    }
}

// MARK: - AsyncImageURLSession

private class URLSessionTaskController: NSObject, URLSessionTaskDelegate {
    
    var metrics: URLSessionTaskMetrics?
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        self.metrics = metrics
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
private extension URLSession {
    
    func data(for request: URLRequest) async throws -> (Data, URLResponse, URLSessionTaskMetrics?) {
        let controller = URLSessionTaskController()
        let (data, response) = try await data(for: request, delegate: controller)
        return (data, response, controller.metrics)
    }
}
