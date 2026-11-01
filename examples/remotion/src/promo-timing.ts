// The transitions of the Promo, in the order they play, and its durations in frames at 30 fps.
export const PROMO_ORDER = [
  "ApertureWipe",
  "Tunnel",
  "Shred",
  "SpiralWipe",
  "Prisms",
  "WhipPan",
  "Halftone",
  "Curtains",
  "TvRoll",
  "Honeycomb",
  "FallOver",
  "DitherDissolve",
  "PaperTear",
  "Fisheye",
  "Comb",
  "DiamondWipe",
  "Puzzle",
  "TvTurnOff",
] as const;
// Nine of them, played at once in the 3x3 grid.
export const PROMO_GRID_NAMES = [
  "SpiralWipe",
  "Honeycomb",
  "Puzzle",
  "Prisms",
  "Shred",
  "ApertureWipe",
  "Halftone",
  "Curtains",
  "Tunnel",
] as const;
export const PROMO_TRANSITION = 24;
export const PROMO_HOLD = 14;
export const PROMO_LAST_HOLD = 22;
export const PROMO_INTRO = 76;
export const PROMO_SERIES =
  PROMO_INTRO +
  (PROMO_ORDER.length - 1) * (2 * PROMO_TRANSITION + PROMO_HOLD) +
  PROMO_TRANSITION +
  PROMO_LAST_HOLD -
  PROMO_ORDER.length * PROMO_TRANSITION;
export const PROMO_GRID = 80;
export const PROMO_OUTRO = 110;
export const PROMO_DURATION = PROMO_SERIES + PROMO_GRID + PROMO_OUTRO;
