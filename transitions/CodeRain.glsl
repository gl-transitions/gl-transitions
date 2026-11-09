// Author: gre
// License: MIT
// Description: The outgoing image darkens into a grid of flickering code characters tinted by its colors, then glowing streams of characters fall down the columns at their own speeds, each with a bright head and a fading tail, leaving the incoming image behind
// Tags: text, digital, rain, reveal

// @range(0.02, 0.1) Height of a character, in frame heights
uniform float cellSize; // = 0.045
// @range(0.05, 1) Average length of the streams' fading tails, in frame heights
uniform float trail; // = 0.5
// @range(0, 1) How much the characters of the outgoing image take its colors, instead of the glow color
uniform float tint; // = 0.5
// @color Color of the falling streams and their glow
uniform vec4 glow; // = vec4(0.2, 1.0, 0.4, 1.0)

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec4 hash42(vec2 p) {
  vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
  p4 += dot(p4, p4.wzxy + 33.33);
  return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// 1 inside a stroke, fading out from 0.3 to 0.6 dot of distance
vec4 band(vec4 d) {
  return 1.0 - smoothstep(0.3, 0.6, d);
}

// coverage of the character of this cell at this time, drawn on a 5x7 dot grid in a 6x8 cell
// (local: 0..1 in the cell, from its top left), made of strokes picked by hashes
float glyph(vec2 cell, float t, vec2 local) {
  vec2 b = local * vec2(6.0, 8.0) - 0.5;
  float x = b.x;
  float y = b.y;
  float d = 0.667 * y;
  // how far outside the spans 0..4, 0..6, 0..3 and 3..6, in dots
  float x04 = abs(x - 2.0) - 2.0;
  float y06 = abs(y - 3.0) - 3.0;
  float y03 = abs(y - 1.5) - 1.5;
  float y36 = abs(y - 4.5) - 1.5;
  vec2 seed = cell + t * vec2(37.0, 61.0);
  // strokes: three bars and a diagonal, the halves of the side verticals,
  // the halves of the middle vertical, the other diagonal and a short bar
  vec4 sa = band(abs(vec4(y, y - 3.0, y - 6.0, x - d))) * band(vec4(x04, x04, x04, y06));
  vec4 sb = band(abs(vec4(x, x, x - 4.0, x - 4.0))) * band(vec4(y03, y36, y03, y36));
  vec4 sc = band(abs(vec4(x - 2.0, x - 2.0, x + d - 4.0, y - 1.0))) * band(vec4(y03, y36, y06, abs(x - 2.0) - 1.0));
  float on = dot(step(0.68, hash42(seed)), sa);
  on += dot(step(0.68, hash42(seed + 41.0)), sb);
  on += dot(step(0.68, hash42(seed + 83.0)), sc);
  return min(on, 1.0);
}

vec4 transition(vec2 uv) {
  float h = max(cellSize, 0.005);
  vec2 dims = vec2(0.75 * h, h);
  // frame coordinates from the top left, in frame heights
  vec2 fp = vec2(uv.x * ratio, 1.0 - uv.y);
  // (shifted by odd fractions of a cell, so that pixel centers don't fall on its lines at usual sizes)
  vec2 grid = fp / dims + vec2(0.389, 0.278);
  vec2 cell = floor(grid);
  vec2 local = grid - cell;
  float rc = hash12(cell + vec2(97.0, 131.0));

  // each column has its own stream: its start, speed and tail length
  float r1 = hash12(vec2(cell.x, 11.0));
  float r2 = hash12(vec2(cell.x, 23.0));
  float r3 = hash12(vec2(cell.x, 37.0));
  float T = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.5);
  float len = max(trail, 0.01) * (0.5 + r3);
  float u = clamp((T - 0.03 - 0.5 * r1) / (0.3 + 0.12 * r2), 0.0, 1.0);
  // the head falls from above the frame, speeding up a little, until its tail has left the frame
  float head = mix(-0.2, 1.0 + h + len, u * (0.7 + 0.3 * u));
  // how far the head has gone past the cell's top
  float dy = head - (cell.y - 0.278) * h;

  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);

  // ahead of the stream: the outgoing image darkens into characters tinted by its cell's color,
  // over time and as the head comes near
  vec2 cuv = clamp(vec2((cell.x + 0.111) * dims.x / ratio, 1.0 - (cell.y + 0.222) * h), 0.0, 1.0);
  vec4 ca = getFromColor(cuv);
  float lum = dot(ca.rgb, vec3(0.299, 0.587, 0.114));
  vec3 hue = ca.rgb / max(max(ca.r, max(ca.g, ca.b)), 0.05);
  vec3 ink = mix(glow.rgb * glow.a, hue, tint) * (0.1 + 0.6 * lum);
  float near = smoothstep(-0.15, 0.0, dy);
  float dim = max(smoothstep(0.0, 0.3, T), near);
  float g = max(smoothstep(0.0, 0.2, T - 0.12 * rc), near);
  float passed = step(0.0, dy);
  // the characters change slowly ahead of the stream and fast in it
  float slow = mod(floor(T * 12.0 + rc * 7.0), 32.0);
  float fast = 32.0 + mod(floor(T * 40.0 + rc * 13.0), 32.0);
  float chr = glyph(cell, mix(slow, fast, passed), local);
  vec3 code = a.rgb * (1.0 - 0.8 * dim) + ink * chr * g;

  // behind the head: bright characters changing fast, fading along the tail, over a shadow that
  // clears in the tail's last two thirds to leave the incoming image
  float fade = clamp(1.0 - dy / len, 0.0, 1.0);
  float shade = 1.0 - smoothstep(0.3 * len, len, dy);
  float hot = 1.0 - smoothstep(h, 3.0 * h, dy);
  vec3 col = mix(glow.rgb * 1.2, vec3(1.0), 0.8 * hot) * glow.a;
  vec3 stream = b.rgb * (1.0 - 0.8 * shade) + col * chr * (fade * (2.0 - fade) + hot * fade);

  // a soft glow around the head, within its column
  float yy = (head - fp.y) / (1.5 * h);
  float halo = 1.6 * u * (1.0 - u) * exp(-yy * yy) * (1.0 - smoothstep(0.25, 0.5, abs(local.x - 0.5)));
  vec3 rgb = mix(code, stream, passed) + glow.rgb * glow.a * halo;
  // the outgoing image's opacity stays under the tail's shadow, then gives way to the incoming one's
  return vec4(clamp(rgb, 0.0, 1.0), mix(a.a, mix(b.a, a.a, shade), passed));
}
