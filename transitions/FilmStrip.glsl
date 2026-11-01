// Author: gre
// License: MIT
// Description: The picture slips like film in a projector gate: it shrinks to show the sprocket holes, the strip runs down with motion blur and a slight weave, then the incoming frame lands in place
// Tags: retro, vertical, motion-blur, film

// @range(1, 6, 1) Number of frames that slip by
uniform int frames; // = 2
// @range(0, 0.4) How much the picture shrinks during the slip, showing the film's edges
uniform float shrink; // = 0.2
// @range(0, 1) Length of the motion blur at full speed
uniform float blur; // = 0.5
// @range(0, 1) Amount of horizontal weave and vertical jitter
uniform float weave; // = 0.5
// @color Color of the film around the pictures and of the line between frames
uniform vec4 filmColor; // = vec4(0.06, 0.05, 0.05, 1.0)
// @color Color of the light through the sprocket holes
uniform vec4 holeColor; // = vec4(0.96, 0.93, 0.85, 1.0)

// height of the line between two frames, in frame heights
const float FRAME_LINE = 0.08;
// sprocket holes per frame
const float HOLES = 4.0;
const int SAMPLES = 16;

// a fine, evenly spread dither pattern over small cells of the frame
float dither(vec2 cell) {
  return fract(52.9829189 * fract(dot(cell, vec2(0.06711056, 0.00583715))));
}

// the film at (x, y): x across it (0 to 1 over the picture), y along it from the start of frame
// number base, in frame heights; holes fades the sprocket holes in
vec4 film(float x, float y, float base, float n, float aa, float holeX, vec2 holeSize, float holes) {
  float pitch = 1.0 + FRAME_LINE;
  float jy = floor(y / pitch);
  float j = base + jy;
  float fy = y - jy * pitch;
  vec4 c = filmColor;
  if (x >= 0.0 && x <= 1.0 && fy <= 1.0) {
    vec2 q = vec2(x, fy);
    c = j < n ? getFromColor(q) : getToColor(q);
  }
  // soft edges for the picture during the slip (none at rest, where it fills the frame)
  float inside = min(min(x, 1.0 - x) * ratio, min(fy, 1.0 - fy));
  c = mix(filmColor, c, clamp(inside / aa + 0.5, 0.0, 1.0));
  // the sprocket holes, in the margins on both sides, in frame heights
  float hy = mod(y, pitch / HOLES) - 0.5 * pitch / HOLES;
  float hx = (abs(x - 0.5) - holeX) * ratio;
  vec2 dd = abs(vec2(hx, hy)) - holeSize + 0.3 * holeSize.x;
  float sd = length(max(dd, 0.0)) + min(max(dd.x, dd.y), 0.0) - 0.3 * holeSize.x;
  return mix(c, holeColor, clamp(0.5 - sd / aa, 0.0, 1.0) * holes);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  float n = max(float(frames), 1.0);
  float pitch = 1.0 + FRAME_LINE;
  float p = progress;
  // the picture shrinks first, slips, then grows back
  float env = smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.7, 1.0, p));
  float k = 1.0 - shrink * env;
  // the slip, in frames: smooth start and landing
  float x0 = clamp((p - 0.15) / 0.7, 0.0, 1.0);
  float slip = x0 * x0 * x0 * (x0 * (x0 * 6.0 - 15.0) + 10.0);
  float speed = 30.0 * x0 * x0 * (1.0 - x0) * (1.0 - x0) / 0.7; // d(slip)/d(progress), up to ~2.7
  // weave and jitter, only while the film moves
  float wob = weave * env;
  // (the weave stays within the film's margin)
  float dx = wob * smoothstep(0.0, 0.1, shrink) * (0.006 * sin(p * 47.0) + 0.004 * sin(p * 113.0 + 1.3));
  float dy = wob * 0.012 * sin(p * 71.0 + 0.4) * (1.0 - speed / 2.7);

  // the frames slipped by so far: whole frames, and the position within the current one
  float frameSlip = slip * n;
  float base = floor(frameSlip);
  float x = (uv.x - 0.5) / k + 0.5 + dx;
  float y = (uv.y - 0.5) / k + 0.5 + dy + (frameSlip - base) * pitch;
  // anti-aliasing width, in frame heights: none at rest or without margin
  float aa = 0.002 * min(1.0, 10.0 * env) * min(1.0, 20.0 * shrink) + 1e-4;
  // the holes sit in the middle of the margin the shrinking picture shows
  float margin = 0.5 * shrink / max(1.0 - shrink, 0.01);
  float holeX = 0.5 + 0.5 * margin;
  vec2 holeSize = vec2(0.28 * margin * ratio, 0.11 * pitch / HOLES);
  float holes = smoothstep(0.0, 0.02, margin);

  // motion blur along the strip, dithered to hide the steps
  float len = blur * 0.06 * speed * n;
  vec4 color = vec4(0.0);
  if (len < 1e-5) {
    color = film(x, y, base, n, aa, holeX, holeSize, holes);
  } else {
    // averaged with premultiplied colors, so transparent parts don't darken the others
    float jitter = dither(floor(uv * vec2(ratio, 1.0) * 540.0));
    for (int i = 0; i < SAMPLES; i++) {
      float t = (float(i) + jitter) / float(SAMPLES) - 0.5;
      vec4 c = film(x, y + t * len, base, n, aa, holeX, holeSize, holes);
      color += vec4(c.rgb * c.a, c.a);
    }
    color /= float(SAMPLES);
    color.rgb = color.a > 0.0 ? color.rgb / color.a : vec3(0.0);
  }
  // the projector's light flickers a little while the film runs
  color.rgb *= 1.0 - 0.08 * wob * (0.5 + 0.5 * sin(p * 157.0));
  return color;
}
