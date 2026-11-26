// Author: gre
// License: MIT
// Description: The outgoing picture turns into a blueprint, white outlines on deep blue drafting paper with a faint grid; its lines are erased patch by patch while the incoming picture's outlines are drafted in, then the incoming picture develops in full color out of its own plan
// Tags: drawing, edges, blueprint, sketch, dissolve

// @range(0.5, 3) Thickness of the drawn lines
uniform float lineWidth; // = 1.2
// @range(0, 1) Visibility of the drafting grid
uniform float grid; // = 0.35
// @color Color of the drafting paper
uniform vec4 paper; // = vec4(0.11, 0.28, 0.56, 1.0)
// @color Color of the drawn lines
uniform vec4 ink; // = vec4(0.92, 0.96, 1.0, 1.0)

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x),
    f.y
  );
}

float luma(vec4 c) {
  return dot(c.rgb, vec3(0.299, 0.587, 0.114));
}

float edge(vec4 xp, vec4 xm, vec4 yp, vec4 ym) {
  return smoothstep(0.05, 0.18, length(vec2(luma(xp) - luma(xm), luma(yp) - luma(ym))));
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 q = uv * vec2(ratio, 1.0);
  vec2 e = vec2(0.0025 / ratio, 0.0025) * lineWidth;
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float n = noise(q * 6.0) * 0.8 + 0.2 * noise(q * 23.0);
  float erase = smoothstep(0.0, 0.08, n - (p - 0.3) * 4.0 + 0.2);
  float draw = smoothstep(0.0, 0.08, (p - 0.35) * 4.0 - n + 0.2);
  vec2 ex = vec2(e.x, 0.0);
  vec2 ey = vec2(0.0, e.y);
  float lineA = edge(getFromColor(uv + ex), getFromColor(uv - ex), getFromColor(uv + ey), getFromColor(uv - ey));
  float lineB = edge(getToColor(uv + ex), getToColor(uv - ex), getToColor(uv + ey), getToColor(uv - ey));
  float lines = max(lineA * erase, lineB * draw);
  vec2 g = abs(fract(q * 16.0) - 0.5);
  float gridLine = smoothstep(0.44, 0.48, max(g.x, g.y)) * grid;
  float tone = mix(luma(a), luma(b), smoothstep(0.35, 0.65, p));
  vec4 bp = vec4(paper.rgb * (0.8 + 0.35 * tone), paper.a);
  bp.rgb *= 1.0 - 0.6 * gridLine;
  bp = mix(bp, ink, lines * ink.a);
  float inA = smoothstep(0.0, 0.25, p);
  float outB = smoothstep(0.75, 1.0, p);
  return mix(mix(a, bp, inA), b, outB);
}
