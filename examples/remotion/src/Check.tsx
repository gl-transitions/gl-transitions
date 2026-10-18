import { AbsoluteFill, Img, staticFile } from "remotion";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { glTransition } from "@gl-transitions/remotion";
import transitions from "gl-transitions";

// Every transition in turn, from `from.png` to `to.png`: the images of the GLSL reference renders
// (scripts/write-images.mjs). Each one fills its scenes, TRANSITION frames with linear timing, so
// transition k shows progress p at frame TRANSITION * (k + p): frames 1, 3, 5, 7 and 9 of each
// are the progress values of the reference strips (0.1 … 0.9). See scripts/check.mjs.

export const TRANSITION = 10;

const Scene = ({ image }: { image: string }) => (
  <AbsoluteFill>
    <Img src={staticFile(image)} style={{ width: "100%", height: "100%" }} />
  </AbsoluteFill>
);

export const Check = () => (
  <TransitionSeries>
    {transitions.flatMap(({ name, textures: needed }) => {
      const textures = Object.fromEntries(needed.map((t) => [t, staticFile("extra.png")]));
      return [
        <TransitionSeries.Sequence key={`${name}-from`} durationInFrames={TRANSITION}>
          <Scene image="from.png" />
        </TransitionSeries.Sequence>,
        <TransitionSeries.Transition
          key={`${name}-transition`}
          presentation={glTransition({ name, textures })}
          timing={linearTiming({ durationInFrames: TRANSITION })}
        />,
        <TransitionSeries.Sequence key={`${name}-to`} durationInFrames={TRANSITION}>
          <Scene image="to.png" />
        </TransitionSeries.Sequence>,
      ];
    })}
  </TransitionSeries>
);
