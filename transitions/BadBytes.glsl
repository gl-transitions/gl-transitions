// Author: gre
// License: MIT
// Description: Bytes of the compressed outgoing picture go bad one after another: everything after each bad byte slips sideways and takes a wrong color, until the incoming picture is decoded instead and recovers segment by segment
// Tags: glitch, codec, corruption, blocks, color
// Preview: 0.45

// @param Number of rows of blocks
// @range(10, 60)
uniform float rows; // = 30.0
// @param Strength of the wrong colors
// @range(0, 1)
uniform float tint; // = 0.55

const int EVENTS = 9;

float hash(float n) {
  float q = fract(n * 0.1031 + 0.37);
  q *= q + 33.33;
  return fract(q * (q + q));
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 n = floor(vec2(rows * ratio, rows));
  vec2 b = min(floor(uv * n), n - 1.0);
  // reading order
  float d = (n.y - 1.0 - b.y) * n.x + b.x;
  float shift = 0.0, chroma = 0.0, seg = 0.0;
  vec3 dc = vec3(0.0);
  for (int i = 0; i < EVENTS; i++) {
    float f = float(i), h = hash(f + 3.0);
    if (d < floor(n.x * n.y * (f + 0.8 * h) / float(EVENTS))) break;
    float on = 0.03 + 0.4 * hash(f + 41.0), off = 0.6 + 0.36 * hash(f + 19.0);
    seg = f + 1.0;
    if (p < on || p > off) continue;
    // a decoder keeps the bad offset until the next restart marker
    float restart = 1.0 + floor(3.0 * (p - on) / (off - on));
    shift += floor((h - 0.5) * 0.5 * n.x) * (0.5 + 0.5 * restart);
    chroma += floor((hash(f + 77.0) - 0.5) * 8.0);
    dc += (vec3(hash(f + 5.0 + restart), hash(f + 25.0), hash(f + 61.0)) - 0.5) * 1.6 * (mod(f, 2.0) * 2.0 - 1.0);
  }
  dc /= 1.0 + 0.9 * length(dc);
  vec2 q = vec2(fract(uv.x + floor(shift) / n.x), uv.y);
  vec2 r = vec2(fract(uv.x + (floor(shift) + chroma) / n.x), uv.y);
  bool incoming = p > 0.3 + 0.4 * hash(seg + 11.0);
  vec4 c = incoming ? getToColor(q) : getFromColor(q);
  vec3 hue = incoming ? getToColor(r).rgb : getFromColor(r).rgb;
  vec3 col = luma(c.rgb) + (hue - luma(hue)) * (1.0 + 0.8 * min(length(dc), 1.0));
  col += tint * (dc - 0.6 * luma(dc));
  return vec4(clamp(col, 0.0, 1.0), c.a);
}
