// Author: gre
// License: MIT
// Description: Ice crystals grow in from the edges of the frame with feathery, branching fronts, frosting the outgoing image white and blurry until it is covered, then thaw back out to the edges on the incoming image
// Tags: frost, ice, crystal, blur, cover

// @range(0, 1) How far the crystal fingers reach ahead of the frost
uniform float spread; // = 0.5
// @range(2, 12) Size of the crystals: more, smaller ones with a larger value
uniform float scale; // = 5.0
// @range(0, 1) How much the frost blurs the image under it
uniform float blur; // = 0.5
// @color Color of the frost
uniform vec4 color; // = vec4(0.86, 0.93, 1.0, 1.0)

const int TAPS = 12;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

float vnoise(vec2 v) {
  vec2 i = floor(v);
  vec2 f = fract(v);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
    mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

// ridged noise: thin bright veins where the noise crosses its middle, like crystal ferns
float ridged(vec2 v) {
  float sum = 0.0;
  float amp = 0.5;
  for (int i = 0; i < 4; i++) {
    float n = 1.0 - abs(2.0 * vnoise(v) - 1.0);
    sum += amp * n * n;
    v = mat2(1.6, 1.2, -1.2, 1.6) * v + 4.7;
    amp *= 0.5;
  }
  return sum / 0.9375;
}

// crystal grains, cells of size 1: x is how far from the boundary between two grains
// (0 on it, where the crystals start), y a random number for the grain, zw the position
// relative to the grain's seed
vec4 grains(vec2 v) {
  vec2 i = floor(v);
  vec2 f = fract(v);
  float d1 = 8.0;
  float d2 = 8.0;
  vec3 seed = vec3(0.0);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 c = vec2(float(x), float(y));
      vec2 o = c + vec2(hash12(i + c), hash12(i + c + 17.3)) - f;
      float d = dot(o, o);
      if (d < d1) {
        d2 = d1;
        d1 = d;
        seed = vec3(hash12(i + c + 41.9), -o);
      } else if (d < d2) {
        d2 = d;
      }
    }
  }
  return vec4(sqrt(d2) - sqrt(d1), seed);
}

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// the image under the frost: the outgoing one, then the incoming one, switched under full cover
vec4 image(vec2 uv, float m) {
  if (m <= 0.0) return getFromColor(uv);
  if (m >= 1.0) return getToColor(uv);
  return mix(getFromColor(uv), getToColor(uv), m);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // 0 at both ends, 1 while the frost covers the whole frame (from 0.425 to 0.575)
  float h = 1.0 - abs(2.0 * p - 1.0);
  float a = clamp(h / 0.85, 0.0, 1.0);
  a = a * (1.6 - 0.6 * a); // fast start, slowing down as the frost closes in
  float m = smoothstep(0.47, 0.53, p);
  if (a <= 0.0) return image(uv, m);

  // how deep in the frame the pixel is: 0 on the edges, 1 at the center
  vec2 q = uv * vec2(ratio, 1.0);
  vec2 dEdge = min(uv, 1.0 - uv) * vec2(ratio, 1.0);
  float depth = min(dEdge.x, dEdge.y) / (0.5 * min(ratio, 1.0));
  depth = 1.0 - (1.0 - depth) * (1.0 - depth); // the covered area grows evenly

  // the front, which moves from the edges past the deepest point; the crystals below only
  // hold it back, so nothing is frosted (yet, or any more) deeper than it
  float reach = 0.2 + 0.6 * clamp(spread, 0.0, 1.0);
  float front = mix(-0.1, 1.0 + reach + 0.2, a);
  if (depth > front + 0.08) return image(uv, m);

  // crystals: ferns grow from the boundaries between grains, with parallel needles shooting
  // off them at an angle that changes from grain to grain
  vec2 gv = q * scale;
  // the stems bend a little
  vec4 gr = grains(gv + 0.35 * vec2(vnoise(gv * 1.7), vnoise(gv * 1.7 + 23.1)));
  // the needles' direction, any angle (a rational point on the unit circle)
  float u = 2.0 * gr.y - 1.0;
  vec2 dir = vec2(1.0 - u * u, 2.0 * u) / (1.0 + u * u);
  float t = dot(gr.zw, dir) * 7.0;
  float needle = 1.0 - abs(2.0 * fract(t) - 1.0); // 1 along each needle, 0 between them
  float nh = fract(gr.y + 0.618034 * floor(t));
  float len = mix(0.15, 0.6, nh); // each needle has its own length
  float r = ridged(gv * 1.3);
  float rf = ridged(gv * 4.0 + 11.0);
  // when the frost reaches the pixel, after the edges: the stems first, then the needles, then
  // the gaps between them
  float grow = min(gr.x * 3.5, gr.x / len * 0.5 + (1.0 - needle) * 1.2 + 0.2 * fract(nh * 13.7));
  float field = depth + reach * (0.8 * min(grow, 1.0) + 0.2 * (1.0 - r)) + 0.1 * (1.0 - rf);
  float inside = front - field; // > 0 under the frost
  float f = smoothstep(0.0, 0.03, inside);
  // a thin, faint haze of fine crystals just ahead of the front
  float haze = 0.4 * smoothstep(0.9, 1.0, rf) * smoothstep(-0.08, 0.0, inside);
  float frost = max(f, haze);
  if (frost <= 0.0) return image(uv, m);

  // thicker ice close to the edges, where it started growing
  float thick = smoothstep(0.0, 0.5, inside);
  float full = smoothstep(0.75, 0.95, h); // the frost turns opaque to hide the switch

  // frosted glass: blur over a small jittered disc, scattered along the crystals
  float radius = (0.004 + 0.03 * blur) * frost * (0.5 + 0.5 * thick);
  float rot = 6.2831853 * hash12(floor(q * 90.0));
  vec3 rgb = vec3(0.0);
  float alpha = 0.0;
  for (int i = 0; i < TAPS; i++) {
    float k = (float(i) + 0.5) / float(TAPS);
    float th = rot + float(i) * 2.3999632;
    vec2 off = sqrt(k) * vec2(cos(th), sin(th)) * radius;
    vec4 c = image(mirror(uv + off / vec2(ratio, 1.0)), m);
    rgb += c.rgb * c.a;
    alpha += c.a;
  }
  alpha /= float(TAPS);
  rgb = alpha > 0.0 ? rgb / (alpha * float(TAPS)) : vec3(0.0);

  // a cool white crystal tint, brighter on the stems, the needles (fading out toward their tips)
  // and the growing front
  float stem = 1.0 - smoothstep(0.0, 0.03, gr.x);
  float needles = smoothstep(0.7, 1.0, needle) * (1.0 - smoothstep(0.0, len, gr.x));
  float glint = 0.4 + 0.6 * rf;
  float veins = clamp(glint * max(0.35 * stem, 0.55 * needles) + 0.3 * smoothstep(0.6, 0.95, r), 0.0, 1.0);
  float rim = smoothstep(0.0, 0.02, inside) * (1.0 - smoothstep(0.02, 0.07, inside));
  vec3 ice = clamp(color.rgb * (0.82 + 0.25 * veins), 0.0, 1.0);
  float cover = frost * (0.35 + 0.3 * thick + 0.25 * veins);
  cover = clamp(mix(cover, frost, full), 0.0, 1.0);
  vec4 under = vec4(rgb * mix(vec3(1.0), color.rgb, 0.5 * frost), alpha);
  // the frost color mixes as straight RGBA, like every fill color
  vec4 res = mix(under, vec4(ice, color.a), cover);

  // fine sparkles on the ice, twinkling as it grows
  vec2 sq = q * 36.0;
  vec2 cell = floor(sq);
  vec2 d = abs(sq - cell - 0.25 - 0.5 * vec2(hash12(cell + 1.3), hash12(cell + 5.9)));
  float star = max(0.0, 1.0 - 9.0 * length(d)) + max(0.0, 1.0 - 4.0 * (d.x + d.y) - 30.0 * min(d.x, d.y));
  float tw = 0.5 + 0.5 * sin(6.2831853 * (hash12(cell + 9.1) + 2.0 * p));
  float sparkle = step(0.82, hash12(cell + 3.7)) * min(star, 1.0) * tw * f * (0.4 + 0.6 * veins);
  float light = clamp(0.4 * rim + 0.8 * sparkle, 0.0, 1.0);
  res = mix(res, vec4(mix(color.rgb, vec3(1.0), 0.6), color.a), light);
  return clamp(res, 0.0, 1.0);
}
