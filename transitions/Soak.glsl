// Author: gre
// License: MIT
// Description: A drop of water lands on the outgoing image as if it were a sheet of paper: a wet stain with a dark tide line spreads from it, the soaked paper turns see-through and cockles, sags into a bowl under its weight, then tears out in the middle and drops away, and the ragged hole follows the stain out to the edges onto the incoming image
// Tags: physical, paper, water, tear, organic

// @param Where the drop lands
uniform vec2 center; // = vec2(0.45, 0.55)
// @range(0, 1) How see-through the soaked paper gets
uniform float seeThrough; // = 0.3
// @range(0, 1) How deep the wet paper sags before it tears
uniform float sag; // = 0.6

const float TEAR = 0.3;
const float F = 1.6;

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

float ease(float x) {
  x = clamp(x, 0.0, 1.0);
  return x * x * (3.0 - 2.0 * x);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

float bowl(float r, float rr) {
  float s = min(r / rr, 1.0);
  return (1.0 - s * s) * (1.0 - s * s);
}

vec4 transition(vec2 uv) {
  vec2 R = vec2(ratio, 1.0);
  vec2 c = center * R;
  vec2 P = uv * R;
  float far = length(max(c, R - c));
  float p = progress;

  vec2 d = P - c;
  float r = length(d);
  vec2 dir = r > 1e-5 ? d / r : vec2(1.0, 0.0);
  // noise sampled on the direction circle keeps the ragged fronts seamless all around
  float ragW = 1.0 + 0.35 * (noise(dir * 2.2 + 3.1) - 0.5) + 0.12 * (noise(dir * 7.0 + 9.0) - 0.5);
  float ragH = 1.0 + 0.3 * (noise(dir * 2.6 + 5.7) - 0.5) + 0.12 * (noise(dir * 6.0 + 1.3) - 0.5);

  float stain = 1.35 * far * ease(p / 0.7);
  float rw = stain * ragW;
  float th = clamp((p - TEAR) / (1.0 - TEAR), 0.0, 1.0);
  float rh = 1.3 * far * pow(th, 1.3) * ragH;

  float rr = max(0.8 * stain, 1e-3);
  // depth follows the stain's width so the first dimple stays shallow instead of reading as a hole
  float depth = sag * 0.6 * min(rr, 0.5) * ease(p / TEAR) * (1.0 - ease(th / 0.15));
  float droop = sag * 0.3 * ease(th / 0.06) * (1.0 - ease(th / 0.9)) * exp(-max(r - rh, 0.0) / 0.06);
  vec2 S = P;
  for (int i = 0; i < 3; i++) {
    S = c + d * (F + depth * bowl(length(S - c), rr) + droop) / F;
  }
  // outside starts within the hole's antialiased band so the rim covers it
  float outside = clamp((r - rh) * 300.0 + 1.0, 0.0, 1.0);
  float s = min(r / rr, 1.0);
  float z = depth * (1.0 - s * s) * (1.0 - s * s) + droop;
  float slope = 4.0 * depth * s * (1.0 - s * s) / rr + droop / 0.06 * outside;

  vec4 from = getFromColor(mirror(S / R));
  vec4 to = getToColor(uv);
  float wetEdge = rw - length(S - c);
  float wet = clamp(wetEdge * 300.0, 0.0, 1.0);
  float soak = smoothstep(0.0, 0.2, wetEdge);
  vec2 n = S * 14.0;
  float n0 = noise(n);
  float cockle = ((noise(n - vec2(0.3, 0.0)) - n0) - (noise(n - vec2(0.0, 0.3)) - n0)) * 0.7 * soak;
  vec3 paper = from.rgb * (1.0 - 0.18 * wet - 0.1 * soak + cockle);
  paper = mix(paper, to.rgb * 0.85, seeThrough * soak);
  float tide = wetEdge / 0.012;
  paper *= 1.0 - 0.3 * exp(-tide * tide) * wet;
  paper *= clamp(1.0 - 0.8 * z + 0.35 * slope * dot(dir, vec2(-0.6, 0.8)), 0.3, 1.15);
  float rim = (1.0 - smoothstep(0.0, 0.012, r - rh)) * outside * ease(th / 0.02);
  paper = mix(paper, vec3(0.93, 0.91, 0.86), 0.75 * rim);
  vec4 sheet = vec4(paper, mix(from.a, to.a, seeThrough * soak));

  float fall = clamp((p - TEAR) / 0.35, 0.0, 1.0);
  float zp = depth + 6.0 * fall * fall;
  vec2 Sp = c + d * (F + zp) / F;
  float inPlug = clamp((0.16 * ragH * (1.0 - 0.1 * fall) - length(Sp - c)) * 300.0, 0.0, 1.0) * (1.0 - fall);
  vec4 plug = getFromColor(mirror(Sp / R));
  plug = mix(vec4(plug.rgb * 0.72, plug.a), vec4(to.rgb * 0.85, to.a), seeThrough);
  plug.rgb *= (1.0 - 0.8 * depth) * (1.0 - 0.6 * fall);
  vec4 below = mix(to, plug, inPlug * ease(th / 0.02));
  below.rgb *= 1.0 - 0.35 * exp(-max(rh - r, 0.0) / 0.05) * (1.0 - th);

  float hole = clamp((rh - r) * 300.0, 0.0, 1.0);
  return mix(sheet, below, hole);
}
