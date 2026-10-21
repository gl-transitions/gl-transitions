import Foundation

public enum TransitionError: Error, Equatable, LocalizedError {
    case unknownParam(transition: String, name: String)
    case wrongParamType(transition: String, name: String, expected: ParamType, got: ParamType)
    case missingTexture(transition: String, name: String)
    case unknownTexture(transition: String, name: String)
    case noMetalDevice
    case compilation(transition: String, message: String)
    case rendering(String)
    case videoComposition(String)

    public var errorDescription: String? {
        switch self {
        case let .unknownParam(transition, name):
            "\(transition) has no parameter \(name)"
        case let .wrongParamType(transition, name, expected, got):
            "\(transition).\(name) is a \(expected.rawValue), not a \(got.rawValue)"
        case let .missingTexture(transition, name):
            "\(transition) needs the texture \(name)"
        case let .unknownTexture(transition, name):
            "\(transition) has no texture \(name)"
        case .noMetalDevice:
            "no Metal device"
        case let .compilation(transition, message):
            "\(transition) failed to compile: \(message)"
        case let .rendering(message), let .videoComposition(message):
            message
        }
    }
}

extension Transition {
    /// The uniform buffer of the shader: `progress`, `ratio` (width / height of the output), then
    /// each parameter, from `params` or its default. `bool` parameters are written as 0 or 1.
    public func uniformBuffer(progress: Float, ratio: Float, params: [String: ParamValue] = [:]) throws -> [UInt8] {
        for (name, value) in params {
            guard let param = param(name) else {
                throw TransitionError.unknownParam(transition: self.name, name: name)
            }
            guard param.type == value.type else {
                throw TransitionError.wrongParamType(transition: self.name, name: name, expected: param.type, got: value.type)
            }
        }
        var buffer = [UInt8](repeating: 0, count: uniformLayout.size)
        for field in uniformLayout.fields {
            let value: ParamValue? = switch field.name {
            case "progress": .float(progress)
            case "ratio": .float(ratio)
            default: params[field.name] ?? param(field.name)?.defaultValue
            }
            if let value {
                buffer.write(value, at: field.offset)
            }
        }
        return buffer
    }
}

private extension [UInt8] {
    mutating func write(_ value: ParamValue, at offset: Int) {
        switch value {
        case let .float(v): write([v], at: offset)
        case let .vec2(v): write([v.x, v.y], at: offset)
        case let .vec3(v): write([v.x, v.y, v.z], at: offset)
        case let .vec4(v): write([v.x, v.y, v.z, v.w], at: offset)
        case let .int(v): write([v], at: offset)
        case let .ivec2(v): write([v.x, v.y], at: offset)
        case let .ivec3(v): write([v.x, v.y, v.z], at: offset)
        case let .ivec4(v): write([v.x, v.y, v.z, v.w], at: offset)
        case let .bool(v): write([Int32(v ? 1 : 0)], at: offset)
        }
    }

    mutating func write<T>(_ components: [T], at offset: Int) {
        components.withUnsafeBytes { bytes in
            replaceSubrange(offset ..< offset + bytes.count, with: bytes)
        }
    }
}
