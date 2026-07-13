import ImageIO
import SwiftUI
import UIKit

struct AnimatedGIFView: UIViewRepresentable {
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        guard let url = resourceURL else {
            imageView.image = UIImage(systemName: "figure.strengthtraining.traditional")
            return
        }
        imageView.image = GIFDecoder.image(at: url, animated: !reduceMotion)
    }

    private var resourceURL: URL? {
        Bundle.main.url(forResource: name, withExtension: nil)
            ?? Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Exercises")
            ?? Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Resources/Exercises")
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
        return value < 0.02 ? 0.1 : value
    }
}
