// Author: gre
// License: MIT
// Description: The outgoing image is washed off into wet paper, then the incoming one is painted in watercolor: pale washes spread first, blooming where the paint is still wet and drying with darker edges and grainy pigment, then deeper glazes go on, darkest tones first, until the picture is complete
// Tags: watercolor, paint, paper, organic, dissolve

// @range(0, 1) How dark the edges of the washes dry, where the pigment gathers
uniform float edges; // = 0.6
// @range(0, 1) Amount of blooms: lighter flowers of paint with frilly dark edges, where water runs back into a wet wash
uniform float blooms; // = 0.5
// @range(0, 1) How much the pigment settles into the grain of the paper
uniform float granulation; // = 0.5
// @color Color of the paper
uniform vec4 paper; // = vec4(0.98, 0.96, 0.92, 1.0)

float wcHash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  // (kept in 0..1 before the last product, so that its rounding is the same on every target)
  p3 = fract(p3 + dot(p3, p3.yzx + 33.33));
  return fract((p3.x + p3.y) * p3.z * 37.0);
}

float wcNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(wcHash(i), wcHash(i + vec2(1.0, 0.0)), f.x),
    mix(wcHash(i + vec2(0.0, 1.0)), wcHash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

// 0..1, spread evenly over the range (the sum of the octaves is about normal, around 0.5)
float wcFbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * wcNoise(p);
    p = mat2(1.6, 1.2, -1.2, 1.6) * p + 5.7;
    a *= 0.5;
  }
  float z = (v / 0.9375 - 0.5) / 0.11;
  return 0.5 + 0.5 * z / sqrt(1.0 + z * z);
}

vec2 wcFold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

// a front spreading over the thresholds of a wash: below -margin at the start, above 1 + margin at the end
float wcFront(float start, float dur, float margin) {
  float s = clamp((progress - start) / dur, 0.0, 1.0);
  s = mix(s, s * s * (3.0 - 2.0 * s), 0.5);
  return s * (1.0 + 2.0 * margin) - margin;
}

// dried edge of a wash at depth d inside it: a dark line right at the edge, fading inward over w
float wcRim(float d, float w) {
  float r = 1.0 - smoothstep(0.0, w, d);
  return smoothstep(-0.006, 0.004, d) * r * r;
}

float wcLuma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

