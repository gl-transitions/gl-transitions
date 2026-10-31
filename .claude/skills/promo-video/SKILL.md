---
name: promo-video
description: Makes a short promotional video of gl-transitions for social media (Instagram Reels, TikTok, YouTube Shorts, X), for example to announce new transitions, with the Promo composition of the Remotion example. Use when asked for a promo, teaser, announcement or social media video of transitions.
---

# Making a promo video

The video is the Promo composition of `examples/remotion` (`src/Promo.tsx`, `src/promo-timing.ts`), rendered with Remotion and the repository's own `@gl-transitions/remotion`: every cut in it is a real transition of the package. It comes in two cuts, `PromoVertical` (1080x1920, Reels/TikTok/Shorts) and `PromoSquare` (1080x1080, X and feeds), about 30 s at 30 fps, silent.

## 1. Choose what it shows

Edit `examples/remotion/src/promo-timing.ts`:

- `PROMO_ORDER`: the transitions to show, in order. The count on the intro card, the header and the `07 / 18` labels follow its length. Alternate the kinds of effects (a wipe, then a 3D one, then a stylized one…) so that two similar transitions never play back to back, and end on one with a strong finish.
- `PROMO_GRID_NAMES`: nine of them for the 3x3 grid, the most graphic ones (they play at tile size).
- The durations: each transition takes `PROMO_TRANSITION` frames (24) and its photo holds `PROMO_HOLD` frames (14), about 1.3 s per transition. Keep the total under ~35 s: past 18–20 transitions, shorten the hold rather than the transition.

The outro lists the platforms (`TARGETS` in `Promo.tsx`): check them against README.md and `packages/` before rendering, and only claim what is published.

## 2. Build and render

```sh
# From the repository root: gl-transitions and the Remotion package, built from the workspace
pnpm install && pnpm run build && pnpm --filter @gl-transitions/remotion run build

cd examples/remotion
pnpm run prepare-promo   # photos into public/promo/ from scripts/rendering/sample-images (needs ffmpeg)
pnpm exec remotion render src/index.ts PromoVertical out/promo-vertical.mp4 --gl=angle
pnpm exec remotion render src/index.ts PromoSquare out/promo-square.mp4 --gl=angle

# Move the index to the front of the file, so that it starts playing before it is downloaded
ffmpeg -i out/promo-vertical.mp4 -c copy -movflags +faststart promo-vertical.mp4
```

- `--gl=angle` is required for the WebGL transitions to render headlessly.
- The build of the packages may print Metal "missing toolchain" errors on a Mac without the Metal Toolchain: they don't stop it.
- pnpm refuses to run when `node_modules` is a symlink: install in the worktree itself.
- Iterate on single frames first, which takes seconds instead of minutes: `pnpm exec remotion still src/index.ts PromoVertical out/f.png --frame=300 --gl=angle`.

Deliver the files where the person asked (by default `~/Desktop`); the videos and `public/` are not committed.

## 3. Check it

Look at the video before handing it over, as frames:

```sh
ffmpeg -v error -i promo-vertical.mp4 -vf "fps=2,scale=180:-2,tile=11x6" -frames:v 1 contact-sheet.jpg
ffprobe -v error -show_entries stream=codec_name,profile,pix_fmt,width,height,r_frame_rate -show_entries format=duration promo-vertical.mp4
```

Read the contact sheet and check:

- every label names the transition playing under it;
- no black, empty or broken frames (a transition that goes through black, like TvTurnOff, is expected);
- in the vertical cut, all text between y ≈ 250 and y ≈ 1570: the apps cover the top 250 px and the bottom 350 px with their own interface;
- text stays readable over busy transitions (the `Shade` gradient behind the label is there for that);
- H.264, yuv420p, the right size and fps.

## How it is designed

- **The cuts are the transitions.** A `TransitionSeries` with `glTransition({ name })` between `PhotoScene`s: there is no other edit, so the video demonstrates the package as it is used.
- **Photo cards.** The sample images are small (512x400), so each shot is a rounded card with a slow Ken Burns zoom over a blurred, darkened copy of the same photo filling the frame, instead of a stretched full-bleed photo. `MOVES` varies the direction so the same photo doesn't look repeated.
- **Lower-third label.** A `NEW` badge with `07 / 18`, the name rising in bold, and a progress bar that follows the transition, so viewers can find the name in the docs.
- **Structure.** Intro card with the count (2.5 s), the transitions one by one, the 3x3 grid for energy, then the outro (open source, the site, the platforms, the install command). The intro, grid and outro use the animated `Backdrop` shader of the example with their own palettes.
- **Type.** Bricolage Grotesque for the display text and JetBrains Mono for the details, from `@remotion/google-fonts`, one accent color (`ACCENT`).
- **Grid tiles play one transition each.** More than one transition per tile at once created too many WebGL contexts and lost them.
- **Square cut.** `useLayout()` switches the card, label and header positions by aspect ratio; check the square cut separately, the grid and the outro need it most.
