// Stands in for "@shopify/react-native-skia" in tests: its headless build, which runs
// the same components and Skia API on CanvasKit in Node (the native build needs a device).

import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
// The CanvasKit build React Native Skia depends on (it can differ from the repository's).
const requireFromSkia = createRequire(require.resolve("@shopify/react-native-skia/package.json"));
globalThis.CanvasKit = await requireFromSkia("canvaskit-wasm/bin/full/canvaskit")();

const headless = require("@shopify/react-native-skia/lib/commonjs/headless");

export const { Skia } = headless.getSkiaExports();
export const { AlphaType, ColorType, Group, ImageShader, Rect, Shader, drawOffscreen, makeOffscreenSurface } = headless;
