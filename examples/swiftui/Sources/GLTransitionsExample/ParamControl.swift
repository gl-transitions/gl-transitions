import GLTransitions
import SwiftUI

/// A slider for a float or int parameter, a toggle for a bool; vectors are only shown.
struct ParamControl: View {
    let param: Param
    @Binding var value: ParamValue

    var body: some View {
        HStack {
            Text(param.name).frame(width: 140, alignment: .leading)
            switch value {
            case let .float(v):
                Slider(value: Binding(get: { v }, set: { value = .float($0) }), in: range(v))
                Text(v.formatted(.number.precision(.fractionLength(2)))).monospacedDigit().frame(width: 50, alignment: .trailing)
            case let .int(v):
                Slider(value: Binding(get: { Float(v) }, set: { value = .int(Int32($0.rounded())) }), in: range(Float(v)), step: 1)
                Text("\(v)").monospacedDigit().frame(width: 50, alignment: .trailing)
            case let .bool(v):
                Toggle(param.name, isOn: Binding(get: { v }, set: { value = .bool($0) })).labelsHidden()
                Spacer()
            default:
                Text(value.components.map { $0.formatted() }.joined(separator: ", "))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    // The declared range, or one around the default.
    private func range(_ value: Float) -> ClosedRange<Float> {
        let defaultValue = param.defaultValue.components[0]
        let span = max(abs(defaultValue) * 2, 1)
        let lower = param.min ?? (defaultValue >= 0 ? 0 : -span)
        let upper = param.max ?? span
        return min(lower, value) ... max(upper, value)
    }
}

extension ParamValue {
    var components: [Float] {
        switch self {
        case let .float(v): [v]
        case let .vec2(v): [v.x, v.y]
        case let .vec3(v): [v.x, v.y, v.z]
        case let .vec4(v): [v.x, v.y, v.z, v.w]
        case let .int(v): [Float(v)]
        case let .ivec2(v): [Float(v.x), Float(v.y)]
        case let .ivec3(v): [Float(v.x), Float(v.y), Float(v.z)]
        case let .ivec4(v): [Float(v.x), Float(v.y), Float(v.z), Float(v.w)]
        case let .bool(v): [v ? 1 : 0]
        }
    }
}
