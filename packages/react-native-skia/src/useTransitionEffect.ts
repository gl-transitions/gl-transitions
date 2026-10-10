import { useMemo } from "react";
import { Skia, type SkRuntimeEffect } from "@shopify/react-native-skia";
import transitions, { type Transition as CatalogTransition } from "gl-transitions";
import sksl from "gl-transitions/sksl/index.js";
import { makeUniforms, type ParamInput, type TransitionParams, type TransitionUniforms } from "./uniforms.ts";

export interface TransitionEffect<N extends string = string> {
  name: N;
  /** The compiled effect, for `<Shader source>`. Children: from, to, then one per entry of `transition.textures`. */
  effect: SkRuntimeEffect;
  /** The transition from the gl-transitions catalog: description, params (types, defaults, ranges), textures… */
  transition: CatalogTransition;
  /** Uniforms for `<Shader uniforms>`, drawing at `width` x `height`. */
  uniforms(width: number, height: number, progress: number, params?: TransitionParams<N>): TransitionUniforms;
}

const byName = new Map(transitions.map((t) => [t.name, t]));
const effects = new Map<string, TransitionEffect>();

/** Compiles a transition (once: effects are cached by name). Throws if it doesn't exist or doesn't compile. */
export function getTransitionEffect<N extends string>(name: N): TransitionEffect<N> {
  let cached = effects.get(name);
  if (!cached) {
    const transition = byName.get(name);
    if (!transition) throw new Error(`gl-transitions: unknown transition '${name}'`);
    const source = sksl[name];
    if (!source) throw new Error(`gl-transitions: '${name}' has no SkSL version`);
    const effect = Skia.RuntimeEffect.Make(source);
    if (!effect) throw new Error(`gl-transitions: '${name}' failed to compile with this version of Skia`);
    cached = {
      name,
      effect,
      transition,
      uniforms: (width, height, progress, params) =>
        makeUniforms(transition, width, height, progress, params as { [name: string]: ParamInput }),
    };
    effects.set(name, cached);
  }
  return cached as TransitionEffect<N>;
}

/** The compiled effect of a transition, to use with your own `<Shader>` and children (videos, any shader…). */
export function useTransitionEffect<N extends string>(name: N): TransitionEffect<N> {
  return useMemo(() => getTransitionEffect(name), [name]);
}
