// Author: gre
// License: MIT
// Description: Billowing smoke drifts in across the outgoing image, with lit tops, darker folds and wispy edges, and thickens until it covers the frame; as it thins out and drifts away, the incoming image shows through
// Tags: smoke, fog, organic, noise, cover

// @param Direction the smoke drifts toward (it comes in from the opposite side); its length is how far it drifts, in frame heights
uniform vec2 direction; // = vec2(0.5, 0.1)
// @range(1, 8) Size of the billows: more, smaller ones with a larger value
uniform float scale; // = 2.5
// @range(0, 1) How much the smoke rolls in from one side rather than everywhere at once
uniform float spread; // = 0.4
// @range(0.05, 1) Softness of the smoke: wispier, more see-through edges with a larger value
uniform float softness; // = 0.5
// @color Color of the smoke, lit from above
uniform vec4 color; // = vec4(0.86, 0.86, 0.88, 1.0)

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

float fbm(vec2 v) {
  float sum = 0.0;
  float amp = 0.5;
  for (int i = 0; i < 4; i++) {
    sum += amp * vnoise(v);
    v = mat2(1.6, 1.2, -1.2, 1.6) * v + 5.3;
    amp *= 0.5;
  }
  return sum / 0.9375;
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 pos = (uv - 0.5) * vec2(ratio, 1.0);

  // where along the drift the pixel is: 0 on the side the smoke comes from, 1 on the other
  float len = length(direction);
  vec2 dir = len > 1e-4 ? direction / len : vec2(0.0);
  float ext = 0.5 * (abs(dir.x) * ratio + abs(dir.y)) + 1e-4;
  float along = len > 1e-4 ? 0.5 + 0.5 * dot(pos, dir) / ext : 0.5;

  // the smoke rolls in (until 0.45), covers the whole frame, then thins out (from 0.55),
  // each side of the frame in turn
  float arrive = (p / 0.45) * (1.0 + spread) - spread * along;
  float leave = ((p - 0.55) / 0.45) * (1.0 + spread) - spread * along;
  float body = smoothstep(0.0, 1.0, arrive) * (1.0 - smoothstep(0.0, 1.0, leave));
  // the images switch while the smoke is fully dense everywhere
  float m = smoothstep(0.48, 0.52, p);
  // no smoke here (yet, or any more): one image only
  if (body <= 0.0) return m < 0.5 ? getFromColor(uv) : getToColor(uv);

  // billows: noise warped by itself, drifting with the smoke and slowly churning
  vec2 q = (pos - direction * (p - 0.5)) * scale;
  vec2 churn = vec2(0.5 * p, -0.35 * p);
  vec2 warp = vec2(fbm(q + vec2(3.1, 1.7) + churn), fbm(q + vec2(8.3, 2.8) - churn));
  vec2 w = q + 1.1 * (warp - 0.5);
  float n = fbm(w);
  // the billows catch the light from above: brighter where the smoke rises toward it
  // (on the coarse octave only, which shapes them)
  float lit = 0.53 * (vnoise(w) - vnoise(w + vec2(0.0, 0.2)));
  // finer curls that fray the edges into wisps
  float wisp = vnoise(w * 3.3 - 2.0 * churn) - 0.5;

  // density: the billows fill in first, the gaps between them last, and thin out first
  float edge = 2.0 * body - (1.0 - smoothstep(0.1, 0.6, n)) + 1.6 * body * (1.0 - body) * wisp;
  float d = smoothstep(0.0, softness, edge) * mix(0.5, 1.0, smoothstep(0.2, 0.9, body));

  // the image under the smoke: one image, or both mixed (premultiplied) during the switch
  vec4 base;
  if (m <= 0.0) base = getFromColor(uv);
  else if (m >= 1.0) base = getToColor(uv);
  else {
    vec4 a = getFromColor(uv);
    vec4 b = getToColor(uv);
    base = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
    base = base.a > 0.0 ? vec4(base.rgb / base.a, base.a) : vec4(0.0);
  }
  if (d <= 0.0) return base;

  // soft volumetric shading: lit tops, darker folds deep in the smoke, lighter thin wisps
  float shade = 0.92 + 1.3 * lit;
  shade *= mix(0.76, 1.04, smoothstep(0.25, 0.75, n));
  shade = mix(1.0, shade, 0.3 + 0.7 * d);
  vec3 smoke = clamp(color.rgb * shade, 0.0, 1.0);

  // the smoke color mixes as straight RGBA, like every fill color
  return mix(base, vec4(smoke, color.a), d);
}
