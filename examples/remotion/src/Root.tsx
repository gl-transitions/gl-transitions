import { Composition } from "remotion";
import transitions from "gl-transitions";
import { Check, TRANSITION } from "./Check.tsx";
import { SHOWCASE_DURATION } from "./timing.ts";

export const Root = () => (
  <>
    <Composition
      id="Showcase"
      lazyComponent={() => import("./Showcase.tsx")}
      width={1920}
      height={1080}
      fps={30}
      durationInFrames={SHOWCASE_DURATION}
    />
    {/* At the size of the GLSL reference renders (scripts/rendering/reference-images.mjs). */}
    <Composition
      id="Check"
      component={Check}
      width={160}
      height={100}
      fps={30}
      durationInFrames={TRANSITION * transitions.length}
    />
  </>
);
