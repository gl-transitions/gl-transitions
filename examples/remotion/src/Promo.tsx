import type { ReactNode } from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  interpolate,
  Series,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { loadFont as loadDisplay } from "@remotion/google-fonts/BricolageGrotesque";
import { loadFont as loadMono } from "@remotion/google-fonts/JetBrainsMono";
import { glTransition } from "@gl-transitions/remotion";
import transitions from "gl-transitions";
import { Backdrop, type Palette } from "./Backdrop.tsx";
import {
  PROMO_GRID,
  PROMO_GRID_NAMES,
  PROMO_HOLD,
  PROMO_INTRO,
  PROMO_LAST_HOLD,
  PROMO_ORDER,
  PROMO_SERIES,
  PROMO_TRANSITION,
} from "./promo-timing.ts";

// A promotional video for social media of a set of transitions (PROMO_ORDER in promo-timing.ts):
// an intro, each transition in turn between photo cards with its name, a grid, and an outro.
// Vertical (1080x1920) and square (1080x1080) cuts: see .claude/skills/promo-video.

const { fontFamily: display } = loadDisplay("normal", { weights: ["700", "800"], subsets: ["latin"] });
const { fontFamily: mono } = loadMono("normal", { weights: ["400", "500", "700"], subsets: ["latin"] });

const ACCENT = "#ffb648";
const EASE = Easing.bezier(0.55, 0, 0.45, 1);

const useLayout = () => {
  const { width, height } = useVideoConfig();
  const vertical = height > width * 1.3;
  return vertical
    ? { vertical, card: { x: 60, y: 430, w: 960, h: 750 }, labelTop: 1250, headerTop: 290, scale: 1 }
    : { vertical, card: { x: 170, y: 150, w: 740, h: 578 }, labelTop: 770, headerTop: 56, scale: 0.8 };
};

// ---- Scenes -----------------------------------------------------------------------------

const photo = (i: number) => staticFile(`promo/fg${(i % 3) + 1}.jpg`);
const blurred = (i: number) => staticFile(`promo/bg${(i % 3) + 1}.jpg`);

// Ken Burns directions, so consecutive shots of the same photo don't look the same.
const MOVES = [
  { from: [1.02, 0, 0], to: [1.14, -2, -1] },
  { from: [1.16, 2, 1], to: [1.04, 0, 0] },
  { from: [1.06, -2, 1], to: [1.14, 2, -1] },
  { from: [1.14, 0, 2], to: [1.04, 0, -1] },
] as const;

const PhotoScene = ({ index }: { index: number }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const { card } = useLayout();
  const move = MOVES[index % MOVES.length];
  const t = frame / Math.max(1, durationInFrames);
  const k = (a: number, b: number) => a + (b - a) * t;
  const s = k(move.from[0], move.to[0]);
  const x = k(move.from[1], move.to[1]);
  const y = k(move.from[2], move.to[2]);
  return (
    <AbsoluteFill style={{ background: "#07080c" }}>
      <Img src={blurred(index)} style={{ position: "absolute", width: "100%", height: "100%", objectFit: "cover" }} />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(180deg, rgba(5,6,10,0.55) 0%, rgba(5,6,10,0.15) 35%, rgba(5,6,10,0.35) 60%, rgba(5,6,10,0.85) 100%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: card.x,
          top: card.y,
          width: card.w,
          height: card.h,
          borderRadius: 40,
          overflow: "hidden",
          boxShadow: "0 40px 90px rgba(0,0,0,0.55), 0 0 0 2px rgba(255,255,255,0.14)",
        }}
      >
        <Img
          src={photo(index)}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            transform: `scale(${s}) translate(${x}%, ${y}%)`,
          }}
        />
      </div>
    </AbsoluteFill>
  );
};

const rise = (frame: number, delay: number, fps: number) =>
  spring({ frame: frame - delay, fps, config: { damping: 200 }, durationInFrames: 18 });

const INTRO_PALETTE: Palette = { base: [7, 8, 18], mid: [30, 40, 92], accent: [255, 170, 70] };
const OUTRO_PALETTE: Palette = { base: [9, 7, 22], mid: [52, 30, 98], accent: [130, 210, 255] };
const GRID_PALETTE: Palette = { base: [5, 10, 14], mid: [16, 52, 64], accent: [140, 255, 210] };

