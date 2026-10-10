// Types for the gl-transitions collection (generated from the GitHub repository).

export type ParamType =
  | "float" | "int" | "bool"
  | "vec2" | "vec3" | "vec4"
  | "ivec2" | "ivec3" | "ivec4"
  | "mat2" | "mat3" | "mat4";

export type ParamValue = number | boolean | number[];

export interface TransitionParam {
  type: ParamType;
  /** Default value, from the `// = value` comment of the uniform. */
  default?: ParamValue;
  /** Suggested bounds for a UI control, from `@range(min, max[, step])`. Per component for vectors. */
  min?: number;
  max?: number;
  step?: number;
  /** The value is an RGB / RGBA color, from `@color`. */
  color?: boolean;
  description?: string;
}

export interface Transition {
  /** File name without `.glsl`. Stable: never renamed once published. */
  name: string;
  author: string;
  license: string;
  /** GLSL source implementing `vec4 transition(vec2 uv)` (GL Transition Specification v1). */
  glsl: string;
  description?: string;
  tags: string[];
  params: { [name: string]: TransitionParam };
  /** Extra `sampler2D` inputs beyond `from` and `to`, to be provided by the implementer. */
  textures: string[];
  /** Legacy: parameter types. Prefer `params`. */
  paramsTypes: { [name: string]: ParamType };
  /** Legacy: parameter default values. Prefer `params`. */
  defaultParams: { [name: string]: ParamValue };
  createdAt?: string;
  updatedAt?: string;
}

/** Uniform buffer and textures of `wgsl/<name>.wgsl` and `msl/<name>.metal`, from `layouts.json`. */
export interface ShaderLayout {
  /** `progress`, `ratio`, then the parameters; offsets in bytes (std140 / WGSL uniform layout). `bool` is stored as a 32-bit int. */
  uniforms: { name: string; type: ParamType; offset: number }[];
  /** Uniform buffer size in bytes, a multiple of 16. */
  size: number;
  /** Extra textures, bound after `from` and `to`. */
  textures: string[];
}

/** Content of `layouts.json`, by transition name. */
export type ShaderLayouts = { [name: string]: ShaderLayout };

export type TargetId = "sksl" | "glsl3" | "wgsl" | "msl";

/**
 * Per transition and target, from `compatibility.json`. The target file is shipped
 * for every status except `compile-error` and `unsupported`.
 * - `match`: renders like the GLSL reference; `close`: up to 5% of pixels differ;
 *   `noise-only`: same picture, different random noise grain
 * - `differs`: renders differently (usually random patterns that legitimately differ)
 * - `compiled`: accepted by the target's compiler, not rendered
 * - `translated`: generated, but no compiler for the target was available in the build
 * - `no-reference`: rendered, but no reference to compare with
 * - `compile-error`, `unsupported`: not shipped for this target
 */
export type CompatibilityStatus =
  | "match"
  | "noise-only"
  | "close"
  | "differs"
  | "compiled"
  | "translated"
  | "no-reference"
  | "compile-error"
  | "unsupported";

export interface TargetCompatibility {
  status: CompatibilityStatus;
  /** Share of pixels that differ from the GLSL reference in the worst frame, 0 to 1. */
  differingPixels?: number;
  /** Uses hash noise (`fract(sin(x) * 43758.5453)`), which differs between implementations. */
  hashNoise?: boolean;
  /** First line of the compiler or converter error. */
  error?: string;
}

/** Content of `compatibility.json`. */
export interface Compatibility {
  targets: {
    [target in TargetId]?: {
      language: string;
      /** File of a transition in the package, `{name}` being its name. */
      path: string;
      /** Statuses come from rendering and comparing with the GLSL reference, not only compiling. */
      rendered: boolean;
    };
  };
  transitions: { [name: string]: { [target in TargetId]?: TargetCompatibility } };
}

declare const transitions: Transition[];
export default transitions;
