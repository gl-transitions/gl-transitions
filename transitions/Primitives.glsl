// Author: gre
// License: MIT
// Description: Flat red, yellow and blue circles, squares and triangles pop onto the outgoing picture one after another with a springy overshoot and a little spin, the incoming picture popping inside each a beat later, until a last red ring opens from the middle over the whole frame
// Tags: shapes, pop, graphic, motion-design, circles, squares, triangles

// @range(0, 0.2) Delay between a flat shape and the picture that pops inside it
uniform float lag; // = 0.07

// @color First flat color, also the last shape opening over the frame
uniform vec4 color1; // = vec4(0.91, 0.27, 0.2, 1.0)
// @color Second flat color
uniform vec4 color2; // = vec4(0.98, 0.76, 0.18, 1.0)
// @color Third flat color
uniform vec4 color3; // = vec4(0.13, 0.27, 0.66, 1.0)

const float AA = 0.003;

// the small shapes overshoot, the last one opens smoothly over the whole frame
float pop(float t, bool last) {
  t = clamp(t, 0.0, 1.0);
  float u = t - 1.0;
  return last ? t * t * (3.0 - 2.0 * t) : 1.0 + u * u * (2.7 * u + 1.7);
}

// kind: 0 circle, 1 square, 2 triangle
float shape(vec2 p, float kind, float r, float a) {
  float c = cos(a), s = sin(a);
  p = vec2(c * p.x + s * p.y, c * p.y - s * p.x);
  if (kind < 0.5) return length(p) - r;
  if (kind < 1.5) {
    vec2 d = abs(p) - r * 0.86;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
  }
  p.y += r * 0.25;
  p.x = abs(p.x);
  return max(p.x * 0.866 + p.y * 0.5, -p.y) - r * 0.6;
}

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  vec2 p = (uv - 0.5) * asp;
  vec4 c = getFromColor(uv);
  vec4 b = getToColor(uv);
  float big = 0.5 * length(asp) + 0.06;
  float shortSide = min(ratio, 1.0);
  float longSide = max(ratio, 1.0 / ratio);
  for (int i = 0; i < 7; i++) {
    float f = float(i);
    vec3 s = i == 0 ? vec3(-0.42, 0.14, 0.24) : i == 1 ? vec3(0.36, -0.18, 0.22) : i == 2 ? vec3(0.04, 0.24, 0.28)
      : i == 3 ? vec3(0.62, 0.28, 0.2) : i == 4 ? vec3(-0.56, -0.3, 0.24) : i == 5 ? vec3(0.16, -0.3, 0.3) : vec3(0.0, 0.0, big);
    // the layout is drawn for a landscape frame and turned a quarter for a portrait one
    vec2 o = s.xy * vec2(longSide / 1.78, 1.0) * shortSide;
    o = ratio < 1.0 ? o.yx : o;
    float size = i == 6 ? big : s.z * shortSide;
    float kind = mod(f, 3.0);
    bool last = i == 6;
    float start = last ? 0.6 : 0.1 * f;
    float l = last ? 0.5 * lag : lag;
    float dur = last ? 0.4 - l : 0.26;
    float spin = (mod(f, 2.0) * 2.0 - 1.0) * 1.2;
    vec4 col = i == 0 || i == 3 || i == 6 ? color1 : i == 1 || i == 4 ? color2 : color3;
    float e = pop((progress - start) / dur, last);
    float d = shape(p - o, kind, mix(-2.0 * AA, size, e), spin * (1.0 - e));
    c = mix(c, col, 1.0 - smoothstep(-AA, AA, d));
    e = pop((progress - start - l) / dur, last);
    d = shape(p - o, kind, mix(-2.0 * AA, size, e), spin * (1.0 - e));
    c = mix(c, b, 1.0 - smoothstep(-AA, AA, d));
  }
  return c;
}
