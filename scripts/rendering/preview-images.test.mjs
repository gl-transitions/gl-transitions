import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { PREVIEW_IMAGES, choosePreviewImages, previewImagePath } from "./preview-images.mjs";

const DIR = path.join(import.meta.dirname, "preview-images");
const TRANSITIONS = path.join(import.meta.dirname, "..", "..", "transitions");
const names = fs.readdirSync(TRANSITIONS).map((file) => path.basename(file, ".glsl"));

test("the bank is exactly the photos of the folder, all credited", () => {
  const images = PREVIEW_IMAGES.flat().map((image) => path.basename(previewImagePath(image)));
  const files = fs.readdirSync(DIR).filter((file) => file.endsWith(".jpg"));
  assert.deepEqual(files.sort(), images.sort());
  const credits = fs.readFileSync(path.join(DIR, "CREDITS.md"), "utf8");
  for (const image of images) assert.ok(credits.includes(`| \`${image}\` |`), `${image} is not credited`);
});

test("a transition gets one photo of each group", () => {
  for (const name of names) {
    const trio = choosePreviewImages(name);
    assert.equal(trio.length, 3);
    for (const group of PREVIEW_IMAGES) assert.equal(trio.filter((image) => group.includes(image)).length, 1, name);
  }
});

test("the choice only depends on the name", () => {
  assert.deepEqual(choosePreviewImages("Fade"), ["sunflowers", "zeus-temple", "cosmic-cliffs"]);
});

test("the collection uses every photo", () => {
  assert.equal(new Set(names.flatMap(choosePreviewImages)).size, PREVIEW_IMAGES.flat().length);
});
