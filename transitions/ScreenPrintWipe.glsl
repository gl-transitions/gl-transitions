// Author: gre
// License: MIT
// Description: A squeegee sweeps back and forth across the frame four times, pushing a bead of ink ahead of its blade and printing the incoming image one halftone ink at a time, yellow, magenta, cyan then black, slightly out of register and streaky, until the layers settle into register and the dots melt into the full picture
// Tags: print, ink, halftone, cmyk, squeegee, wipe

// @range(30, 160) Number of halftone dots across the frame height: more makes a finer screen, which can shimmer at small sizes
uniform float dots; // = 70.0
// @range(0, 0.03) How far the ink layers are printed out of register, in frame heights
uniform float misregistration; // = 0.01
// @range(0, 1) Amount of ink texture: squeegee streaks and ink-starved specks
uniform float grit; // = 0.5

const float PI = 3.141592653589793;
// the four passes end here, then the layers settle into register and the dots melt into the picture
const float PRINTED = 0.8;
// share of black taken out of the three colors (an exact separation, whatever the amount)
const float BLACK = 0.6;
// widths across the squeegee, in frame heights: bead of ink ahead of the blade, rubber blade, holder behind it
const float BEAD = 0.03;
const float RUBBER = 0.009;
const float HOLDER = 0.075;
const float SHADOW = 0.018;
const float SHADOW_SOFT = 0.02;
const float AA = 0.0015;

