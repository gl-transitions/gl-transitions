// The photos of the preview GIFs (preview-images/, credited in its CREDITS.md).

import path from "node:path";
import { createHash } from "node:crypto";

// A trio takes one photo of each group, so that its photos contrast.
export const PREVIEW_IMAGES = [
  // a large subject on a calm background
  ["lion", "water-lily", "zeus-temple"],
  // cool colors
  ["boat", "camels", "cosmic-cliffs"],
  // bright, with fine details
  ["chevrolet", "sunflowers"],
];
const ORDERS = [
  [0, 1, 2],
  [0, 2, 1],
  [1, 0, 2],
  [1, 2, 0],
  [2, 0, 1],
  [2, 1, 0],
];

export const previewImagePath = (image) => path.join(import.meta.dirname, "preview-images", `${image}.jpg`);

// The trio (A, B, C) of a transition: always the same for a given name.
export function choosePreviewImages(transitionName) {
  const hash = createHash("sha256").update(transitionName).digest();
  const trio = PREVIEW_IMAGES.map((group, i) => group[hash[i] % group.length]);
  return ORDERS[hash[PREVIEW_IMAGES.length] % ORDERS.length].map((i) => trio[i]);
}
