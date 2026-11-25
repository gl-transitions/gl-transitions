import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { PREVIEW_IMAGES, choosePreviewImages, previewImagePath } from "./preview-images.mjs";

const DIR = path.join(import.meta.dirname, "preview-images");
const SEEDS = Array.from({ length: 1000 }, (_, i) => i);
const IMAGES = PREVIEW_IMAGES.flat();

test("every photo of the bank exists and is credited, and every one of preview-images/ is in the bank", () => {
  const photos = fs.readdirSync(DIR).filter((file) => file.endsWith(".jpg"));
  for (const file of photos) assert.ok(IMAGES.includes(`preview-images/${file}`), file);
  const credits = fs.readFileSync(path.join(DIR, "CREDITS.md"), "utf8");
  for (const image of IMAGES) {
    assert.ok(fs.existsSync(previewImagePath(image)), image);
    const file = image.replace("preview-images/", "").replace("sample-images/", "../sample-images/");
    assert.ok(credits.includes(`| \`${file}\` |`), `${file} is not credited`);
  }
});

test("a trio has one photo of each group", () => {
  for (const seed of SEEDS) {
    const trio = choosePreviewImages(seed);
    assert.equal(trio.length, 3);
    for (const group of PREVIEW_IMAGES) assert.equal(trio.filter((image) => group.includes(image)).length, 1);
  }
});

test("consecutive seeds go through every trio", () => {
  const trios = PREVIEW_IMAGES.reduce((count, group) => count * group.length, 1);
  const sorted = SEEDS.map((seed) => choosePreviewImages(seed).sort().join());
  for (const seed of SEEDS.slice(0, -trios)) assert.equal(new Set(sorted.slice(seed, seed + trios)).size, trios);
});

test("every photo can come first, second or third", () => {
  for (const i of [0, 1, 2]) {
    assert.deepEqual(new Set(SEEDS.map((seed) => choosePreviewImages(seed)[i])), new Set(IMAGES));
  }
});
