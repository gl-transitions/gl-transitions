#!/usr/bin/env node
// Measures what a 1080p frame of each transition costs the GPU, in ms, with an installed Chrome.
// Usage: pnpm run bench [--transition <name or file>]... [--json <file>] [--software]
//
// Without a transition, measures the whole collection (several minutes). Each transition is drawn
// at 5 progress values; its cost is its worst frame, also given relative to Fade, measured in the
// same run. Worst first.
//
// --json <file>   also writes the measures
// --software      draws small frames on the CPU instead, with headless gl on Mesa's llvmpipe (Linux
//                 only, with xvfb-run): the relative costs rank the transitions like a GPU does, on a
//                 machine without one (the PR preview)
// --size <WxH>    size of the frames
// --timeout <s>   stops there, with what was measured
// CHROME_PATH     the Chrome or Chromium to run, when it is not found
//
// Exit code 1 only when nothing could be measured: a high cost is not an error.

import { spawn } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { parseArgs } from "node:util";
import { parseTransition } from "../catalog/parse-transition.mjs";
import { WIDTH, HEIGHT, PROGRESS, fromImage, toImage, extraImage } from "../rendering/reference-images.mjs";
import { createFrameTimer, rendererName } from "./frame-timer.mjs";
import { LIMITS, REFERENCE, attachReferences, formatTable, rankCosts } from "./frame-cost.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..");
const TRANSITIONS = path.join(ROOT, "transitions");
const IMAGES = path.join(ROOT, "scripts", "rendering", "sample-images");
const SIZES = { gpu: "1920x1080", software: "320x180" };

function usage(message) {
  console.error(message);
  console.error("Usage: pnpm run bench [--transition <name or file>]... [--json <file>] [--software]");
  process.exit(1);
}

let options;
try {
  options = parseArgs({
    allowPositionals: true,
    options: {
      transition: { type: "string", short: "t", multiple: true, default: [] },
      json: { type: "string" },
      software: { type: "boolean", default: false },
      size: { type: "string" },
      timeout: { type: "string", default: "1800" },
    },
  });
} catch (e) {
  usage(e.message);
}
const { values, positionals } = options;
const renderer = values.software ? "software" : "gpu";
const size = (values.size ?? SIZES[renderer]).match(/^([1-9]\d*)x([1-9]\d*)$/);
if (!size) usage("Invalid --size");
const [width, height] = size.slice(1).map(Number);
const timeout = Number(values.timeout);
if (!(timeout > 0)) usage("Invalid --timeout");

function readTransition(file) {
  const { transition } = parseTransition(fs.readFileSync(file, "utf8"), path.basename(file));
  const { name, glsl, paramsTypes, defaultParams, textures } = transition;
  return { name, glsl, paramsTypes, defaultParams, textures };
}

const asked = [...values.transition, ...positionals].map((t) =>
  t.endsWith(".glsl") ? path.resolve(t) : path.join(TRANSITIONS, `${t}.glsl`),
);
const missing = asked.find((file) => !fs.existsSync(file));
if (missing) usage(`No such transition: ${missing}`);
const files = asked.length
  ? asked
  : fs
      .readdirSync(TRANSITIONS)
      .filter((f) => f.endsWith(".glsl"))
      .sort()
      .map((f) => path.join(TRANSITIONS, f));
const job = {
  width,
  height,
  progress: PROGRESS,
  timeout,
  reference: readTransition(path.join(TRANSITIONS, `${REFERENCE}.glsl`)),
  transitions: files.map(readTransition),
};

function findChrome() {
  const { CHROME_PATH, HOME = "", PATH = "", PROGRAMFILES = "", LOCALAPPDATA = "" } = process.env;
  if (CHROME_PATH) return CHROME_PATH;
  let candidates;
  if (process.platform === "darwin") {
    candidates = ["", HOME].flatMap((home) =>
      ["Google Chrome", "Chromium"].map((app) => `${home}/Applications/${app}.app/Contents/MacOS/${app}`),
    );
  } else if (process.platform === "win32") {
    candidates = [PROGRAMFILES, LOCALAPPDATA].map((dir) => path.join(dir, "Google/Chrome/Application/chrome.exe"));
  } else {
    const names = ["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"];
    candidates = PATH.split(path.delimiter).flatMap((dir) => names.map((name) => path.join(dir, name)));
  }
  return candidates.find((file) => fs.existsSync(file));
}

async function measureHeadless() {
  const measured = { renderer: "none", results: [], failure: null };
  if (process.platform !== "linux") return { ...measured, failure: "--software needs Linux, with Mesa" };
  process.env.LIBGL_ALWAYS_SOFTWARE = "1"; // llvmpipe even with a GPU: headless gl doesn't tell which
  const { default: createGL } = await import("gl");
  const gl = createGL(width, height, {});
  if (!gl) return { ...measured, failure: "Failed to create GL context" };
  measured.renderer = rendererName(gl);
  console.error(`${measured.renderer}, ${width}x${height}`);
  const images = [fromImage, toImage, extraImage].map((data) => ({ width: WIDTH, height: HEIGHT, data }));
  const measureAll = createFrameTimer(gl, { width, height, progress: PROGRESS, images });
  try {
    await measureAll(job.reference, job.transitions, timeout, (result) => measured.results.push(result));
  } catch (e) {
    measured.failure = String(e.message || e).trim();
  }
  return measured;
}

