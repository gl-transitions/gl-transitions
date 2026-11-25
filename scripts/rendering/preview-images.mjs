// The photos of the preview GIFs, credited in preview-images/CREDITS.md.

import path from "node:path";
import { createHash } from "node:crypto";

// A trio takes one photo of each group, so that its photos contrast.
export const PREVIEW_IMAGES = [
  // a large subject on a calm background
  ["preview-images/lion.jpg", "preview-images/water-lily.jpg", "preview-images/zeus-temple.jpg", "sample-images/2.jpg"],
  // cool colors
  ["preview-images/boat.jpg", "preview-images/camels.jpg", "preview-images/cosmic-cliffs.jpg", "sample-images/1.jpg"],
  // warm, with fine details
  ["preview-images/chevrolet.jpg", "preview-images/sunflowers.jpg", "sample-images/3.jpg"],
];
const ORDERS = [
  [0, 1, 2],
  [0, 2, 1],
  [1, 0, 2],
  [1, 2, 0],
  [2, 0, 1],
  [2, 1, 0],
];

export const previewImagePath = (image) => path.join(import.meta.dirname, image);

const sha256 = (text) => createHash("sha256").update(text).digest();

// Every trio, in a fixed shuffled order.
const TRIOS = PREVIEW_IMAGES.reduce(
  (trios, group) => trios.flatMap((trio) => group.map((image) => [...trio, image])),
  [[]],
).sort((a, b) => Buffer.compare(sha256(a.join()), sha256(b.join())));

// The photos A, B and C of a seed (an integer >= 0): consecutive seeds have different trios.
export function choosePreviewImages(seed) {
  const trio = TRIOS[seed % TRIOS.length];
  const order = ORDERS[sha256(String(seed)).readUInt32BE() % ORDERS.length];
  return order.map((i) => trio[i]);
}
