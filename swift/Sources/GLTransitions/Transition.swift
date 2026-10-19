/// The gl-transitions collection: `all` the transitions, or one by `name`.
public enum GLTransitions {
    private static let byName = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })

    /// The transition with this name (as in gl-transitions.com), if the collection has it.
    public static func named(_ name: String) -> Transition? {
        byName[name]
    }
}

/// A transition between two images: its metadata, parameters and Metal fragment shader.
public struct Transition: Hashable, Sendable {
    public let name: String
    public let author: String
    public let license: String
    public let description: String?
    public let tags: [String]
    /// The parameters, in declaration order.
    public let params: [Param]
    /// The extra textures the shader samples besides `from` and `to` (e.g. `luma`), in order.
    public let textures: [String]
    /// Where `progress`, `ratio` and each parameter go in the uniform buffer.
    public let uniformLayout: UniformLayout
    /// The Metal fragment shader `main_`: uniform buffer at `[[buffer(0)]]`, a sampler at
    /// `[[sampler(0)]]`, `from` and `to` at `[[texture(0)]]` and `[[texture(1)]]`, then the extra
    /// textures; uv in `[[user(loc0)]]` with a bottom-left origin.
    public let metalSource: String

    public static func == (lhs: Transition, rhs: Transition) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    /// The parameter with this name.
    public func param(_ name: String) -> Param? {
        params.first { $0.name == name }
    }

    /// Each parameter's default value.
    public var defaultParams: [String: ParamValue] {
        Dictionary(uniqueKeysWithValues: params.map { ($0.name, $0.defaultValue) })
    }
}

/// A transition parameter.
public struct Param: Hashable, Sendable {
    public let name: String
    public let type: ParamType
    public let defaultValue: ParamValue
    public let min: Float?
    public let max: Float?
    public let step: Float?
    /// A `vec3` or `vec4` meant as an RGB(A) color.
    public let isColor: Bool
    public let description: String?
}

public enum ParamType: String, Hashable, Sendable {
    case float, vec2, vec3, vec4, int, ivec2, ivec3, ivec4, bool
}

public enum ParamValue: Hashable, Sendable {
    case float(Float)
    case vec2(SIMD2<Float>)
    case vec3(SIMD3<Float>)
    case vec4(SIMD4<Float>)
    case int(Int32)
    case ivec2(SIMD2<Int32>)
    case ivec3(SIMD3<Int32>)
    case ivec4(SIMD4<Int32>)
    case bool(Bool)

    public var type: ParamType {
        switch self {
        case .float: .float
        case .vec2: .vec2
        case .vec3: .vec3
        case .vec4: .vec4
        case .int: .int
        case .ivec2: .ivec2
        case .ivec3: .ivec3
        case .ivec4: .ivec4
        case .bool: .bool
        }
    }
}

/// The uniform buffer of a transition: `progress` and `ratio`, then each parameter.
public struct UniformLayout: Hashable, Sendable {
    /// In bytes.
    public let size: Int
    public let fields: [UniformField]
}

public struct UniformField: Hashable, Sendable {
    public let name: String
    public let type: ParamType
    /// In bytes.
    public let offset: Int
}
