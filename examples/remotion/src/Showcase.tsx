import { AbsoluteFill, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { loadFont as loadDisplay } from "@remotion/google-fonts/BricolageGrotesque";
import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";
import { glTransition } from "@gl-transitions/remotion";
import { Backdrop, type Palette } from "./Backdrop.tsx";
import transitions from "gl-transitions";
import { SHOWCASE_SCENE, SHOWCASE_SLIDES, SHOWCASE_TRANSITION } from "./timing.ts";

// A few transitions between React scenes: any markup works (here a WebGL background and
// text), Remotion captures it.

const { fontFamily: display } = loadDisplay("normal", { weights: ["700"], subsets: ["latin"] });
const { fontFamily: mono } = loadMono("normal", { weights: ["400", "500"], subsets: ["latin"] });

type SlideProps = { kicker: string; title: string; code?: string; palette: Palette; seed: number };

const Slide = ({ kicker, title, code, palette, seed }: SlideProps) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  // The text settles in over the first half second.
  const t = interpolate(frame, [0, 0.5 * fps], [0, 1], { extrapolateRight: "clamp" });
  return (
    <AbsoluteFill style={{ background: "#05060a" }}>
      <Backdrop palette={palette} seed={seed} />
      <AbsoluteFill
        style={{
          justifyContent: "center",
          padding: "0 110px",
          gap: 28,
          color: "white",
          textShadow: "0 4px 40px rgba(0, 0, 0, 0.45)",
          transform: `translateY(${(1 - t) * 24}px)`,
          opacity: 0.4 + 0.6 * t,
        }}
      >
        <div
          style={{
            fontFamily: mono,
            fontWeight: 500,
            fontSize: 28,
            letterSpacing: 6,
            textTransform: "uppercase",
            opacity: 0.75,
          }}
        >
          {kicker}
        </div>
        <div
          style={{
            fontFamily: display,
            fontWeight: 700,
            fontSize: 132,
            lineHeight: 0.95,
            letterSpacing: -4,
            maxWidth: 1500,
          }}
        >
          {title}
        </div>
        {code ? (
          <div
            style={{
              alignSelf: "flex-start",
              fontFamily: mono,
              fontSize: 30,
              padding: "14px 22px",
              borderRadius: 12,
              background: "rgba(5, 6, 15, 0.55)",
              border: "1px solid rgba(255, 255, 255, 0.18)",
            }}
          >
            {code}
          </div>
        ) : null}
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// Dark bases with one accent each: ink blue and amber, plum and coral, deep teal and mint…
const slides: SlideProps[] = [
  {
    kicker: "gl-transitions",
    title: "Now in Remotion",
    palette: { base: [8, 10, 24], mid: [24, 48, 92], accent: [255, 176, 72] },
    seed: 5,
  },
  {
    kicker: "next: Cube",
    title: `${transitions.length} GLSL transitions`,
    palette: { base: [16, 6, 22], mid: [74, 28, 76], accent: [255, 120, 104] },
    seed: 3.1,
  },
  {
    kicker: "next: LumaWipe",
    title: "One line each",
    code: 'glTransition({ name: "Cube" })',
    palette: { base: [4, 18, 20], mid: [14, 70, 72], accent: [150, 255, 210] },
    seed: 7.4,
  },
  {
    kicker: "next: Dreamy",
    title: "Between any React scenes",
    palette: { base: [20, 12, 6], mid: [86, 46, 18], accent: [255, 214, 140] },
    seed: 11.9,
  },
  {
    kicker: "open source · MIT",
    title: "gl-transitions.com",
    code: "npm i @gl-transitions/remotion",
    palette: { base: [10, 8, 26], mid: [44, 34, 110], accent: [140, 220, 255] },
    seed: 17.3,
  },
];

// The composition duration (timing.ts) counts the slides.
if (slides.length !== SHOWCASE_SLIDES) throw new Error(`timing.ts: SHOWCASE_SLIDES should be ${slides.length}`);

const presentations = [
  glTransition({ name: "CrossWarp" }),
  glTransition({ name: "Cube", params: { persp: 0.7 } }),
  glTransition({ name: "LumaWipe", textures: { luma: staticFile("spiral.png") } }),
  glTransition({ name: "Dreamy" }),
];

const Showcase = () => (
  <TransitionSeries>
    {slides.flatMap((slide, i) => [
      <TransitionSeries.Sequence key={`slide-${i}`} durationInFrames={SHOWCASE_SCENE}>
        <Slide {...slide} />
      </TransitionSeries.Sequence>,
      ...(i < presentations.length
        ? [
            <TransitionSeries.Transition
              key={`transition-${i}`}
              presentation={presentations[i]}
              timing={linearTiming({ durationInFrames: SHOWCASE_TRANSITION })}
            />,
          ]
        : []),
    ])}
  </TransitionSeries>
);

export default Showcase;