// Serves the page and collects what it posts, until it is done, Chrome exits or the time is up.
async function measureInChrome(chrome) {
  const measured = { renderer: "unknown", results: [], failure: null };
  let stop;
  let ended = false;
  const stopped = new Promise((resolve) => {
    stop = (failure = null) => {
      if (!ended) measured.failure = failure;
      ended = true;
      resolve();
    };
  });
  const received = {
    renderer: (name) => {
      measured.renderer = name;
      console.error(`${name}, ${width}x${height}`);
      if (/swiftshader|llvmpipe|software|basic render/i.test(name))
        stop(`Chrome draws on the CPU, not on a GPU: ${name}`);
    },
    result: (result) => {
      measured.results.push(result);
      const count = measured.results.filter(({ reference }) => !reference).length;
      if (!result.reference && count % 20 === 0) console.error(`${count}/${files.length}`);
    },
    failure: (message) => stop(message),
    done: () => stop(),
  };
  const readModule = (name) => fs.readFileSync(path.join(import.meta.dirname, name));
  const readImage = (name) => fs.readFileSync(path.join(IMAGES, name));
  const served = new Map([
    ["", ["text/html", `<!doctype html><script type="module" src="benchmark-page.mjs"></script>`]],
    ["benchmark-page.mjs", ["text/javascript", readModule("benchmark-page.mjs")]],
    ["frame-timer.mjs", ["text/javascript", readModule("frame-timer.mjs")]],
    ["job.json", ["application/json", JSON.stringify(job)]],
    ["1.jpg", ["image/jpeg", readImage("1.jpg")]],
    ["2.jpg", ["image/jpeg", readImage("2.jpg")]],
    ["3.jpg", ["image/jpeg", readImage("3.jpg")]],
  ]);
  const server = http.createServer((request, response) => {
    const name = request.url.slice(1);
    if (request.method === "POST") {
      let body = "";
      request.setEncoding("utf8");
      request.on("data", (chunk) => (body += chunk));
      request.on("end", () => {
        try {
          if (Object.hasOwn(received, name)) received[name](JSON.parse(body));
        } catch (e) {
          stop(`unexpected message from the page: ${e.message}`);
        }
        response.end();
      });
      return;
    }
    if (!served.has(name)) {
      response.writeHead(404).end();
      return;
    }
    const [type, body] = served.get(name);
    // Cross-origin isolation gives performance.now() its full resolution.
    response.setHeader("Cross-Origin-Opener-Policy", "same-origin");
    response.setHeader("Cross-Origin-Embedder-Policy", "require-corp");
    response.setHeader("Content-Type", type).end(body);
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));

  const profile = fs.mkdtempSync(path.join(os.tmpdir(), "gl-transitions-bench-"));
  const angle = process.platform === "darwin" ? "metal" : null;
  const child = spawn(
    chrome,
    [
      "--headless=new",
      "--no-first-run",
      "--no-default-browser-check",
      "--disable-background-networking",
      "--disable-gpu-watchdog",
      "--ignore-gpu-blocklist",
      ...(angle ? [`--use-angle=${angle}`] : []),
      `--user-data-dir=${profile}`,
      `http://127.0.0.1:${server.address().port}/`,
    ],
    { stdio: "ignore" },
  );
  const exited = new Promise((resolve) => child.once("close", resolve));
  child.once("error", (e) => stop(`Chrome did not start: ${e.message}`));
  exited.then(() => stop("Chrome stopped"));
  const timer = setTimeout(() => stop(`stopped after ${timeout} s`), (timeout + 5) * 1000);
  process.once("SIGINT", () => stop("interrupted"));
  process.once("SIGTERM", () => stop("interrupted"));

  await stopped;
  clearTimeout(timer);
  if (child.pid && child.exitCode === null) {
    child.kill("SIGKILL");
    await exited;
  }
  server.closeAllConnections();
  server.close();
  try {
    fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  } catch {} // Chrome's other processes may still write there
  return measured;
}

async function measureOnGpu() {
  const chrome = findChrome();
  if (!chrome) usage("Chrome was not found: install it, or set CHROME_PATH to a Chrome or Chromium executable");
  return measureInChrome(chrome);
}

const measured = await (values.software ? measureHeadless() : measureOnGpu());
const { failure } = measured;
const results = attachReferences(measured.results, renderer);
if (failure) console.error(failure);
const done = new Set(results.map(({ name }) => name));
const skipped = job.transitions
  .filter(({ name }) => !done.has(name))
  .map(({ name }) => ({ name, error: failure ?? "the benchmark stopped before" }));
const costs = rankCosts([...results, ...skipped], LIMITS[renderer]);
const fade = Math.min(...results.filter((result) => result.ms).map((result) => result.fade));

console.log(formatTable(costs, PROGRESS));
if (fade < Infinity) console.log(`\n${REFERENCE}: ${fade.toFixed(3)} ms`);
if (values.json) {
  const report = {
    renderer: measured.renderer,
    software: values.software,
    width,
    height,
    progress: PROGRESS,
    fade: fade < Infinity ? fade : null,
    transitions: costs,
  };
  fs.writeFileSync(values.json, JSON.stringify(report, null, 2) + "\n");
}
if (fade === Infinity) {
  console.error("Nothing was measured");
  process.exit(1);
}
