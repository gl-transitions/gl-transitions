// Author: gre
// License: MIT
// Description: The image turns into text-mode characters, denser where it is brighter, the characters scramble into those of the incoming image, then resolve back into it
// Tags: text, pattern, retro, digital

// @range(0.01, 0.1) Height of a character at the peak, in frame heights
uniform float cellSize; // = 0.04
// @param Color the characters with the image (otherwise, with the ink color)
uniform bool colored; // = true
// @color Color of the characters when they are not colored with the image
uniform vec4 ink; // = vec4(0.3, 1.0, 0.45, 1.0)
// @color Color behind the characters
uniform vec4 background; // = vec4(0.0, 0.0, 0.0, 1.0)

// width of a character cell, in cell heights
const float ASPECT = 0.6;
// half width of the strokes, in cell heights
const float STROKE = 0.05;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// distance to the segment from a to b
float segment(vec2 q, vec2 a, vec2 b) {
  vec2 pa = q - a;
  vec2 ba = b - a;
  return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// distance to the strokes of the character of this density, from 0 (" ") to 9 ("@"),
// at q, in cell heights from the cell's center
float glyph(float g, vec2 q) {
  if (g < 0.5) return 1.0; // " "
  if (g < 1.5) return length(q - vec2(0.0, -0.27)) - 0.035; // "."
  if (g < 2.5) return min(length(q - vec2(0.0, -0.25)), length(q - vec2(0.0, 0.1))) - 0.035; // ":"
  if (g < 3.5) return segment(q, vec2(-0.17, 0.0), vec2(0.17, 0.0)) - STROKE; // "-"
  if (g < 4.5) { // "="
    return min(segment(q, vec2(-0.18, 0.1), vec2(0.18, 0.1)), segment(q, vec2(-0.18, -0.1), vec2(0.18, -0.1))) - STROKE;
  }
  if (g < 5.5) { // "+"
    return min(segment(q, vec2(-0.19, 0.0), vec2(0.19, 0.0)), segment(q, vec2(0.0, -0.19), vec2(0.0, 0.19))) - STROKE;
  }
  if (g < 6.5) { // "*"
    float d = segment(q, vec2(0.0, -0.2), vec2(0.0, 0.2));
    d = min(d, segment(q, vec2(-0.18, -0.11), vec2(0.18, 0.11)));
    d = min(d, segment(q, vec2(-0.18, 0.11), vec2(0.18, -0.11)));
    return d - STROKE;
  }
  if (g < 7.5) { // "#"
    float d = min(segment(q, vec2(-0.06, -0.3), vec2(-0.1, 0.3)), segment(q, vec2(0.12, -0.3), vec2(0.08, 0.3)));
    d = min(d, min(segment(q, vec2(-0.24, 0.11), vec2(0.24, 0.11)), segment(q, vec2(-0.24, -0.11), vec2(0.24, -0.11))));
    return d - STROKE;
  }
  if (g < 8.5) { // "%"
    float d = segment(q, vec2(-0.2, -0.3), vec2(0.2, 0.3));
    d = min(d, abs(length(q - vec2(-0.13, 0.19)) - 0.08));
    d = min(d, abs(length(q - vec2(0.13, -0.19)) - 0.08));
    return d - STROKE;
  }
  // "@": a ring around a small "a"
  float d = abs(length(q) - 0.25);
  d = min(d, abs(length(q - vec2(-0.02, 0.0)) - 0.1));
  d = min(d, segment(q, vec2(0.08, 0.1), vec2(0.08, -0.12)));
  return d - 0.8 * STROKE;
}

// the brightness of a color, from 0 to 1, as a character density
float density(vec4 c) {
  return floor(pow(clamp(dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a, 0.0, 1.0), 0.75) * 9.99);
}

// the average color of a cell, from 4 samples
vec4 cellColor(vec2 center, vec2 dims, bool incoming) {
  vec4 c = vec4(0.0);
  for (int i = 0; i < 4; i++) {
    vec2 o = (vec2(mod(float(i), 2.0), floor(float(i) / 2.0)) - 0.5) * 0.5 * dims;
    vec2 st = clamp((center + o) / vec2(ratio, 1.0) + 0.5, 0.0, 1.0);
    c += incoming ? getToColor(st) : getFromColor(st);
  }
  return c * 0.25;
}

// the frame in characters of height h, at the point fp (in frame heights from the center)
vec4 characters(vec2 fp, float h) {
  float p = progress;
  vec2 dims = vec2(ASPECT * h, h);
  vec2 cell = floor(fp / dims);
  vec2 center = (cell + 0.5) * dims;
  vec2 q = (fp - center) / h;

  // each cell switches to the incoming image at its own time, scrambling through
  // random characters around it
  float r = hash12(cell + 100.0);
  float at = 0.4 + 0.2 * r;
  bool incoming = p > at;
  vec4 c = cellColor(center, dims, incoming);
  float g = density(c);
  float scramble = 1.0 - smoothstep(0.02, 0.045, abs(p - at));
  if (hash12(cell + floor(p * 40.0) * vec2(17.0, 31.0)) < scramble) {
    g = 1.0 + floor(9.0 * hash12(cell * 1.7 + floor(p * 40.0) * vec2(5.0, 11.0)));
  }

  float cover = 1.0 - smoothstep(-0.02, 0.02, glyph(g, q));
  vec3 tint = colored ? mix(c.rgb, c.rgb / max(max(c.r, max(c.g, c.b)), 0.05), 0.7) : ink.rgb;
  float alpha = colored ? c.a : ink.a * c.a;
  // where the image is transparent, so are the characters and their background
  // colored characters glow faintly over their cell, so the picture stays readable
  vec3 behind = colored ? mix(background.rgb, c.rgb, 0.3) : background.rgb;
  vec4 back = vec4(behind, background.a * c.a);
  return mix(back, vec4(clamp(tint, 0.0, 1.0), alpha), cover);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // the characters show up until 0.3 and fade back into the image from 0.7,
  // growing to their full size before the switch (0.36 to 0.64), then shrinking back
  float show = smoothstep(0.0, 0.3, p) * (1.0 - smoothstep(0.7, 1.0, p));
  float grow = smoothstep(0.0, 0.36, p) * (1.0 - smoothstep(0.64, 1.0, p));
  // in steps, like a terminal switching font sizes, with a quick blend from one to the next
  float level = grow * 3.0;
  float step0 = floor(level);
  float blend = smoothstep(0.3, 0.7, level - step0);
  vec2 fp = (uv - 0.5) * vec2(ratio, 1.0);
  vec4 text = characters(fp, cellSize * mix(0.45, 1.0, step0 / 3.0));
  if (blend > 0.0) {
    text = mix(text, characters(fp, cellSize * mix(0.45, 1.0, min(step0 + 1.0, 3.0) / 3.0)), blend);
  }
  vec4 image = p < 0.5 ? getFromColor(uv) : getToColor(uv);
  return mix(image, text, show);
}
