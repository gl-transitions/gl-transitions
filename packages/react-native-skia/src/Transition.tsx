import { useMemo, type ReactNode } from "react";
import {
  Group,
  ImageShader,
  Rect,
  Shader,
  type Fit,
  type SkImage,
  type SkRuntimeEffect,
} from "@shopify/react-native-skia";
import {
  makeUniforms,
  type ParamInput,
  type TransitionName,
  type TransitionParams,
  type TransitionUniforms,
} from "./uniforms.ts";
import { useTransitionEffect } from "./useTransitionEffect.ts";

/** A Reanimated shared or derived value, or anything else React Native Skia animates (`{ value }`). */
export interface AnimatedValue<T> {
  readonly value: T;
}

/** An image, or an animated one such as the current frame of `useVideo`. `null` draws nothing (still loading). */
export type TransitionImage = SkImage | null | AnimatedValue<SkImage | null>;

export interface TransitionProps<N extends string = TransitionName> {
  /** Transition name, as in gl-transitions (e.g. "crosswarp"). */
  name: N;
  from: TransitionImage;
  to: TransitionImage;
  /** From 0 (shows `from`) to 1 (shows `to`). A Reanimated value animates without re-rendering. */
  progress: number | AnimatedValue<number>;
  width: number;
  height: number;
  x?: number;
  y?: number;
  /** Parameters of the transition; the ones left out keep their default value. */
  params?: TransitionParams<N>;
  /** Extra images some transitions need, by name (e.g. `luma` for "luma"): see `transition.textures`. */
  textures?: { [name: string]: TransitionImage };
  /** How `from`, `to` and the textures fill the rectangle. Default: "cover". */
  fit?: Fit;
}

/** Draws a gl-transition between two images in a `width` x `height` rectangle of a Skia `<Canvas>`. */
export function Transition<N extends string>({
  name,
  from,
  to,
  progress,
  width,
  height,
  x = 0,
  y = 0,
  params,
  textures = {},
  fit = "cover",
}: TransitionProps<N>) {
  const { effect, transition } = useTransitionEffect(name);
  const base = useMemo(
    () => makeUniforms(transition, width, height, 0, params as { [name: string]: ParamInput }),
    [transition, width, height, params],
  );
  const rect = useMemo(() => ({ x: 0, y: 0, width, height }), [width, height]);

  const images = [from, to];
  for (const texture of transition.textures) {
    if (!(texture in textures)) throw new Error(`gl-transitions: '${name}' needs the texture '${texture}'`);
    images.push(textures[texture]);
  }
  if (images.includes(null)) return null;

  const children = images.map((image, i) => (
    <ImageShader key={i} image={image} fit={fit} rect={rect} tx="clamp" ty="clamp" />
  ));
  return (
    <Group transform={[{ translateX: x }, { translateY: y }]}>
      <Rect x={0} y={0} width={width} height={height}>
        {typeof progress === "number" ? (
          <Shader source={effect} uniforms={{ ...base, progress }}>
            {children}
          </Shader>
        ) : (
          <AnimatedShader effect={effect} base={base} progress={progress}>
            {children}
          </AnimatedShader>
        )}
      </Rect>
    </Group>
  );
}

interface Reanimated {
  useDerivedValue<T>(updater: () => T, dependencies?: unknown[]): AnimatedValue<T>;
}

declare const require: (id: string) => unknown;
let reanimated: Reanimated | undefined;

// Reanimated is only needed for an animated progress, so it is an optional peer dependency.
// Metro treats a require() inside try/catch as optional (allowOptionalDependencies, on in the
// React Native and Expo default configs), as React Native Skia does for its own Reanimated import.
function loadReanimated(): Reanimated {
  if (!reanimated) {
    try {
      reanimated = require("react-native-reanimated") as Reanimated;
    } catch {
      throw new Error("gl-transitions: an animated `progress` needs react-native-reanimated");
    }
  }
  return reanimated;
}

function AnimatedShader({
  effect,
  base,
  progress,
  children,
}: {
  effect: SkRuntimeEffect;
  base: TransitionUniforms;
  progress: AnimatedValue<number>;
  children: ReactNode;
}) {
  const uniforms = loadReanimated().useDerivedValue(() => {
    "worklet";
    return { ...base, progress: progress.value };
  }, [base, progress]);
  return (
    <Shader source={effect} uniforms={uniforms}>
      {children}
    </Shader>
  );
}
