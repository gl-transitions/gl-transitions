#!/usr/bin/env node
// Writes the photos of the Promo into public/promo/ from the sample images of the repository
// (scripts/rendering/sample-images): fgN.jpg, sharp for the photo card, and bgN.jpg, blurred
// and darkened to fill the frame behind it.
// Requires: ffmpeg

import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

const samples = path.join(import.meta.dirname, "..", "..", "..", "scripts", "rendering", "sample-images");
const out = path.join(import.meta.dirname, "..", "public", "promo");
fs.mkdirSync(out, { recursive: true });

const ffmpeg = (input, filter, output) =>
  execFileSync("ffmpeg", ["-v", "error", "-y", "-i", input, "-vf", filter, "-q:v", "2", output]);

for (const n of [1, 2, 3]) {
  const input = path.join(samples, `${n}.jpg`);
  // The samples are small: upscale with lanczos and a light sharpen.
  ffmpeg(input, "scale=1152:-2:flags=lanczos,unsharp=5:5:0.6", path.join(out, `fg${n}.jpg`));
  ffmpeg(
    input,
    "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,boxblur=40:2,eq=brightness=-0.12:saturation=1.2",
    path.join(out, `bg${n}.jpg`),
  );
}
