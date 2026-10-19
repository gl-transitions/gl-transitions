import GLTransitions
import XCTest

final class CatalogTests: XCTestCase {
    func testCatalog() throws {
        XCTAssertGreaterThan(GLTransitions.all.count, 100)
        XCTAssertEqual(Set(GLTransitions.all.map(\.name)).count, GLTransitions.all.count)
        XCTAssertFalse(GLTransitions.catalogVersion.isEmpty)
        for transition in GLTransitions.all {
            XCTAssertEqual(GLTransitions.named(transition.name), transition)
            XCTAssertTrue(transition.metalSource.contains("fragment main_Output main_("), transition.name)
            let layout = transition.uniformLayout
            XCTAssertEqual(layout.fields.prefix(2).map(\.name), ["progress", "ratio"], transition.name)
            XCTAssertEqual(layout.fields.count, transition.params.count + 2, transition.name)
            XCTAssertEqual(layout.size % 16, 0, transition.name)
            for param in transition.params {
                XCTAssertEqual(param.defaultValue.type, param.type, "\(transition.name).\(param.name)")
                XCTAssertEqual(layout.fields.first { $0.name == param.name }?.type, param.type, "\(transition.name).\(param.name)")
            }
        }
        XCTAssertNil(GLTransitions.named("nope"))
    }

    func testUniformBuffer() throws {
        let transition = try XCTUnwrap(GLTransitions.named("GridFlip"))
        let buffer = try transition.uniformBuffer(progress: 0.25, ratio: 1.5, params: ["size": .ivec2(SIMD2(3, 2))])
        XCTAssertEqual(buffer.count, transition.uniformLayout.size)
        func read<T>(_: T.Type, _ name: String) throws -> T {
            let offset = try XCTUnwrap(transition.uniformLayout.fields.first { $0.name == name }).offset
            return buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
        }
        XCTAssertEqual(try read(Float.self, "progress"), 0.25)
        XCTAssertEqual(try read(Float.self, "ratio"), 1.5)
        XCTAssertEqual(try read(SIMD2<Int32>.self, "size"), SIMD2(3, 2))
        // Defaults for the others.
        XCTAssertEqual(try read(Float.self, "pause"), 0.1)
        XCTAssertEqual(try read(SIMD4<Float>.self, "bgcolor"), SIMD4(0, 0, 0, 1))
    }

    func testBoolParamsAreInts() throws {
        let transition = try XCTUnwrap(GLTransitions.all.first { $0.params.contains { $0.type == .bool } })
        let param = try XCTUnwrap(transition.params.first { $0.type == .bool })
        for value in [true, false] {
            let buffer = try transition.uniformBuffer(progress: 0, ratio: 1, params: [param.name: .bool(value)])
            let offset = try XCTUnwrap(transition.uniformLayout.fields.first { $0.name == param.name }).offset
            XCTAssertEqual(buffer.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int32.self) }, value ? 1 : 0)
        }
    }

    func testParamErrors() throws {
        let transition = try XCTUnwrap(GLTransitions.named("cube"))
        XCTAssertThrowsError(try transition.uniformBuffer(progress: 0, ratio: 1, params: ["nope": .float(1)])) {
            XCTAssertEqual($0 as? TransitionError, .unknownParam(transition: "cube", name: "nope"))
        }
        XCTAssertThrowsError(try transition.uniformBuffer(progress: 0, ratio: 1, params: ["persp": .int(1)])) {
            XCTAssertEqual($0 as? TransitionError, .wrongParamType(transition: "cube", name: "persp", expected: .float, got: .int))
        }
    }
}
