// Author: gre
// License: MIT
// Description: Seen from above, an umbrella made of the incoming picture pops open over the outgoing one: a furled star of pleats spins as its ribs spread and stretch the fabric into taut shaded panels with a scalloped hem and a soft shadow, then the canopy rises toward the camera and flattens out to fill the frame
// Tags: umbrella, open, 3d, object, playful

// @range(5, 12) Number of ribs
uniform int ribs; // = 8
// @range(0, 1) Strength of the shading of the fabric and of the shadow
uniform float shading; // = 0.7
// @range(0, 3) Turns in radians while it opens
uniform float spin; // = 1.6
// @color Ferrule and tips of the ribs
uniform vec4 metal; // = vec4(0.8, 0.78, 0.74, 1.0)

const float PI = 3.141592653589793;

vec2 rot(vec2 v, float a) {
  float c = cos(a), s = sin(a);
  return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// point in the frame of its panel: xy along the panel's bisector and across it, z the panel's angle
vec3 panelAt(vec2 q, float n) {
  float th = abs(q.x) + abs(q.y) < 1e-5 ? 0.0 : atan(q.y, q.x);
  float a = floor(th * n / (2.0 * PI) + 0.5) * 2.0 * PI / n;
  return vec3(rot(q, -a), a);
}

// -1 to 1 across a panel, rib to rib: a ratio, exact on the ribs whatever the precision of atan
float across(vec2 l, float n) {
  return clamp(l.y / (max(l.x, 1e-4) * tan(PI / n)), -1.0, 1.0);
}

// distance inside the hem: taut it is the chord between two rib tips, slack it dips toward the center
float hemGap(vec2 l, float u, float R, float sag, float n) {
  float chord = R * cos(PI / n);
  float tilt = 2.0 * chord * sag * u / max(l.x * tan(PI / n), 0.3 * chord * tan(PI / n) + 1e-4);
  return (chord * (1.0 - sag * (1.0 - u * u)) - l.x) / sqrt(1.0 + tilt * tilt);
}

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * asp;
  float n = max(float(ribs), 5.0);

  float o = clamp(progress / 0.46, 0.0, 1.0);
  o *= sqrt(o);
  // eases past the open radius and settles back
  float pop = 1.0 + (o - 1.0) * (o - 1.0) * (2.4 * (o - 1.0) + 1.4);
  float v = clamp((progress - 0.34) / 0.66, 0.0, 1.0);
  float rise = v * v * (3.0 - 2.0 * v);
  float g = smoothstep(0.3, 1.0, v);
  float dome = 1.0 - g;
  float size = min(ratio, 1.0);
  float k = 0.42 * size;
  float rEnd = 0.54 * length(asp) / cos(PI / n);
  float R = mix(k * pop, rEnd, rise * rise);
  float sag = mix(mix(0.75, 0.09, smoothstep(0.15, 0.9, pop)), 0.0, g);
  float turn = spin * ((1.0 - o) * (1.0 - o) - 0.12 * v * sin(2.0 * PI * v) * dome);

  vec2 qc = rot(q, turn);
  vec3 panel = panelAt(qc, n);
  vec2 l = panel.xy;
  float u = across(l, n);
  float X = R * cos(PI / n) * (1.0 - sag * (1.0 - u * u));
  float e = hemGap(l, u, R, sag, n);
  // under a pixel of fabric there is no canopy yet
  float cov = smoothstep(-0.002, 0.002, e) * smoothstep(0.0, 0.01, R);

  float height = (0.4 + rise) * dome;
  vec3 sp = panelAt(rot(q - vec2(0.04, -0.06) * height * size, turn), n);
  float se = hemGap(sp.xy, across(sp.xy, n), R, sag, n);
  float soft = (0.015 + 0.05 * height) * size;
  float shadow = 0.55 * shading * dome * smoothstep(0.0, 0.15 * size, R) * smoothstep(-soft, soft, se);

  float rho = clamp(l.x / max(X, 1e-3), 0.0, 1.0);
  float bulge = 1.0 - 0.16 * (1.0 - rho * rho);
  // soft max with 1: the picture never grows past its final size
  float over = 1.1 * k / max(R, 1e-3) - 1.0;
  over = 0.5 * (over + sqrt(over * over + 0.01));
  vec2 tuv = 0.5 + qc * mix((1.0 + over) * bulge, 1.0, g) / asp;
  tuv = 1.0 - abs(1.0 - mod(tuv, 2.0));
  vec4 fabric = getToColor(tuv);

  float w = smoothstep(0.0, 0.05 * size, R) * dome;
  float crease = cos(17.0 * u) * (1.0 - rho) * (1.0 - rho) * 0.3 + cos(9.0 * u) * rho * rho * 0.06;
  vec2 grad = w * vec2(-0.15 - 0.75 * rho * rho, (0.35 + 1.6 * sag) * u * (0.3 + 0.7 * rho) + crease);
  vec3 nrm = normalize(vec3(-rot(grad, panel.z - turn), 1.0));
  vec3 L = normalize(vec3(-0.45, 0.6, 0.75));
  float lit = mix(1.0, max(dot(nrm, L), 0.0) / L.z, 0.8 * shading);
  vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
  float sheen = pow(max(dot(nrm, H), 0.0), 40.0) - pow(H.z, 40.0);
  float px = l.x * sin(PI / n);
  float rib = (1.0 - abs(u)) * px;
  float seam = (1.0 - smoothstep(0.001, 0.004, rib)) * smoothstep(0.0, 0.03, px);
  float ridge = (1.0 - smoothstep(0.004, 0.02, rib)) * smoothstep(0.002, 0.006, rib) * smoothstep(0.0, 0.06, px);
  float stitch = 1.0 - smoothstep(0.001, 0.0025, abs(e - 0.012));
  vec3 col = fabric.rgb * lit * (1.0 - shading * w * (0.45 * seam + 0.18 * stitch));
  // the rib under the fabric pushes up a soft ridge, and light shows through the thin hem
  col += shading * w * (0.18 * max(sheen, 0.0) + 0.07 * ridge + 0.07 * (1.0 - smoothstep(0.0, 0.012, e)));

  vec4 from = getFromColor(uv);
  vec4 c = vec4(from.rgb * from.a * (1.0 - shadow), from.a);

  vec2 tip = l - R * vec2(cos(PI / n), (l.y < 0.0 ? -1.0 : 1.0) * sin(PI / n));
  float tipR = 0.009 * size * w;
  float ball = (1.0 - smoothstep(tipR - 0.002, tipR, length(tip))) * smoothstep(0.2, 0.6, w);
  float shine = 0.7 + 0.5 * max(dot(rot(tip, panel.z - turn) / max(tipR, 1e-3), L.xy), 0.0);
  c = mix(c, vec4(metal.rgb * shine, 1.0), ball * metal.a);

  c = mix(c, vec4(col * fabric.a, fabric.a), cov);

  float r = length(q) / (0.022 * size * w + 1e-4);
  float cone = 0.75 + 0.45 * dot(q / max(length(q), 1e-4), L.xy) * min(r, 1.0) + 0.35 * (1.0 - smoothstep(0.25, 0.4, r));
  float cap = (1.0 - smoothstep(0.88, 1.0, r)) * smoothstep(0.0, 0.2, w);
  c = mix(c, vec4(metal.rgb * cone, 1.0), cap * metal.a * cov);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
