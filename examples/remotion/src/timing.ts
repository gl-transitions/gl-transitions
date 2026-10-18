// Durations of the Showcase, in frames at 30 fps: Root.tsx needs them without loading the
// Showcase (its fonts and texture), which is only loaded when it is opened or rendered.
export const SHOWCASE_SCENE = 120;
export const SHOWCASE_TRANSITION = 30;
export const SHOWCASE_SLIDES = 5;
export const SHOWCASE_DURATION = SHOWCASE_SLIDES * SHOWCASE_SCENE - (SHOWCASE_SLIDES - 1) * SHOWCASE_TRANSITION;
