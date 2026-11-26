// Author: gre
// License: MIT
// Description: Fat marker lines are drawn one after another down the frame, each showing the incoming image in glowing fluorescent ink over a paled outgoing image, darker where lines overlap, until the ink dries into the plain incoming image
// Tags: marker, highlighter, stroke, ink, reveal

// @range(3, 9, 1) Number of highlighter lines drawn down the frame
uniform float lines; // = 5.0
// @range(0, 1) How see-through the marker ink is over the outgoing picture
uniform float transparency; // = 0.55

float h1(float n) {
  float p = fract(n * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

// coverage of one marker line (0..1) and its pooled-ink rim
vec2 stroke(vec2 q, float i, float t) {
  float h = 1.0 / lines;
  float yc = (i + 0.5) * h + (h1(i + 3.0) - 0.5) * 0.12 * h;
  float tilt = (h1(i + 7.0) - 0.5) * 0.03;
  float y = q.y - yc - tilt * (q.x - 0.5 * ratio) - 0.008 * sin(q.x * 3.0 + i * 2.0);
  float half_ = 0.57 * h;
  float edge = abs(y) - half_;
  float aa = 0.0025;
  float band = 1.0 - smoothstep(-aa, aa, edge);
  float x0 = -0.08 + (h1(i + 11.0) - 0.5) * 0.06;
  // starts 2 aa behind its tail so an undrawn line covers nothing
  float front = mix(x0 - 2.0 * aa, ratio + 0.12, t) + 0.35 * y;
  float start = x0 + 0.35 * y;
  float along = smoothstep(start - aa, start + aa, q.x) * (1.0 - smoothstep(front - aa, front + aa, q.x));
  float rim = smoothstep(-0.012, 0.0, edge) + 0.6 * (1.0 - smoothstep(0.0, 0.02, front - q.x));
  return vec2(band * along, clamp(rim, 0.0, 1.0) * band * along);
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  vec2 q = vec2(uv.x * ratio, 1.0 - uv.y);
  float n = lines;
  float draw = progress / 0.72;
  float cover = 0.0;
  float rim = 0.0;
  for (int k = 0; k < 9; k++) {
    float i = float(k);
    if (i >= n) break;
    float t = clamp(draw * n - i * 0.92, 0.0, 1.0);
    t = t * t * (3.0 - 2.0 * t);
    vec2 s = stroke(q, i, t);
    cover += s.x;
    rim = max(rim, s.y);
  }
  float dry = smoothstep(0.7, 1.0, progress);
  float streak = 0.94 + 0.06 * smoothstep(0.2, 0.8, h1(floor(q.y * 260.0) + 0.37));
  float l = dot(b.rgb, vec3(0.299, 0.587, 0.114));
  vec3 glow = clamp((l + (b.rgb - l) * 1.6) * 1.2 + 0.1, 0.0, 1.0);
  vec3 ink = mix(glow * mix(1.0, streak, min(cover, 1.0)) * (1.0 - 0.15 * rim), b.rgb, dry);
  vec3 base = mix(a.rgb, vec3(1.0), (1.0 - 0.6 * transparency) * min(cover, 1.0));
  base = mix(base, vec3(1.0), dry);
  float m = mix(cover, 1.0, dry);
  vec3 tint = m <= 1.0 ? mix(vec3(1.0), ink, m) : ink * mix(vec3(1.0), ink, m - 1.0);
  return vec4(clamp(base * tint, 0.0, 1.0), mix(a.a, b.a, mix(min(cover, 1.0), 1.0, dry)));
}
