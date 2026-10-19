import GLTransitions
import Metal
import XCTest

final class RendererTests: XCTestCase {
    private var renderer: TransitionRenderer!
    private var queue: MTLCommandQueue!

    override func setUpWithError() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("no Metal device") }
        renderer = try TransitionRenderer(device: device)
        queue = try XCTUnwrap(device.makeCommandQueue())
    }

    private func texture(_ color: SIMD4<UInt8>, size: Int = 8) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: size, height: size, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let texture = renderer.device.makeTexture(descriptor: descriptor)!
        let pixels = [SIMD4<UInt8>](repeating: color, count: size * size)
        texture.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: pixels, bytesPerRow: size * 4)
        return texture
    }

    private func render(_ name: String, progress: Float, textures: [String: MTLTexture] = [:]) throws -> SIMD4<UInt8> {
        let transition = try XCTUnwrap(GLTransitions.named(name))
        let target = texture(.zero)
        let commandBuffer = try XCTUnwrap(queue.makeCommandBuffer())
        try renderer.encode(
            transition, from: texture(SIMD4(255, 0, 0, 255)), to: texture(SIMD4(0, 0, 255, 255)),
            progress: progress, textures: textures, into: target, commandBuffer: commandBuffer
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        var pixel = SIMD4<UInt8>.zero
        target.getBytes(&pixel, bytesPerRow: target.width * 4, from: MTLRegionMake2D(4, 4, 1, 1), mipmapLevel: 0)
        return pixel
    }

    func testEveryTransitionCompiles() throws {
        for transition in GLTransitions.all {
            XCTAssertNoThrow(try renderer.prepare(transition, pixelFormat: .rgba8Unorm), transition.name)
        }
    }

    func testFade() throws {
        XCTAssertEqual(try render("fade", progress: 0), SIMD4(255, 0, 0, 255))
        XCTAssertEqual(try render("fade", progress: 1), SIMD4(0, 0, 255, 255))
        let half = try render("fade", progress: 0.5)
        XCTAssertEqual(Int(half.x), 128, accuracy: 1)
        XCTAssertEqual(Int(half.z), 128, accuracy: 1)
    }

    func testTextures() throws {
        XCTAssertThrowsError(try render("luma", progress: 0.5)) {
            XCTAssertEqual($0 as? TransitionError, .missingTexture(transition: "luma", name: "luma"))
        }
        XCTAssertThrowsError(try render("fade", progress: 0.5, textures: ["luma": texture(.zero)])) {
            XCTAssertEqual($0 as? TransitionError, .unknownTexture(transition: "fade", name: "luma"))
        }
        // The dark parts of the mask go first.
        XCTAssertEqual(try render("luma", progress: 0.5, textures: ["luma": texture(SIMD4(0, 0, 0, 255))]), SIMD4(0, 0, 255, 255))
        XCTAssertEqual(try render("luma", progress: 0.5, textures: ["luma": texture(SIMD4(255, 255, 255, 255))]), SIMD4(255, 0, 0, 255))
    }
}
