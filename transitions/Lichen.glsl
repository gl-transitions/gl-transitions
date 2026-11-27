// Author: gre
// License: MIT
// Description: Lichen colonizes the outgoing picture like a rock in time-lapse: lobed rosettes of pale sage and orange crust start at scattered spots and creep outward, with a paler growing margin, radial lobes and tiny fruiting cups; behind the margin the old crust flakes away in islands onto the incoming picture, until the colonies meet and the last of the crust falls off
// Tags: nature, organic, growth, reveal

// @range(1.5, 6) Lichen colonies across the frame height
uniform float colonies; // = 3.0
// @color Crust of most colonies
uniform vec4 lichenColor; // = vec4(0.74, 0.8, 0.62, 1.0)
// @color Crust of the orange colonies and the fruiting cups
uniform vec4 accentColor; // = vec4(0.94, 0.64, 0.2, 1.0)

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec4 transition(vec2 uv) {
  vec2 g = uv * vec2(ratio, 1.0) * colonies;
  vec2 c = floor(g);
  float A = 9.0;
  float R = 0.0;
  float cid = 0.0;
  vec2 dirw = vec2(1.0, 0.0);
  for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
      vec2 id = c + vec2(float(i), float(j));
      vec2 d = g - id - 0.2 - 0.6 * vec2(hash(id), hash(id + 17.3));
      float r = length(d);
      vec2 dir = d / max(r, 1e-4);
      float lobes = 0.65 * noise(dir * 2.5 + id * 3.1) + 0.35 * noise(dir * 6.0 + id * 5.7);
      float rr = r / (0.7 + 0.6 * lobes);
      float a = 0.3 * hash(id + 5.1) + rr;
      if (a < A) {
        A = a;
        R = rr;
        cid = hash(id.yx * 1.37 + 9.7);
        dirw = dir;
      }
    }
  // squaring starts the colonies fast; squeezing the late arrivals closes the last gaps without a tail
  A *= A;
  float late = max(A - 0.45, 0.0);
  A = min(A, 0.45) + late / (1.0 + 8.0 * late);
  float crust = noise(g * 22.0);

  const float AMAX = 0.61;
  A = min(0.03 + A + 0.03 * (crust - 0.5), AMAX);
  const float W = 0.26;
  // faster at both ends so the first spots and the last flakes do not linger
  float age = (AMAX + 0.25 * W + 0.01) * (progress + 0.035 * sin(6.2831853 * progress)) - A;

  vec4 from = getFromColor(uv);
  vec4 to = getToColor(uv);

  float lag = W * (1.0 - 0.75 * A / AMAX);
  float k = age / lag;
  float orange = step(0.68, cid);
  vec4 base = mix(lichenColor, accentColor, orange);
  float streak = noise(dirw * 16.0 + vec2(R * 2.5, cid * 40.0));
  float crevice = 1.0 - smoothstep(0.03, 0.12, abs(streak - 0.5));
  float tex = (0.8 + 0.28 * streak + 0.12 * crust) * (1.0 - 0.18 * crevice);
  vec3 thallus = base.rgb * (0.62 + 0.45 * dot(from.rgb, vec3(0.3, 0.55, 0.15))) * tex;
  float margin = 1.0 - smoothstep(0.01, 0.045, age);
  thallus = mix(thallus, min(base.rgb * 1.3, 1.0) * (0.85 + 0.2 * crust), 0.6 * margin);

  vec2 ac = g * 9.0;
  vec2 ai = floor(ac);
  float cd = length(ac - ai - 0.25 - 0.5 * vec2(hash(ai + 3.3), hash(ai + 8.1)));
  float cupR = 0.1 + 0.1 * hash(ai + 1.7);
  float cup = (1.0 - smoothstep(cupR - 0.04, cupR, cd)) * step(hash(ai), 0.3) * smoothstep(0.03, 0.06, age);
  thallus = mix(thallus, mix(accentColor.rgb, accentColor.rgb * accentColor.rgb, orange) * mix(0.65, 1.1, smoothstep(cupR - 0.08, cupR - 0.03, cd)), cup);

  // the old crust thins into islands that shade the incoming picture around them
  float f = 1.4 * k - 0.25 - noise(g * 10.0 + 7.0);
  float flake = 1.0 - smoothstep(-0.08, 0.08, f);
  vec3 under = to.rgb * (1.0 - 0.22 * (1.0 - smoothstep(0.08, 0.3, f)) * (1.0 - smoothstep(0.7, 1.0, k)));
  vec3 col = mix(under, thallus, flake);

  float lichen = smoothstep(0.0, 0.012, age);
  float shadow = smoothstep(-0.012, 0.0, age) * (1.0 - lichen);
  return mix(vec4(from.rgb * (1.0 - 0.3 * shadow), from.a), vec4(col, mix(to.a, base.a * max(from.a, to.a), flake)), lichen);
}
