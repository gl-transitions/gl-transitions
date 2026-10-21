// Renders every transition between the images of the GLSL reference renders and writes one strip
// per transition (`<out>/<name>.png`, one frame per progress value), laid out as the references, or
// `<out>/<name>.error`. scripts/swift-package/check.mjs runs it and compares the strips with the
// references.
//
// Usage: gl-transitions-check <images dir with from.png, to.png, extra.png> <out dir> <progress values, comma-separated>

import CoreGraphics
import Foundation
import GLTransitions
import ImageIO
import Metal
import UniformTypeIdentifiers

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 3 else {
    FileHandle.standardError.write("usage: gl-transitions-check <images dir> <out dir> <progress values>\n".data(using: .utf8)!)
    exit(2)
}
let images = URL(fileURLWithPath: arguments[0])
let out = URL(fileURLWithPath: arguments[1])
let progressValues = arguments[2].split(separator: ",").map { Float($0)! }
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let renderer = try TransitionRenderer()
let device = renderer.device
let queue = device.makeCommandQueue()!

// RGBA8 pixels, as stored: no color conversion, so that the shaders see the references' values.
func texture(_ name: String) throws -> MTLTexture {
    let url = images.appendingPathComponent(name)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path]) }
    let (width, height) = (image.width, image.height)
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(
        data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
    let texture = device.makeTexture(descriptor: descriptor)!
    texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: pixels, bytesPerRow: width * 4)
    return texture
}

func writePNG(_ pixels: [UInt8], width: Int, height: Int, to url: URL) {
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let image = CGImage(
        width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )!
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

let from = try texture("from.png")
let to = try texture("to.png")
let extra = try texture("extra.png")
let (width, height) = (from.width, from.height)
let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false)
descriptor.usage = [.renderTarget, .shaderRead]
descriptor.storageMode = .shared
let target = device.makeTexture(descriptor: descriptor)!

var failures = 0
for transition in GLTransitions.all {
    let textures = Dictionary(uniqueKeysWithValues: transition.textures.map { ($0, extra) })
    var strip = [UInt8](repeating: 0, count: width * progressValues.count * height * 4)
    do {
        for (i, progress) in progressValues.enumerated() {
            let commandBuffer = queue.makeCommandBuffer()!
            try renderer.encode(transition, from: from, to: to, progress: progress, textures: textures, into: target, commandBuffer: commandBuffer)
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            var frame = [UInt8](repeating: 0, count: width * height * 4)
            target.getBytes(&frame, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            for y in 0 ..< height {
                let row = (y * progressValues.count * width + i * width) * 4
                strip.replaceSubrange(row ..< row + width * 4, with: frame[y * width * 4 ..< (y + 1) * width * 4])
            }
        }
        writePNG(strip, width: width * progressValues.count, height: height, to: out.appendingPathComponent("\(transition.name).png"))
    } catch {
        failures += 1
        try error.localizedDescription.write(to: out.appendingPathComponent("\(transition.name).error"), atomically: true, encoding: .utf8)
    }
}
FileHandle.standardError.write("Rendered \(GLTransitions.all.count - failures) of \(GLTransitions.all.count) transitions with \(device.name) to \(out.path)\n".data(using: .utf8)!)
