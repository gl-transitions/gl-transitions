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

declare const transitions: Transition[];
export default transitions;
