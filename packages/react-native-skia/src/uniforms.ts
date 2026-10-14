import type { Transition as CatalogTransition } from "gl-transitions";
import type { TransitionParamsByName } from "./transition-types.generated.ts";

/** Name of a transition known when this package was built. Newer ones from gl-transitions work too. */
export type TransitionName = keyof TransitionParamsByName;

/** A parameter value: `number` for float and int, `boolean` for bool, an array for vectors. */
export type ParamInput = number | boolean | readonly number[];

/** Parameters of a transition, all optional: the ones left out keep their default value. */
export type TransitionParams<N extends string> = N extends TransitionName
  ? Partial<TransitionParamsByName[N]>
  : { [name: string]: ParamInput };

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
