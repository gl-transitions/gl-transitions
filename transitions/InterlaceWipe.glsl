// Author: gre
// License: MIT
// Description: The incoming image loads over the outgoing one like an interlaced picture on a slow connection: a first pass sweeps down drawing it in big blocky rows, then each new pass sweeps down again at twice the detail until the picture is sharp
// Tags: wipe, retro, pixelate, blocks, scanlines, vertical

// @range(24, 480) Number of rows of pixels of the picture being loaded, before its last pass draws it at full detail
uniform float rows; // = 120.0
// @range(2, 6, 1) Number of passes, the first one drawing blocks 2^(passes - 1) rows tall
uniform int passes; // = 5
// @range(0, 1) Brightness of the freshly drawn rows behind each sweep
uniform float glow; // = 0.5

vec4 transition(vec2 uv) {
  float lines = max(floor(rows), 1.0);
  float cols = max(floor(lines * ratio + 0.5), 1.0);
  // no more passes than fit: the first pass's blocks are never taller than the picture
  float n = max(min(clamp(float(passes), 2.0, 6.0), 1.0 + floor(log2(lines) + 0.01)), 2.0);
  // the picture is read from its top left corner, in pixel rows and columns
  float row = min(floor((1.0 - uv.y) * lines), lines - 1.0);
  float col = min(floor(uv.x * cols), cols - 1.0);

  // a slight ease, so the loading starts and finishes gently
  float p = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.5);
  // each pass sweeps the whole frame in time T; the passes start one after another and overlap a little
  float T = 1.5 / (n + 0.5);

  // the finest pass that has drawn this pixel wins: try them from the finest (blocks 1 row tall) up
  float bestB = 0.0;
  float light = 0.0;
  for (int i = 0; i < 6; i++) {
    float k = n - 1.0 - float(i); // order of this pass, from 0 for the first one
    if (k < 0.0) break;
    float b = floor(exp2(float(i)) + 0.5); // block size of this pass, in pixel rows
    float u = clamp((p - (1.0 - T) * k / (n - 1.0)) / T, 0.0, 1.0);
    // the sweep, in block rows; the row it is on fills from left to right block by block.
    // Freshly drawn rows are brighter over a few rows behind it: the sweep runs on past the
    // bottom of the frame until that glow is gone, so the pass is over before its time ends
    float glowRows = max(1.5 * b, 0.05 * lines);
    float blockRows = ceil(lines / b);
    float sweep = u * (blockRows + glowRows / b);
    float behind = sweep - floor(row / b) - (floor(col / b) + 1.0) / ceil(cols / b);
    if (behind >= -1e-4) {
      bestB = b;
      light = 1.0 - smoothstep(0.0, glowRows, behind * b);
      break;
    }
  }

  if (bestB == 0.0) return getFromColor(uv);
  vec4 c;
  if (bestB <= 1.0) {
    c = getToColor(uv);
  } else {
    // a block repeats the top left pixel of its block
    float top = floor(row / bestB) * bestB;
    float left = floor(col / bestB) * bestB;
    c = getToColor(vec2((left + 0.5) / cols, 1.0 - (top + 0.5) / lines));
  }
  c.rgb += 0.5 * glow * light * (1.0 - c.rgb);
  return c;
}
