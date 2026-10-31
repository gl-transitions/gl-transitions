import { Composition } from "remotion";
import transitions from "gl-transitions";
import { Check, TRANSITION } from "./Check.tsx";
import { SHOWCASE_DURATION } from "./timing.ts";
import { PROMO_DURATION } from "./promo-timing.ts";

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
    <Composition
      id="PromoVertical"
      lazyComponent={() => import("./Promo.tsx")}
      width={1080}
      height={1920}
      fps={30}
      durationInFrames={PROMO_DURATION}
    />
    <Composition
      id="PromoSquare"
      lazyComponent={() => import("./Promo.tsx")}
      width={1080}
      height={1080}
      fps={30}
      durationInFrames={PROMO_DURATION}
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
