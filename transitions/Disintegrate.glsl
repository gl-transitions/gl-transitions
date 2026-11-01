// Author: gre
// License: MIT
// Description: The outgoing image crumbles into fine dust from one side, its grains blown away by the wind and fading out, revealing the incoming image underneath
// Tags: particles, dust, wind, directional

// @range(0.0075, 0.03) Size of the dust grains, in frame heights
uniform float particleSize; // = 0.008
// @param Direction in which the wind blows the dust
uniform vec2 direction; // = vec2(1.0, -0.15)
// @range(0, 1) How far the dust flies and scatters before it fades out
uniform float spread; // = 0.75

// the grains a pixel looks back to, along the wind: every grain up to 16 cells away,
// one in 2 up to 32 cells, one in 4 up to 64 cells (only those stay visible that far,
// so the dust thins out as it flies): 35 candidates, without unrolling a long loop
const int NEAR = 17;
const int CANDIDATES = 35;
// part of the transition during which a grain flies, from its release to its fade-out
const float LIFE = 0.45;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// smooth value noise, between -1 and 1
float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));
  return 2.0 * mix(mix(a, b, f.x), mix(c, d, f.x), f.y) - 1.0;
}

// the grains' sideways drift, in gusts along the wind, between -1 and 1: it depends only
// on where a grain comes from along the wind, so that a pixel knows which row to look in
float gust(float x) {
  float i = floor(x);
  float f = fract(x);
  f = f * f * (3.0 - 2.0 * f);
  return 2.0 * mix(hash12(vec2(i, 7.0)), hash12(vec2(i + 1.0, 7.0)), f) - 1.0;
}

// when the grain at this center (in cells) is released, from the downwind side first,
// along a ragged front
float release(vec2 center, float h, float halfLength, float s) {
  float front = 1.0 - (center.x + halfLength) / (2.0 * halfLength) + 0.14 * noise(center * s * 6.0) + 0.08 * (h - 0.5);
  return clamp((front + 0.12) / 1.24, 0.0, 1.0) * (1.0 - LIFE);
}

vec4 transition(vec2 uv) {
  vec2 d = length(direction) > 0.0 ? normalize(direction) : vec2(1.0, 0.0);
  vec2 n = vec2(-d.y, d.x);
  // grid of grains aligned with the wind: x along it, y across it, in cells
  vec2 fp = (uv - 0.5) * vec2(ratio, 1.0);
  float s = particleSize;
  vec2 g = vec2(dot(fp, d), dot(fp, n)) / s;
  float halfLength = 0.5 * (ratio * abs(d.x) + abs(d.y)) / s;
  // the longest flight, in cells (at most 60, within the 64 cells looked back to)
  float reach = min(spread * 0.45 / s, 60.0);
  float px = floor(g.x);

  // this pixel's own grain: once it has left, the incoming image shows through
  vec2 own = floor(g);
  vec4 under = progress > release(own + 0.5, hash12(own), halfLength, s) ? getToColor(uv) : getFromColor(uv);
  vec2 grainUV = vec2(0.5);
  float cover = 0.0;
  for (int i = 0; i < CANDIDATES; i++) {
    // the column of the candidate grain
    float fi = float(i);
    float cx = px - fi;
    if (i >= NEAR + 9) {
      cx = floor(px / 4.0) * 4.0 - 4.0 * (fi - float(NEAR + 9) + 8.0);
    } else if (i >= NEAR) {
      cx = floor(px / 2.0) * 2.0 - 2.0 * (fi - float(NEAR) + 8.0);
    }
    // how far the grain stays visible (in cells): further when its column is a multiple
    // of 2, and of 4, as far as the pixels look back to
    float visible = mod(cx, 4.0) < 0.5 ? 63.0 : mod(cx, 2.0) < 0.5 ? 31.0 : 15.0;
    float drift = 0.3 * gust(cx * s * 4.0);
    // the row the grain comes from: its sideways drift is known from its column and how
    // far it has flown to get here
    vec2 cell = vec2(cx, floor(g.y - drift * (g.x - cx - 0.5)));
    vec2 center = cell + 0.5;
    vec2 cuv = (center.x * d + center.y * n) * s / vec2(ratio, 1.0) + 0.5;
    if (cuv.x < 0.0 || cuv.x > 1.0 || cuv.y < 0.0 || cuv.y > 1.0) continue;
    float h = hash12(cell);
    float t = (progress - release(center, h, halfLength, s)) / LIFE;
    if (t <= 0.0 || t >= 1.0) continue;
    float r2 = fract(h * 13.7);
    // the grain speeds up, drifts sideways, shrinks and fades out
    float travel = reach * (0.4 + 0.6 * r2) * t * (0.2 + 0.8 * t);
    // it first fills its cell, then crumbles to a smaller speck
    float crumble = smoothstep(0.0, 0.25, t);
    vec2 pos = center + vec2(travel + (fract(h * 71.1) - 0.5) * 0.3 * crumble, drift * travel);
    vec2 local = abs(g - pos);
    float size = mix(0.5, 0.3 * (1.0 - 0.5 * t) * (0.6 + 0.4 * h), crumble);
    float feather = 0.001 + 0.12 * crumble;
    float a = (1.0 - smoothstep(size - feather, size, max(local.x, local.y))) * (1.0 - smoothstep(0.15, 1.0, t))
      * (1.0 - smoothstep(0.6 * visible, visible, travel));
    if (a > cover) {
      cover = a;
      grainUV = cuv;
    }
  }
  return mix(under, getFromColor(grainUV), cover);
}
