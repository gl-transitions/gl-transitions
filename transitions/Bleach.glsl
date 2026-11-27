// Author: gre
// License: MIT
// Description: Bleach is splashed on the outgoing image like on a dark T-shirt: two ragged stains spread from the splashes, running fast through the image's dark areas and slowly through its light ones, the dye lifting at their edges to a soft rusty orange, then to cream, and the incoming image comes up from the cream until the stains cover the frame
// Tags: liquid, fabric, organic, luma

// @range(0, 1) How much the light areas of the outgoing image hold the bleach back
uniform float hold; // = 0.8
// @range(0, 1) How strong the rust and cream tones are (0 reveals the incoming image right at the stain's edge)
uniform float rings; // = 1.0
// @color Tone the dye lifts to first
uniform vec4 rust; // = vec4(0.96, 0.56, 0.3, 1.0)
// @color Tone the dye lifts to last
uniform vec4 cream; // = vec4(1.0, 0.93, 0.8, 1.0)

const int N = 12;
const float W = 0.3;

float hash(vec2 p) {
  vec3 q = fract(p.xyx * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

float luma(vec3 c) {
  return dot(c, vec3(0.299, 0.587, 0.114));
}

float pathLight(vec2 S, vec2 P, vec2 R, float g) {
  vec2 side = 0.012 * normalize(vec2(S.y - P.y, P.x - S.x) + 1e-5);
  float s = 0.0;
  for (int k = 0; k < N; k++) {
    float t = (float(k) + 0.5) / float(N);
    // alternating side offsets blur the spokes the straight paths would draw
    vec2 Q = mix(S, P, t) + side * (mod(float(k), 2.0) - 0.5) * t;
    vec4 c = getFromColor(clamp(Q / R, 0.0, 1.0));
    s += mix(g, luma(c.rgb), c.a);
  }
  return s / float(N);
}

float nearest(vec2 c, vec2 S1, vec2 S2) {
  return min(length(c - S1), length(c - S2));
}

float arrival(vec2 P, vec2 S, vec2 R, float F, float g, float seed) {
  vec2 d = P - S;
  float r = length(d) * (0.88 + 0.24 * noise(normalize(d + 1e-5) * 3.0 + seed));
  float n = clamp(r / F, 1e-4, 1.0);
  float x = clamp(pathLight(S, P, R, g) - g, -0.5, 0.5);
  // the power keeps arrivals in 0..1 and is eased in near the splash so both stains start at once
  return mix(n, pow(n, exp(-2.5 * hold * x)), min(4.0 * n, 1.0));
}

vec4 transition(vec2 uv) {
  vec2 R = vec2(ratio, 1.0);
  vec2 P = uv * R;
  vec2 S1 = vec2(0.32, 0.62) * R;
  vec2 S2 = vec2(0.7, 0.34) * R;
  float g = 0.0;
  for (int k = 0; k < 9; k++) {
    vec2 c = (vec2(mod(float(k), 3.0), floor(float(k) / 3.0)) + 0.5) / 3.0;
    g += luma(getFromColor(c).rgb);
  }
  g /= 9.0;
  float F = 1.12 * max(max(nearest(vec2(0.0), S1, S2), nearest(R, S1, S2)), max(nearest(vec2(0.0, 1.0), S1, S2), nearest(vec2(ratio, 0.0), S1, S2)));
  float A = min(arrival(P, S1, R, F, g, 2.0), arrival(P, S2, R, F, g, 7.0));
  A = clamp(A + 0.02 * (noise(P * 22.0) + 0.5 * noise(P * 55.0) - 0.75), 0.0, 1.0);
  // remaps arrivals to an even stained area per frame, the linear floor lets the splashes grow from nothing
  A = max(smoothstep(0.03, 0.78, A), 0.25 * A);

  float behind = progress * (1.0 + W + 0.1) - 0.03 - A;
  float mottle = noise(P * 9.0 + 4.0) - 0.5;

  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float l = luma(a.rgb);
  float lift = smoothstep(-0.026, 0.01, behind) * rings;
  float pale = smoothstep(0.01, 0.12, behind + 0.04 * mottle);
  float o = smoothstep(0.1, W, behind + 0.04 * mottle);
  vec3 tone = mix(rust.rgb * (0.78 + 0.3 * l), cream.rgb * (0.84 + 0.2 * l), pale);
  tone = mix(a.rgb, tone, mix(rust.a, cream.a, pale));
  // lifting dye only ever lightens the fabric, so the stain's edge cannot darken into a scorch
  vec3 col = mix(a.rgb, tone, lift * smoothstep(-0.1, 0.05, luma(tone) - l));
  col = mix(col, b.rgb, o);
  return vec4(col, mix(a.a, b.a, o));
}