const Intro = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { vertical, scale } = useLayout();
  const a = rise(frame, -6, fps);
  const b = rise(frame, -3, fps);
  const c = rise(frame, 4, fps);
  const count = Math.round(
    interpolate(frame, [0, 24], [1, PROMO_ORDER.length], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: Easing.out(Easing.cubic),
    }),
  );
  return (
    <AbsoluteFill style={{ background: "#05060a" }}>
      <Backdrop palette={INTRO_PALETTE} seed={4.2} />
      <AbsoluteFill
        style={{
          justifyContent: "center",
          padding: vertical ? "0 80px" : "0 110px",
          color: "white",
          textShadow: "0 6px 40px rgba(0,0,0,0.45)",
        }}
      >
        <div
          style={{
            fontFamily: mono,
            fontWeight: 500,
            fontSize: 40 * scale,
            letterSpacing: 4,
            opacity: a,
            transform: `translateY(${(1 - a) * 30}px)`,
            display: "flex",
            alignItems: "center",
            gap: 18,
          }}
        >
          <span style={{ width: 16 * scale, height: 16 * scale, borderRadius: 99, background: ACCENT }} />
          gl-transitions
        </div>
        <div
          style={{
            fontFamily: display,
            fontWeight: 800,
            fontSize: 520 * scale,
            lineHeight: 0.86,
            letterSpacing: -24 * scale,
            marginTop: 30 * scale,
            marginLeft: -12,
            color: ACCENT,
            opacity: b,
            transform: `translateY(${(1 - b) * 60}px) scale(${0.92 + 0.08 * b})`,
            transformOrigin: "left center",
            fontVariantNumeric: "tabular-nums",
          }}
        >
          {count}
        </div>
        <div
          style={{
            fontFamily: display,
            fontWeight: 700,
            fontSize: 140 * scale,
            lineHeight: 0.92,
            letterSpacing: -5 * scale,
            opacity: c,
            transform: `translateY(${(1 - c) * 40}px)`,
          }}
        >
          new
          <br />
          transitions
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// ---- Lower-third label ------------------------------------------------------------------

const PERIOD = PROMO_HOLD + PROMO_TRANSITION;
const firstStart = PROMO_INTRO - PROMO_TRANSITION;

const Labels = () => {
  const frame = useCurrentFrame();
  const { labelTop, card, scale } = useLayout();
  const k = Math.min(PROMO_ORDER.length - 1, Math.floor((frame - firstStart) / PERIOD));
  if (frame < firstStart) return null;
  const local = frame - (firstStart + k * PERIOD);
  const inT = interpolate(local, [0, 9], [0, 1], { extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) });
  const progress = interpolate(local, [0, PROMO_TRANSITION], [0, 1], { extrapolateRight: "clamp", easing: EASE });
  // Fades out at the end of the series.
  const out = interpolate(frame, [PROMO_SERIES - 8, PROMO_SERIES], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const name = PROMO_ORDER[k];
  return (
    <AbsoluteFill style={{ opacity: out }}>
      <div style={{ position: "absolute", left: card.x + 4, top: labelTop, right: card.x, color: "white" }}>
        <div
          style={{
            fontFamily: mono,
            fontWeight: 500,
            fontSize: 30 * scale,
            letterSpacing: 3,
            display: "flex",
            alignItems: "center",
            gap: 16,
            opacity: 0.92,
          }}
        >
          <span
            style={{
              background: ACCENT,
              color: "#121212",
              fontWeight: 700,
              padding: "4px 12px",
              borderRadius: 8,
              letterSpacing: 2,
            }}
          >
            NEW
          </span>
          <span style={{ fontVariantNumeric: "tabular-nums" }}>
            {String(k + 1).padStart(2, "0")} / {PROMO_ORDER.length}
          </span>
        </div>
        <div style={{ overflow: "hidden", paddingBottom: 10, marginTop: 10 }}>
          <div
            style={{
              fontFamily: display,
              fontWeight: 700,
              fontSize: 112 * scale,
              lineHeight: 1.02,
              letterSpacing: -3 * scale,
              transform: `translateY(${(1 - inT) * 100}%)`,
              textShadow: "0 6px 30px rgba(0,0,0,0.5)",
            }}
          >
            {name}
          </div>
        </div>
        <div
          style={{ height: 6, borderRadius: 3, background: "rgba(255,255,255,0.18)", marginTop: 8, width: card.w - 4 }}
        >
          <div style={{ height: 6, borderRadius: 3, background: ACCENT, width: `${progress * 100}%` }} />
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Shade = () => {
  const frame = useCurrentFrame();
  const { vertical } = useLayout();
  const o = interpolate(frame, [firstStart, firstStart + 12, PROMO_SERIES - 8, PROMO_SERIES], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <AbsoluteFill
      style={{
        opacity: o,
        background: vertical
          ? "linear-gradient(180deg, rgba(4,5,9,0.5) 0%, rgba(4,5,9,0) 22%, rgba(4,5,9,0) 58%, rgba(4,5,9,0.7) 72%, rgba(4,5,9,0.7) 84%, rgba(4,5,9,0) 100%)"
          : "linear-gradient(180deg, rgba(4,5,9,0.45) 0%, rgba(4,5,9,0) 14%, rgba(4,5,9,0) 62%, rgba(4,5,9,0.7) 76%, rgba(4,5,9,0.75) 100%)",
      }}
    />
  );
};

const Header = () => {
  const frame = useCurrentFrame();
  const { headerTop, card, scale } = useLayout();
  const o = interpolate(frame, [firstStart, firstStart + 12, PROMO_SERIES - 8, PROMO_SERIES], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  return (
    <div
      style={{
        position: "absolute",
        top: headerTop,
        left: card.x + 4,
        right: card.x,
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        fontFamily: mono,
        fontWeight: 500,
        fontSize: 32 * scale,
        color: "white",
        opacity: o,
        textShadow: "0 2px 16px rgba(0,0,0,0.6)",
      }}
    >
      <span style={{ display: "flex", alignItems: "center", gap: 14 }}>
        <span style={{ width: 14, height: 14, borderRadius: 99, background: ACCENT }} />
        gl-transitions
      </span>
      <span style={{ opacity: 0.75 }}>{PROMO_ORDER.length} new</span>
    </div>
  );
};

// ---- The new transitions, one after the other --------------------------------------------------------

const timing = linearTiming({ durationInFrames: PROMO_TRANSITION, easing: EASE });

const MainSeries = () => (
  <TransitionSeries>
    <TransitionSeries.Sequence durationInFrames={PROMO_INTRO}>
      <Intro />
    </TransitionSeries.Sequence>
    {PROMO_ORDER.flatMap((name, i) => {
      const last = i === PROMO_ORDER.length - 1;
      return [
        <TransitionSeries.Transition key={`t-${name}`} presentation={glTransition({ name })} timing={timing} />,
        <TransitionSeries.Sequence
          key={`s-${name}`}
          durationInFrames={last ? PROMO_TRANSITION + PROMO_LAST_HOLD : 2 * PROMO_TRANSITION + PROMO_HOLD}
        >
          <PhotoScene index={i} />
        </TransitionSeries.Sequence>,
      ];
    })}
  </TransitionSeries>
);

// ---- Grid: nine of them at once ---------------------------------------------------------

const GRID_T = 26;

const Tile = ({ i }: { i: number }) => {
  const { durationInFrames } = useVideoConfig();
  // Staggered: each tile plays its transition once, a few frames after the previous one.
  const a = 6 + 2 * i + GRID_T;
  const b = durationInFrames + GRID_T - a;
  const t = linearTiming({ durationInFrames: GRID_T, easing: EASE });
  const Pic = ({ n }: { n: number }) => (
    <AbsoluteFill>
      <Img src={photo(n)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
    </AbsoluteFill>
  );
  return (
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={a}>
        <Pic n={i} />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={glTransition({ name: PROMO_GRID_NAMES[i] })} timing={t} />
      <TransitionSeries.Sequence durationInFrames={b}>
        <Pic n={i + 1} />
      </TransitionSeries.Sequence>
    </TransitionSeries>
  );
};

const Grid = () => {
  const frame = useCurrentFrame();
  const { fps, width } = useVideoConfig();
  const { vertical, scale } = useLayout();
  const gap = vertical ? 18 : 12;
  const size = vertical ? 284 : 204;
  const total = 3 * size + 2 * gap;
  const left = (width - total) / 2;
  const top = vertical ? 540 : 210;
  const title = rise(frame, 0, fps);
  return (
    <AbsoluteFill style={{ background: "#05060a" }}>
      <Backdrop palette={GRID_PALETTE} seed={9.1} />
      <div
        style={{
          position: "absolute",
          left,
          top: vertical ? 290 : 48,
          color: "white",
          opacity: title,
          transform: `translateY(${(1 - title) * 30}px)`,
        }}
      >
        <div style={{ fontFamily: mono, fontWeight: 500, fontSize: 32 * scale, letterSpacing: 3, opacity: 0.8 }}>
          the collection
        </div>
        <div
          style={{
            fontFamily: display,
            fontWeight: 700,
            fontSize: 100 * scale,
            letterSpacing: -3 * scale,
            lineHeight: 1,
          }}
        >
          now <span style={{ color: ACCENT }}>{transitions.length}</span> transitions
        </div>
      </div>
      {PROMO_GRID_NAMES.map((name, i) => {
        const pop = spring({
          frame: frame - i * 2,
          fps,
          config: { damping: 14, stiffness: 160 },
          durationInFrames: 20,
        });
        const col = i % 3;
        const row = Math.floor(i / 3);
        return (
          <div
            key={name}
            style={{
              position: "absolute",
              left: left + col * (size + gap),
              top: top + row * (size + gap + (vertical ? 44 : 32)),
              width: size,
              transform: `scale(${0.6 + 0.4 * pop})`,
              opacity: Math.min(1, pop * 1.5),
            }}
          >
            <div
              style={{
                position: "relative",
                width: size,
                height: size,
                borderRadius: 24,
                overflow: "hidden",
                boxShadow: "0 20px 50px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.15)",
              }}
            >
              <Tile i={i} />
            </div>
            <div
              style={{
                fontFamily: mono,
                fontWeight: 500,
                fontSize: 26 * scale,
                color: "white",
                marginTop: 10,
                opacity: 0.9,
              }}
            >
              {name}
            </div>
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

// ---- Outro ------------------------------------------------------------------------------

const TARGETS = ["WebGL", "WebGPU", "React Native Skia", "Remotion", "Metal · SwiftUI", "Android", "Rust"];

const Outro = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { vertical, scale } = useLayout();
  const a = rise(frame, 0, fps);
  const b = rise(frame, 6, fps);
  const c = rise(frame, 30, fps);
  return (
    <AbsoluteFill style={{ background: "#05060a" }}>
      <Backdrop palette={OUTRO_PALETTE} seed={17.3} />
      <AbsoluteFill
        style={{
          justifyContent: "center",
          padding: vertical ? "0 70px" : "0 90px",
          color: "white",
          gap: 26 * scale,
          textShadow: "0 6px 40px rgba(0,0,0,0.45)",
        }}
      >
        <div
          style={{
            fontFamily: mono,
            fontWeight: 500,
            fontSize: 36 * scale,
            letterSpacing: 4,
            opacity: a * 0.85,
            transform: `translateY(${(1 - a) * 30}px)`,
          }}
        >
          open source · MIT
        </div>
        <div
          style={{
            fontFamily: display,
            fontWeight: 800,
            fontSize: (vertical ? 112 : 124) * scale,
            lineHeight: 0.95,
            whiteSpace: "nowrap",
            letterSpacing: -4 * scale,
            opacity: b,
            transform: `translateY(${(1 - b) * 40}px)`,
          }}
        >
          gl-transitions
          <span style={{ color: ACCENT }}>.com</span>
        </div>
        <div
          style={{
            fontFamily: mono,
            fontSize: 30 * scale,
            opacity: 0.75 * rise(frame, 14, fps),
            marginTop: 20 * scale,
          }}
        >
          runs on
        </div>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 16 * scale, maxWidth: vertical ? 960 : 900 }}>
          {TARGETS.map((target, i) => {
            const p = spring({
              frame: frame - 16 - i * 2,
              fps,
              config: { damping: 14, stiffness: 170 },
              durationInFrames: 20,
            });
            return (
              <div
                key={target}
                style={{
                  fontFamily: display,
                  fontWeight: 700,
                  fontSize: 52 * scale,
                  padding: `${10 * scale}px ${26 * scale}px`,
                  borderRadius: 999,
                  background: "rgba(255,255,255,0.1)",
                  border: "2px solid rgba(255,255,255,0.22)",
                  opacity: Math.min(1, p * 1.5),
                  transform: `scale(${0.7 + 0.3 * p})`,
                }}
              >
                {target}
              </div>
            );
          })}
        </div>
        <div
          style={{
            alignSelf: "flex-start",
            marginTop: 26 * scale,
            fontFamily: mono,
            fontWeight: 500,
            fontSize: 34 * scale,
            padding: `${16 * scale}px ${26 * scale}px`,
            borderRadius: 14,
            background: "rgba(5, 6, 15, 0.6)",
            border: "1px solid rgba(255, 255, 255, 0.2)",
            opacity: c,
            transform: `translateY(${(1 - c) * 20}px)`,
          }}
        >
          <span style={{ color: ACCENT }}>$</span> npm i gl-transitions
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// ---- All together -----------------------------------------------------------------------

const Layer = ({ children }: { children: ReactNode }) => <AbsoluteFill>{children}</AbsoluteFill>;

const Promo = () => (
  <AbsoluteFill style={{ background: "#05060a" }}>
    <Series>
      <Series.Sequence durationInFrames={PROMO_SERIES}>
        <Layer>
          <MainSeries />
        </Layer>
        <Shade />
        <Header />
        <Labels />
      </Series.Sequence>
      <Series.Sequence durationInFrames={PROMO_GRID}>
        <Grid />
      </Series.Sequence>
      <Series.Sequence durationInFrames={10_000}>
        <Outro />
      </Series.Sequence>
    </Series>
  </AbsoluteFill>
);

export default Promo;
