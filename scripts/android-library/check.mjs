#!/usr/bin/env node
// Renders every transition with the Android library on the connected device or emulator (Android 13+,
// android/gl-transitions/src/androidTest/.../CheckTest.kt: the AGSL shaders drawn by TransitionShader)
// and compares it with its GLSL reference render, as the other targets do
// (scripts/targets/compare-renders.mjs).
// Usage: node scripts/android-library/check.mjs <references dir> [--renders <dir>] [--report <file.json>]
// Fails when a transition differs from its reference (hash noise is only reported) or does not render.

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { PNG } from "pngjs";
import { WIDTH, HEIGHT, PROGRESS, fromImage, toImage, extraImage } from "../rendering/reference-images.mjs";
import { checkRender, usesHashNoise, writeReport } from "../targets/compare-renders.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..");
const LIBRARY = path.join(ROOT, "android/gl-transitions");
const args = process.argv.slice(2);
const refsDir = args.find((a, i) => !a.startsWith("--") && !args[i - 1]?.startsWith("--"));
const option = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : undefined);
const rendersDir = path.resolve(option("--renders") ?? fs.mkdtempSync(path.join(os.tmpdir(), "android-renders-")));
const reportFile = option("--report");
if (!refsDir) {
  console.error(
    "Usage: node scripts/android-library/check.mjs <references dir> [--renders <dir>] [--report <file.json>]",
  );
  process.exit(2);
}
if (reportFile) fs.mkdirSync(path.dirname(reportFile), { recursive: true });

// The test's assets (see android/gl-transitions/build.gradle.kts).
const images = path.join(LIBRARY, "build/check-images/check");
fs.mkdirSync(images, { recursive: true });
for (const [name, data] of Object.entries({ from: fromImage, to: toImage, extra: extraImage })) {
  const png = new PNG({ width: WIDTH, height: HEIGHT });
  png.data = Buffer.from(data);
  fs.writeFileSync(path.join(images, `${name}.png`), PNG.sync.write(png));
}
fs.rmSync(path.join(LIBRARY, "build/outputs/connected_android_test_additional_output"), {
  recursive: true,
  force: true,
});
execFileSync(
  "./gradlew",
  [
    ":gl-transitions:connectedDebugAndroidTest",
    "-Pandroid.testInstrumentationRunnerArguments.class=com.gltransitions.CheckTest",
    `-Pandroid.testInstrumentationRunnerArguments.checkProgress=${PROGRESS.join(",")}`,
    "--console=plain",
  ],
  { cwd: path.join(ROOT, "android"), stdio: "inherit" },
);
// CheckTest writes with TestStorage, which Gradle copies to <outputs>/<device>/check/.
const outputs = path.join(LIBRARY, "build/outputs/connected_android_test_additional_output/debugAndroidTest/connected");
const devices = fs.existsSync(outputs) ? fs.readdirSync(outputs) : [];
if (devices.length !== 1) {
  console.error(`Expected the renders of one device in ${outputs}, found ${devices.length}`);
  process.exit(1);
}
fs.rmSync(rendersDir, { recursive: true, force: true });
fs.cpSync(path.join(outputs, devices[0], "check"), rendersDir, { recursive: true });

// The transitions of the library (the ones with an SkSL source).
const names = fs
  .readdirSync(path.join(LIBRARY, "src/main/resources/com/gltransitions/sksl"))
  .map((f) => f.slice(0, -".sksl".length))
  .sort();
const results = names.map((name) => {
  const hashNoise = usesHashNoise(fs.readFileSync(path.join(ROOT, "transitions", `${name}.glsl`), "utf8"));
  const noise = hashNoise ? { hashNoise } : {};
  const error = path.join(rendersDir, `${name}.error`);
  if (fs.existsSync(error)) return { name, ...noise, status: "compile-error", error: fs.readFileSync(error, "utf8") };
  const file = path.join(rendersDir, `${name}.png`);
  if (!fs.existsSync(file)) return { name, ...noise, status: "compile-error", error: "not rendered" };
  const png = PNG.sync.read(fs.readFileSync(file));
  if (png.width !== WIDTH * PROGRESS.length || png.height !== HEIGHT) {
    return { name, ...noise, status: "differs", error: `rendered ${png.width}x${png.height}` };
  }
  return { name, ...noise, ...checkRender(png.data, { name, hashNoise, refsDir }) };
});

writeReport("android", "Android (AGSL)", results, reportFile, ["match"]);
const failed = results.filter(
  (r) => (r.status === "differs" && (!r.hashNoise || r.error)) || r.status === "compile-error",
);
if (failed.length) {
  console.error(`Differ from their GLSL reference or don't compile: ${failed.map((r) => r.name).join(", ")}`);
  process.exit(1);
}
const missing = results.filter((r) => r.status === "no-reference").map((r) => r.name);
if (missing.length || results.length === 0) {
  console.error(`No reference render for: ${missing.join(", ") || "any transition"}`);
  process.exit(1);
}
