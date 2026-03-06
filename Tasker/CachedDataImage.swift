import SwiftUI
import UIKit
import ImageIO

private final class DataImageCache {
    static let shared = DataImageCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 150 * 1024 * 1024
    }

    func image(for key: NSString) -> UIImage? {
        cache.object(forKey: key)
    }

    func insert(_ image: UIImage, for key: NSString) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key, cost: max(cost, 1))
    }
}

struct CachedDataImage<Content: View, Placeholder: View>: View {
    let data: Data
    var maxPixelSize: CGFloat? = nil
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @Environment(\.displayScale) private var displayScale
    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: data) {
            let pixelSize = resolvedPixelSize()
            let key = cacheKey(for: data, pixelSize: pixelSize)

            if let cached = DataImageCache.shared.image(for: key) {
                uiImage = cached
                return
            }

            let source = data
            let decoded = await Task.detached(priority: .utility) {
                Self.decodeImage(data: source, pixelSize: pixelSize)
            }.value

            guard let decoded else { return }
            DataImageCache.shared.insert(decoded, for: key)
            uiImage = decoded
        }
    }

    private func resolvedPixelSize() -> Int? {
        guard let maxPixelSize, maxPixelSize > 0 else { return nil }
        let size = Int((maxPixelSize * displayScale).rounded(.up))
        return max(size, 1)
    }

    private func cacheKey(for data: Data, pixelSize: Int?) -> NSString {
        "\(data.hashValue)_\(pixelSize ?? 0)" as NSString
    }

    nonisolated private static func decodeImage(data: Data, pixelSize: Int?) -> UIImage? {
        guard let pixelSize else {
            return UIImage(data: data)
        }

        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else {
            return UIImage(data: data)
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: pixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }
}