vec4 transition(vec2 uv) {
  // the last glaze has covered everything (see d3 below)
  if (progress >= 0.98) return getToColor(uv);
  vec2 q = vec2(uv.x * ratio, uv.y);
  vec2 px = vec2(1.0 / ratio, 1.0);
  vec4 from = getFromColor(uv);

  // paper texture, turned so that the cells of the noise do not line up with the frame
  vec2 gq = mat2(0.8, 0.6, -0.6, 0.8) * q;
  float grain = 0.55 * wcNoise(gq * 120.0) + 0.45 * wcNoise(gq * 50.0 + 3.1);
  float tooth = 0.03 * (grain - 0.5);
  vec2 w = vec2(wcNoise(q * 2.5 + 1.3), wcNoise(q * 2.5 + 8.1)) - 0.5;

  vec4 run = vec4(from.rgb * from.a, from.a);
  for (int i = 0; i < 4; i++) {
    float a = float(i) * 1.570796 + 0.8;
    vec4 f = getFromColor(wcFold(uv + 0.007 * vec2(cos(a), sin(a)) * px));
    run += vec4(f.rgb * f.a, f.a);
  }
  vec3 fromRun = run.a > 0.0 ? run.rgb / run.a : from.rgb;
  float d0 = wcFront(0.0, 0.4, 0.1) - wcFbm(q * 2.8 + 0.9 * w + 11.0);
  float lift = smoothstep(-0.03, 0.06, d0);
  vec3 stain = mix(paper.rgb, paper.rgb * fromRun, 0.12);
  vec3 c = mix(from.rgb, mix(fromRun, stain, smoothstep(0.0, 0.1, d0)), lift);
  c *= 1.0 - 0.18 * wcRim(d0, 0.05) * (1.0 - wcLuma(fromRun)) * lift;
  c *= (1.0 - 0.06 * lift * (1.0 - smoothstep(0.05, 0.4, d0)) * (1.0 - smoothstep(0.35, 0.6, progress))) * (1.0 - 0.05 * (grain - 0.5) * lift);
  float alpha = mix(from.a, paper.a, lift);
  // no wash has started yet (see d1 below)
  if (progress <= 0.07) return vec4(c, alpha);

  // washes carry no detail: they take the colors of the incoming image, blurred (broadly for the
  // first one, less for the second) and a little off its shapes, as painted by hand.
  // Their pigment is as dense as the incoming image is opaque
  vec2 hand = uv + 0.012 * w * px;
  vec4 broad = vec4(0.0);
  vec4 fine = vec4(0.0);
  for (int i = 0; i < 8; i++) {
    float a = float(i) * 0.785398 + 0.3;
    vec4 b = getToColor(wcFold(hand + 0.035 * vec2(cos(a), sin(a)) * px));
    vec4 f = getToColor(wcFold(hand + 0.012 * vec2(-sin(a), cos(a)) * px));
    broad += vec4(b.rgb * b.a, b.a);
    fine += vec4(f.rgb * f.a, f.a);
  }
  vec3 broadC = broad.rgb / max(broad.a, 1e-3);
  vec3 fineC = fine.rgb / max(fine.a, 1e-3);
  broad.a /= 8.0;
  fine.a /= 8.0;
  float pool = wcNoise(q * 4.0 + w * 2.0 + 31.0);

  float d1 = wcFront(0.07, 0.43, 0.12) - wcFbm(q * 3.0 + 1.2 * w + 2.0);
  float cov1 = smoothstep(-0.05, 0.03, d1) * lift;
  float k1 = 0.55 * broad.a;
  vec3 g1 = mix(vec3(1.0), broadC, (0.4 + 0.3 * pool) * broad.a);
  vec2 bq = q / 0.3;
  vec2 bc = floor(bq);
  float frill = 0.5 * wcNoise(q * 14.0) + 0.3 * wcNoise(q * 33.0 + 4.0) + 0.2 * wcNoise(q * 80.0 + 9.0);
  float inBloom = 0.0;
  float bloomRim = 0.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 cell = bc + vec2(float(i), float(j));
      if (wcHash(cell + vec2(17.0, 53.0)) < blooms) {
        vec2 ctr = cell + 0.3 + 0.4 * vec2(wcHash(cell + vec2(3.0, 71.0)), wcHash(cell + vec2(89.0, 9.0)));
        float g = clamp((d1 - 0.08 - 0.2 * wcHash(cell + vec2(5.0, 37.0))) / 0.3, 0.0, 1.0);
        g = 1.0 - (1.0 - g) * (1.0 - g) * (1.0 - g);
        // at most 0.32 * 1.55 < 0.5 cells: a bloom never reaches past the cells next to its own
        float r = g * (0.18 + 0.14 * wcHash(cell + vec2(61.0, 7.0))) * (0.45 + 1.1 * frill);
        float d = r - length(bq - ctr);
        float inside = smoothstep(-0.015, 0.015, d);
        inBloom = max(inBloom, inside * smoothstep(0.0, 0.25, r));
        bloomRim = max(bloomRim, inside * (1.0 - smoothstep(0.0, 0.05, d)) * smoothstep(0.0, 0.1, r));
      }
    }
  }
  g1 = mix(g1, mix(vec3(1.0), g1, 0.55), inBloom);
  g1 *= mix(vec3(1.0), g1 * g1 * 0.9, bloomRim);
  g1 *= mix(vec3(1.0), g1, edges * 0.8 * wcRim(d1, 0.06));

  float t2 = clamp(mix(wcFbm(q * 3.2 - 1.0 * w + 7.0), mix(1.0, wcLuma(fineC), fine.a), 0.55) + tooth, 0.0, 1.0);
  float d2 = wcFront(0.25, 0.42, 0.1) - t2;
  float cov2 = smoothstep(-0.006, 0.004, d2) * cov1;
  vec3 g2 = clamp(mix(vec3(1.0), fineC, (0.75 + 0.2 * (1.0 - pool)) * fine.a) / mix(vec3(1.0), broadC, 0.55 * broad.a), 0.0, 1.0);
  g2 *= mix(vec3(1.0), g2 * g2 * 0.92, edges * wcRim(d2, 0.07));

  vec3 wash = mix(vec3(1.0), g1, cov1) * mix(vec3(1.0), g2, cov2);
  float settle = clamp((grain - 0.5) * 2.0 + 0.5 * (wcNoise(q * 18.0 + 9.0) - 0.5), -0.4, 1.0);
  wash = min(wash * (1.0 - granulation * 0.45 * settle * (1.0 - wcLuma(wash))), 1.0);
  // on paper that is not opaque, the pigment brings its own opacity
  float a1 = alpha + (1.0 - alpha) * clamp(cov1 * k1 + cov2 * 0.35 * fine.a, 0.0, 1.0);
  c = mix(c * wash, wash, (a1 - alpha) / max(a1, 1e-3));
  alpha = a1;

  vec4 to = getToColor(uv);
  float t3 = clamp(mix(wcFbm(q * 3.6 + 0.8 * w + 19.0), mix(1.0, wcLuma(fineC), fine.a), 0.45) + tooth, 0.0, 1.0);
  float d3 = wcFront(0.45, 0.53, 0.1) - t3;
  float cov3 = smoothstep(-0.006, 0.004, d3);
  vec3 last = to.rgb * mix(vec3(1.0), to.rgb * 0.9, edges * 0.7 * wcRim(d3, 0.05));
  return vec4(mix(c, last, cov3), mix(alpha, to.a, cov3));
}
