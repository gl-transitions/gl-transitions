import CoreGraphics
import Foundation
import ImageIO

/// The sample images of the gl-transitions previews, and the extra image of the transitions that
/// take one (LumaWipe, DisplacementMap…).
struct Samples: Sendable {
    let images: [CGImage]
    /// A grayscale spiral.
    let extra: CGImage

    static func load() throws -> Samples {
        let images = try ["1", "2", "3"].map { name in
            guard let url = Bundle.module.url(forResource: name, withExtension: "jpg"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: "SampleImages/\(name).jpg"]) }
            return image
        }
        return Samples(images: images, extra: spiral(size: 256))
    }

    var aspectRatio: CGFloat {
        CGFloat(images[0].width) / CGFloat(images[0].height)
    }

    private static func spiral(size: Int) -> CGImage {
        var pixels = [UInt8](repeating: 255, count: size * size * 4)
        for y in 0 ..< size {
            for x in 0 ..< size {
                let dx = Float(x) / Float(size - 1) - 0.5
                let dy = Float(y) / Float(size - 1) - 0.5
                let angle = atan2(dy, dx) / (2 * .pi) + 0.5
                let radius = (dx * dx + dy * dy).squareRoot() * 1.4
                let gray = UInt8((angle + radius * 3).truncatingRemainder(dividingBy: 1) * 255)
                let i = (y * size + x) * 4
                (pixels[i], pixels[i + 1], pixels[i + 2]) = (gray, gray, gray)
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
            width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: size * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )!
    }
}
