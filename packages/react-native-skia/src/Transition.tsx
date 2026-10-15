import { useMemo, type ReactNode } from "react";
import {
  AlphaType,
  ColorType,
  Group,
  ImageShader,
  Rect,
  Shader,
  Skia,
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

/**
 * An image, or an animated one such as the current frame of `useVideo`. `null` draws nothing (still loading);
 * an animated image whose value is `null` is drawn transparent until it loads.
 */
export type TransitionImage = SkImage | null | AnimatedValue<SkImage | null>;

export interface TransitionProps<N extends TransitionName | (string & {}) = TransitionName> {
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
export function Transition<N extends TransitionName | (string & {})>({
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
  // By value: params are usually written inline, a new object on every render.
  const paramsKey = JSON.stringify(params ?? {});
  const base = useMemo(
    () => makeUniforms(transition, width, height, 0, JSON.parse(paramsKey) as { [name: string]: ParamInput }),
    [transition, width, height, paramsKey],
  );
  const rect = useMemo(() => ({ x: 0, y: 0, width, height }), [width, height]);

  const images = [from, to];
  for (const texture of transition.textures) {
    if (!(texture in textures)) throw new Error(`gl-transitions: '${name}' needs the texture '${texture}'`);
    images.push(textures[texture]);
  }
  if (images.some((image) => image == null)) return null;

  const children = images.map((image, i) =>
    isAnimatedImage(image) ? (
      <AnimatedImageShader key={i} image={image} fit={fit} rect={rect} />
    ) : (
      <ImageShader key={i} image={image} fit={fit} rect={rect} tx="clamp" ty="clamp" />
    ),
  );
  return (
    <Group transform={[{ translateX: x }, { translateY: y }]}>
      <Rect x={0} y={0} width={width} height={height}>
        {typeof progress === "number" ? (
          <Shader source={effect} uniforms={{ ...base, progress }}>
            {children}
          </Shader>
        ) : (
          // Keyed by name: the uniforms are derived on the UI thread, after the new effect is
          // set, so a reused shader would draw a frame of the new effect with the old uniforms.
          <AnimatedShader key={name} effect={effect} base={base} progress={progress}>
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
    } catch (cause) {
      throw new Error("gl-transitions: animated values need react-native-reanimated", { cause });
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

function isAnimatedImage(image: TransitionImage): image is AnimatedValue<SkImage | null> {
  return image != null && typeof (image as SkImage).width !== "function";
}

let emptyImage: SkImage | null = null;

// React Native Skia skips an ImageShader whose image is null, which would shift the shader's
// children (`to` bound as `from`…): an animated image still loading is replaced by a transparent pixel.
function getEmptyImage(): SkImage {
  emptyImage ??= Skia.Image.MakeImage(
    { width: 1, height: 1, colorType: ColorType.RGBA_8888, alphaType: AlphaType.Premul },
    Skia.Data.fromBytes(new Uint8Array(4)),
    4,
  );
  if (!emptyImage) throw new Error("gl-transitions: could not create a placeholder image");
  return emptyImage;
}

function AnimatedImageShader({
  image,
  fit,
  rect,
}: {
  image: AnimatedValue<SkImage | null>;
  fit: Fit;
  rect: { x: number; y: number; width: number; height: number };
}) {
  const empty = getEmptyImage();
  const current = loadReanimated().useDerivedValue(() => {
    "worklet";
    return image.value ?? empty;
  }, [image, empty]);
  return <ImageShader image={current} fit={fit} rect={rect} tx="clamp" ty="clamp" />;
}
