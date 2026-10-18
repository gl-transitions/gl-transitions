import type { Transition as CatalogTransition } from "gl-transitions";
import type { ParamInput, TransitionName, TransitionParams } from "./transition-types.generated.ts";

export type { ParamInput, TransitionName, TransitionParams };

/** Uniform values as React Native Skia's `<Shader uniforms>` takes them. */
export type TransitionUniforms = { [name: string]: number | readonly number[] };

/**
 * Uniforms of the SkSL effect of `transition` (see the SkSL contract of gl-transitions):
 * output size, progress, ratio, then every parameter, from `params` or its default value.
 */
export function makeUniforms(
  transition: CatalogTransition,
  width: number,
  height: number,
  progress: number,
  params: { [name: string]: ParamInput | undefined } = {},
): TransitionUniforms {
  const uniforms: TransitionUniforms = { _resolution: [width, height], progress, ratio: width / height };
  for (const [name, param] of Object.entries(transition.params)) {
    const value = params[name] ?? param.default;
    if (value === undefined) {
      throw new Error(`gl-transitions: parameter '${name}' of '${transition.name}' has no default value`);
    }
    // SkSL has no bool uniforms: the effect declares them as int.
    uniforms[name] = typeof value === "boolean" ? Number(value) : value;
  }
  return uniforms;
}
