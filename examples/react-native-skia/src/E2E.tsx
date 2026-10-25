import { useEffect, useState, type ReactElement } from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";
import {
  AlphaType,
  Canvas,
  ColorType,
  ImageShader,
  Rect,
  drawAsImage,
  useCanvasRef,
  type SkImage,
} from "@shopify/react-native-skia";
import { useSharedValue } from "react-native-reanimated";
import { Transition } from "@gl-transitions/react-native-skia";
import transitions from "gl-transitions";
import sksl from "gl-transitions/sksl/index.js";
import { SIZE, fromImage, texturesFor, toImage } from "./images";

// Runs on the device, through the native Skia build, what the spec validation checks with
// WebGL: for every transition with an SkSL version (the SkSL build reports the others), progress 0 shows `from` and 1 shows `to`; a solid color at
// 0.5 is only a warning, as there (CircleIris is a solid color halfway). Then the Reanimated path:
// an animated progress and an animated image still loading, then another transition with
// other uniforms on the same <Transition>, compared halfway with a static render of it. Each result is logged with the
// GLT_E2E prefix (logcat: ReactNativeJS), the last line is "GLT_E2E done: <passed>/<total> passed".

const LOG = "GLT_E2E";
// Like build-sksl.mjs: a pixel differs when a channel moves by more than 16, a frame
// matches when at most 2% of its pixels differ (sampling and precision differ per GPU).
const PIXEL_TOLERANCE = 16;
const MATCH_RATIO = 0.02;

type Result = { name: string; error?: string; warning?: string };

function readRGBA(image: SkImage): Uint8Array {
  const width = image.width();
  const height = image.height();
  const info = { width, height, colorType: ColorType.RGBA_8888, alphaType: AlphaType.Premul };
  const pixels = image.readPixels(0, 0, info);
  if (!pixels) throw new Error("readPixels failed");
  return pixels as Uint8Array;
}

function differing(actual: Uint8Array, expected: Uint8Array): number {
  let bad = 0;
  for (let i = 0; i < actual.length; i += 4) {
    for (let c = 0; c < 4; c++) {
      if (Math.abs(actual[i + c] - expected[i + c]) > PIXEL_TOLERANCE) {
        bad++;
        break;
      }
    }
  }
  return bad / (actual.length / 4);
}

function isSolid(pixels: Uint8Array): boolean {
  for (let i = 4; i < pixels.length; i += 4) {
    for (let c = 0; c < 3; c++) if (Math.abs(pixels[i + c] - pixels[c]) > 2) return false;
  }
  return true;
}

async function draw(element: ReactElement, width = SIZE, height = SIZE): Promise<Uint8Array> {
  const image = await drawAsImage(element, { width, height });
  if (!image) throw new Error("drawAsImage returned null");
  return readRGBA(image);
}

// An image drawn as <Transition> draws its images (fit "fill"), to compare with.
function drawImage(image: SkImage, width = SIZE, height = SIZE) {
  const rect = { x: 0, y: 0, width, height };
  return draw(
    <Rect {...rect}>
      <ImageShader image={image} fit="fill" rect={rect} tx="clamp" ty="clamp" />
    </Rect>,
    width,
    height,
  );
}

function expectMatch(label: string, actual: Uint8Array, expected: Uint8Array): string | undefined {
  const ratio = differing(actual, expected);
  return ratio > MATCH_RATIO ? `${label}: ${(ratio * 100).toFixed(1)}% of pixels differ` : undefined;
}

