import ImageIO
import SwiftUI
import UIKit

struct AnimatedGIFView: UIViewRepresentable {
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        guard context.coordinator.name != name || context.coordinator.reduceMotion != reduceMotion else { return }
        context.coordinator.name = name
        context.coordinator.reduceMotion = reduceMotion
        let cacheKey = "\(name)|\(reduceMotion ? "still" : "animated")" as NSString
        if let cached = GIFCache.shared.object(forKey: cacheKey) {
            imageView.image = cached
            return
        }
        guard let url = resourceURL else {
            imageView.image = UIImage(systemName: "figure.strengthtraining.traditional")
            return
        }
        imageView.image = UIImage(systemName: "figure.strengthtraining.traditional")

        let expectedName = name
        let expectedReduceMotion = reduceMotion
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = GIFDecoder.image(at: url, animated: !expectedReduceMotion) else { return }
            GIFCache.shared.setObject(image, forKey: cacheKey, cost: image.estimatedMemoryCost)
            DispatchQueue.main.async { [weak imageView] in
                guard context.coordinator.name == expectedName,
                      context.coordinator.reduceMotion == expectedReduceMotion else { return }
                imageView?.image = image
            }
        }
    }

    final class Coordinator {
        var name: String?
        var reduceMotion: Bool?
    }

    private var resourceURL: URL? {
        Bundle.main.url(forResource: name, withExtension: nil)
            ?? Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Exercises")
            ?? Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Resources/Exercises")
    }
}

private enum GIFCache {
    static let shared: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 48 * 1_024 * 1_024
        return cache
    }()
}

private extension UIImage {
    var estimatedMemoryCost: Int {
        let frameCount = max(images?.count ?? 1, 1)
        return Int(size.width * scale * size.height * scale * 4) * frameCount
    }
}

private enum GIFDecoder {
    static func image(at url: URL, animated: Bool) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }

        let count = CGImageSourceGetCount(source)
        guard animated, count > 1 else {
            return CGImageSourceCreateImageAtIndex(source, 0, nil).map { UIImage(cgImage: $0) }
        }

        var frames: [UIImage] = []
        var duration = 0.0
        for index in 0..<count {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: frame))
            duration += frameDuration(source: source, index: index)
        }
        return UIImage.animatedImage(with: frames, duration: max(duration, 0.1))
    }

    private static func frameDuration(source: CGImageSource, index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else { return 0.1 }
        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let value = unclamped ?? clamped ?? 0.1
        return value <= 0 ? 0.1 : max(value, 0.02)
    }
}
