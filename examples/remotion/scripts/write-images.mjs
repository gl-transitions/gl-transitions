#!/usr/bin/env node
// Writes the images the compositions use into public/: the procedural images of the GLSL
// reference renders (scripts/rendering/reference-images.mjs), so the check compares the same pixels.

import fs from "node:fs";
import path from "node:path";
import { PNG } from "pngjs";
import { WIDTH, HEIGHT, fromImage, toImage, extraImage } from "../../../scripts/rendering/reference-images.mjs";

const out = path.join(import.meta.dirname, "..", "public");
fs.mkdirSync(out, { recursive: true });
for (const [name, data] of Object.entries({ from: fromImage, to: toImage, extra: extraImage })) {
  const png = new PNG({ width: WIDTH, height: HEIGHT });
  png.data = Buffer.from(data);
  fs.writeFileSync(path.join(out, `${name}.png`), PNG.sync.write(png));
}

// The luma texture of the Showcase: a soft spiral, so "luma" sweeps around the center.
const W = 640;
const H = 360;
const spiral = new PNG({ width: W, height: H });
for (let y = 0; y < H; y++) {
  for (let x = 0; x < W; x++) {
    const dx = (x - W / 2) / H;
    const dy = (y - H / 2) / H;
    const v = (Math.atan2(dy, dx) / (2 * Math.PI) + 0.5 + Math.hypot(dx, dy) * 1.2) % 1;
    const i = (y * W + x) * 4;
    spiral.data[i] = spiral.data[i + 1] = spiral.data[i + 2] = Math.round(v * 255);
    spiral.data[i + 3] = 255;
  }
}
fs.writeFileSync(path.join(out, "spiral.png"), PNG.sync.write(spiral));
