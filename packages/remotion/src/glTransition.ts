import { makeHtmlInCanvasPresentation, type HtmlInCanvasShader } from "@remotion/transitions";
import transitions, { type Transition as CatalogTransition } from "gl-transitions";
import { createRenderer } from "./renderer.ts";
import { loadImage } from "./textures.ts";
import type { ParamInput, TransitionName, TransitionParams } from "./transition-types.generated.ts";

const byName = new Map(transitions.map((t) => [t.name, t]));

type PassedProps = {
  transition: CatalogTransition;
  params: { [name: string]: ParamInput | undefined };
  textures: { [name: string]: string };
};

// Remotion captures both scenes (HTML-in-canvas): `nextImage` is the outgoing scene, the
// gl-transitions `from`; `prevImage` the incoming one, `to`. With only one of them captured
// yet, it is shown as is.
const shader: HtmlInCanvasShader<PassedProps> = (canvas) => {
  const gl = canvas.getContext("webgl2", { premultipliedAlpha: false });
  if (!gl) throw new Error("gl-transitions: WebGL 2 is not available");
  const renderer = createRenderer(gl);
  return {
    clear: renderer.clear,
    cleanup: renderer.dispose,
    draw: ({ prevImage, nextImage, width, height, time, passedProps: { transition, params, textures } }) => {
      renderer.draw({
        transition,
        from: nextImage,
        to: prevImage,
        progress: !prevImage ? 0 : !nextImage ? 1 : time,
        width,
        height,
        params,
        textures: Object.fromEntries(Object.entries(textures).map(([name, url]) => [name, loadImage(url)])),
      });
    },
  };
};

const presentation = makeHtmlInCanvasPresentation(shader);

export interface GlTransitionOptions<N extends TransitionName | (string & {}) = TransitionName> {
  /** Transition name, as in gl-transitions (e.g. "cube"). */
  name: N;
  /** Parameters of the transition; the ones left out keep their default value. */
  params?: TransitionParams<N>;
  /**
   * Images some transitions need (see `transition.textures`, e.g. `luma` for "luma"), by name:
   * URLs, for example from `staticFile()`.
   */
  textures?: { [name: string]: string };
}

/**
 * A presentation for `<TransitionSeries.Transition>` that plays a gl-transition between the
 * two scenes. It relies on Remotion's HTML-in-canvas: built into Remotion's renderer, and
 * behind a Chrome flag in the Studio (see the README).
 */
export function glTransition<N extends TransitionName | (string & {})>({
  name,
  params = {} as TransitionParams<N>,
  textures = {},
}: GlTransitionOptions<N>) {
  const transition = byName.get(name);
  if (!transition) throw new Error(`gl-transitions: unknown transition '${name}'`);
  for (const texture of transition.textures) {
    if (!(texture in textures)) throw new Error(`gl-transitions: '${name}' needs the texture '${texture}'`);
  }
  // Starts loading them early, where there is a DOM (not when a composition is imported on a server).
  if (typeof Image !== "undefined") for (const url of Object.values(textures)) loadImage(url);
  return presentation({ transition, params: params as PassedProps["params"], textures });
}