float spHash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float spNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(spHash(i), spHash(i + vec2(1.0, 0.0)), f.x),
    mix(spHash(i + vec2(0.0, 1.0)), spHash(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

// mirrored coordinates, so that a shifted lookup never smears the frame's border
vec2 spMirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// amount of ink of pass i (yellow, magenta, cyan, black) separating the color c
float separation(vec3 c, float i) {
  float k = BLACK * (1.0 - max(max(c.r, c.g), c.b));
  if (i > 2.5) return k;
  float channel = i < 0.5 ? c.b : (i < 1.5 ? c.g : c.r);
  return clamp((1.0 - channel - k) / (1.0 - k), 0.0, 1.0);
}

vec3 inkFilter(float i) {
  if (i < 0.5) return vec3(1.0, 1.0, 0.0);
  if (i < 1.5) return vec3(1.0, 0.0, 1.0);
  if (i < 2.5) return vec3(0.0, 1.0, 1.0);
  return vec3(0.0);
}

vec3 inkColor(float i) {
  if (i < 0.5) return vec3(1.0, 0.84, 0.05);
  if (i < 1.5) return vec3(0.86, 0.06, 0.48);
  if (i < 2.5) return vec3(0.0, 0.58, 0.86);
  return vec3(0.07, 0.07, 0.08);
}

vec4 transition(vec2 uv) {
  vec2 aspect = vec2(ratio, 1.0);
  vec2 p = (uv - 0.5) * aspect;
  float settle = smoothstep(PRINTED, 1.0, progress);
  float rough = clamp(grit, 0.0, 1.0) * (1.0 - settle);
  float cells = max(dots, 1.0);

  vec4 from = getFromColor(uv);
  vec4 to = getToColor(uv);
  vec3 col = from.rgb;
  float alpha = from.a;
  float shade = 1.0;
  vec4 tool = vec4(0.0);

  for (int n = 0; n < 4; n++) {
    float i = float(n);
    float t = clamp((progress - i * PRINTED / 4.0) / (PRINTED / 4.0), 0.0, 1.0);
    // the passes run one after another: none of the next ones has started yet
    if (t <= 0.0) break;
    float dir = mod(i, 2.0) < 0.5 ? 1.0 : -1.0;
    float tilt = mod(i, 2.0) < 0.5 ? 0.05 : 0.07;
    float m = dir * p.x + tilt * p.y;
    float extent = 0.5 * ratio + 0.5 * abs(tilt);
    // the squeegee speeds up into the frame and slows down out of it, without stopping: it starts with
    // its bead and shadow just outside the frame, and ends with its holder and shadow just past it
    float e = mix(t, t * t * (3.0 - 2.0 * t), 0.55);
    float front = mix(-extent - 1.15 * BEAD - SHADOW - SHADOW_SOFT, extent + HOLDER + SHADOW + SHADOW_SOFT, e);
    // across the blade: u < 0 ahead of it, u > 0 behind it, v along it
    float u = front - m;
    float v = dir * p.y - tilt * p.x;
    float cover = smoothstep(-AA, AA, u);

    float a = 2.4 * i + 0.7;
    vec2 offset = misregistration * (1.0 - settle) * vec2(cos(a), sin(a)) * (0.6 + 0.4 * mod(i * 3.0, 4.0) / 3.0);
    vec4 s = getToColor(spMirror(uv + offset / aspect));
    float amount = separation(s.rgb, i);
    float streak = spNoise(vec2(v * 90.0, m * 2.0 + i * 13.0));
    streak = smoothstep(0.3, 0.9, streak);
    float speck = step(spHash(floor(p * 260.0) + i * 17.3), 0.07 * rough);
    amount *= 1.0 - rough * (0.3 * streak + speck);
    float ga = radians(i < 0.5 ? 0.0 : (i < 1.5 ? 75.0 : (i < 2.5 ? 15.0 : 45.0)));
    vec2 g = mat2(cos(ga), sin(ga), -sin(ga), cos(ga)) * p * cells;
    // a dot grows from each cell's center (and a hole shrinks at its corners past half): the ink covers
    // the part of the cell where the spot is below the level whose area matches the amount of ink
    vec2 cell = 2.0 * PI * fract(g);
    float spot = 0.5 - 0.25 * (cos(cell.x) + cos(cell.y));
    float d = 1.0 - 2.0 * amount;
    float level = 0.5 - 0.5 * sign(d) * pow(abs(d), 1.5);
    float w = 0.16;
    float dotted = smoothstep(-w, w, level * (1.0 + 2.0 * w) - w - spot);
    float c = mix(dotted, amount, settle) * mix(s.a, 1.0, settle);
    vec3 ink = 1.0 - c * (1.0 - inkFilter(i));
    float wet = (1.0 - smoothstep(0.75, 1.0, t)) * exp(-max(u, 0.0) / 0.1) * cover * c;
    ink *= 1.0 - 0.12 * wet;
    vec3 printed = (n == 0 ? vec3(1.0) : col) * ink + 0.06 * wet * streak;
    col = mix(col, printed, cover);
    if (n == 0) alpha = mix(from.a, to.a, cover);

    if (t > 0.0 && t < 1.0) {
      float us = u + dir * SHADOW;
      shade *= 1.0 - 0.35 * smoothstep(-BEAD - SHADOW_SOFT, -BEAD + SHADOW_SOFT, us)
        * (1.0 - smoothstep(HOLDER - SHADOW_SOFT, HOLDER + SHADOW_SOFT, us));
      float bead = BEAD * (0.55 + 0.6 * spNoise(vec2(v * 7.0, i * 5.0)));
      float bx = clamp((u + 0.5 * bead) / (0.5 * bead), -1.0, 1.0);
      float bz = sqrt(1.0 - bx * bx);
      float beadMask = smoothstep(-bead - AA, -bead + AA, u) * (1.0 - smoothstep(-AA, AA, u));
      vec3 bc = inkColor(i) * (0.45 + 0.55 * bz) * (0.92 + 0.16 * spNoise(vec2(v * 30.0, u * 120.0)));
      bc += 0.35 * pow(smoothstep(0.75, 1.0, bz), 3.0) * (0.6 + 0.4 * spNoise(vec2(v * 40.0, i)));
      float rubber = smoothstep(-AA, AA, u) * (1.0 - smoothstep(RUBBER - AA, RUBBER + AA, u));
      float holder = smoothstep(RUBBER - AA, RUBBER + AA, u) * (1.0 - smoothstep(HOLDER - AA, HOLDER + AA, u));
      float hx = clamp((u - RUBBER) / (HOLDER - RUBBER) * 2.0 - 1.0, -1.0, 1.0);
      vec3 metal = vec3(0.62, 0.64, 0.67) * (0.55 + 0.45 * sqrt(1.0 - hx * hx));
      metal += 0.3 * (1.0 - smoothstep(0.0, 0.15, abs(hx + 0.35 * dir)));
      metal *= 1.0 - 0.5 * smoothstep(0.8, 1.0, abs(hx));
      vec3 rc = vec3(0.1, 0.11, 0.12) + 0.12 * (1.0 - smoothstep(0.0, 0.004, abs(u - 0.0025)));
      // (the squeegee only tints the print: over a transparent image, it adds no alpha)
      tool = vec4(beadMask * bc + rubber * rc + holder * metal, beadMask + rubber + holder);
    }
  }
  col = col * shade * (1.0 - tool.a) + tool.rgb;
  return vec4(col, alpha);
}