async function checkTransition(name: string, textures: readonly string[], from: Uint8Array, to: Uint8Array) {
  const render = (progress: number) =>
    draw(
      <Transition
        name={name}
        from={fromImage}
        to={toImage}
        textures={texturesFor(textures)}
        progress={progress}
        width={SIZE}
        height={SIZE}
        fit="fill"
      />,
    );
  const errors = [
    expectMatch("progress 0 is not `from`", await render(0), from),
    expectMatch("progress 1 is not `to`", await render(1), to),
  ].filter(Boolean);
  return {
    error: errors.join("; ") || undefined,
    warning: isSolid(await render(0.5)) ? "progress 0.5 is a solid color" : undefined,
  };
}

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// Drawn on screen: progress and `from` are shared values, `from` starts null (still loading).
function AnimatedCheck({ onDone }: { onDone: (result: Result) => void }) {
  const ref = useCanvasRef();
  const [name, setName] = useState("Fade");
  const progress = useSharedValue(0);
  const from = useSharedValue<SkImage | null>(null);
  useEffect(() => {
    (async () => {
      const result: Result = { name: "animated progress and image (Reanimated)" };
      try {
        await wait(500); // drawn while `from` is null: must not throw
        from.value = fromImage;
        await wait(500);
        const atStart = await ref.current!.makeImageSnapshotAsync();
        const { width, height } = { width: atStart.width(), height: atStart.height() };
        progress.value = 1;
        await wait(500);
        const atEnd = await ref.current!.makeImageSnapshotAsync();
        // FadeColor has a `color` uniform that Fade has not: the new shader must not get Fade's uniforms.
        setName("FadeColor");
        await wait(500);
        progress.value = 0.5;
        await wait(500);
        const switched = await ref.current!.makeImageSnapshotAsync();
        const fadecolor = await draw(
          <Transition
            name="FadeColor"
            from={fromImage}
            to={toImage}
            progress={0.5}
            width={width}
            height={height}
            fit="fill"
          />,
          width,
          height,
        );
        const to = await drawImage(toImage, width, height);
        result.error =
          [
            expectMatch("progress 0 is not `from`", readRGBA(atStart), await drawImage(fromImage, width, height)),
            expectMatch("progress 1 is not `to`", readRGBA(atEnd), to),
            expectMatch(
              "after changing the transition, progress 0.5 is not FadeColor's",
              readRGBA(switched),
              fadecolor,
            ),
          ]
            .filter(Boolean)
            .join("; ") || undefined;
      } catch (e) {
        result.error = String(e);
      }
      onDone(result);
    })();
    // Once: the shared values and the ref are stable, and onDone is only called once.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return (
    <Canvas ref={ref} style={styles.canvas}>
      <Transition name={name} from={from} to={toImage} progress={progress} width={128} height={128} fit="fill" />
    </Canvas>
  );
}

export function E2E() {
  const [results, setResults] = useState<Result[]>([]);
  const [staticDone, setStaticDone] = useState(false);
  const [done, setDone] = useState(false);

  const report = (result: Result) => {
    const status = result.error ? "FAIL" : result.warning ? "warn" : "ok";
    const detail = result.error ?? result.warning;
    console.log(`${LOG} ${status} ${result.name}${detail ? `: ${detail}` : ""}`);
    setResults((r) => [...r, result]);
  };

  useEffect(() => {
    (async () => {
      try {
        const from = await drawImage(fromImage);
        const to = await drawImage(toImage);
        for (const t of transitions.filter((t) => t.name in sksl)) {
          try {
            report({ name: t.name, ...(await checkTransition(t.name, t.textures, from, to)) });
          } catch (e) {
            report({ name: t.name, error: String(e) });
          }
        }
      } catch (e) {
        report({ name: "reference images", error: String(e) });
      }
      setStaticDone(true);
    })();
  }, []);

  useEffect(() => {
    if (!done) return;
    const passed = results.filter((r) => !r.error).length;
    console.log(`${LOG} done: ${passed}/${results.length} passed`);
  }, [done]);

  const failed = results.filter((r) => r.error);
  return (
    <View style={styles.screen}>
      <Text style={styles.title}>
        {done ? "Done" : "Running"}: {results.length - failed.length}/{results.length} passed
      </Text>
      {staticDone && !done && (
        <AnimatedCheck
          onDone={(result) => {
            report(result);
            setDone(true);
          }}
        />
      )}
      <ScrollView>
        {failed.map((r) => (
          <Text key={r.name} style={styles.failure}>
            {r.name}: {r.error}
          </Text>
        ))}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: "#111", paddingTop: 48, paddingHorizontal: 16 },
  title: { color: "#fff", fontSize: 20, fontWeight: "600", marginBottom: 12 },
  canvas: { width: 128, height: 128 },
  failure: { color: "#f88", marginBottom: 6 },
});
