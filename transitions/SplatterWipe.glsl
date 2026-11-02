// Author: gre
// License: MIT
// Description: Splats of paint land one after another, each popping in with a spiky outline, flung droplets and a few drips running down, revealing the incoming image until they cover the frame
// Tags: paint, splash, organic, reveal

// @range(2, 10, 1) Number of splats across the frame
uniform float splats; // = 4.0
// @range(0, 1) How long the spikes around each splat are
uniform float spikiness; // = 0.6
// @range(0, 1) How many droplets are flung around each splat
uniform float droplets; // = 0.6
// @range(0, 1) How far the paint drips run down
uniform float drips; // = 0.5
// @range(0, 1) How dark and glossy the rim of the splats is
uniform float rim; // = 0.5
// @param Random seed for the splats
uniform float seed; // = 3.0

const float PI = 3.141592653589793;
// number of spikes around a splat
const float SPIKES = 14.0;
// furthest reach of the shapes of a splat from its center, in cells. Splats are looked for in the 3x3 cells
// around a pixel, and the center of a splat 2 cells away is more than 1.35 cells away; on top of REACH, the
// smooth unions add up to 0.02 and the antialiasing 0.025 (at 10 splats), which leaves a margin of 0.055
// so that no splat is ever cut by the search
const float REACH = 1.25;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

// smooth noise around a splat, wrapping over a full turn (t in 0..1)
float turnNoise(float t, float n, vec2 key) {
  float x = t * n;
  float i = floor(x);
  float f = x - i;
  float a = hash12(key + vec2(mod(i, n), 61.0));
  float b = hash12(key + vec2(mod(i + 1.0, n), 61.0));
  return mix(a, b, f * f * (3.0 - 2.0 * f));
}

// smooth union of two signed distances (> 0 inside)
float smax(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return max(a, b) + h * h * k * 0.25;
}

// signed distance (approximately, in cells, > 0 inside) to the splat of a grid cell
float splat(vec2 q, vec2 cell, vec2 key) {
  float t0 = 0.01 + 0.6 * hash12(key + vec2(3.0, 0.0)); // when it lands
  if (progress <= t0) return -1.0;
  vec2 c = cell + 0.5 + 0.3 * (vec2(hash12(key + vec2(5.0, 1.0)), hash12(key + vec2(9.0, 2.0))) - 0.5);
  vec2 d = q - c;
  float l = length(d);
  // nothing of the splat reaches this far (its distance there would be below -0.08 anyway)
  if (l > REACH + 0.1) return -1.0;
  // a fast pop-in, then the paint slowly spreads until it covers its whole cell
  float pop = clamp((progress - t0) / 0.08, 0.0, 1.0);
  pop = 1.0 - (1.0 - pop) * (1.0 - pop) * (1.0 - pop);
  float x = clamp((progress - t0) / (0.96 - t0), 0.0, 1.0);
  float grow = x * x * x;
  float r0 = 0.42 + 0.2 * hash12(key + vec2(11.0, 3.0));
  // the farthest corner of the cell is at most 0.65 * sqrt(2) ~ 0.92 cells away, and the body dents by 6% at most in the end
  float rc = mix(r0 * pop, 1.03, grow);

  float a = l > 1e-5 ? atan(d.y, d.x) / (2.0 * PI) + 0.5 : 0.0;
  // an irregular body
  float lumps = mix(0.3, 0.06, grow) * (turnNoise(a, 5.0, key) - 0.5) + mix(0.18, 0.06, grow) * (turnNoise(a, 19.0, key + 3.0) - 0.5);
  float f = rc * (1.0 + lumps) - l;

  // a spike in each slice of the turn: a ray that tapers from a wide base, the long ones ending in a bead;
  // the slices on both sides are looked at too, as their spikes can lean over the boundary
  float s = floor(a * SPIKES);
  float spike = -1.0;
  for (int k = -1; k <= 1; k++) {
    float sl = s + float(k);
    vec2 sk = key + vec2(mod(sl, SPIKES), 17.0);
    float h = hash12(sk);
    float w0 = (0.022 + 0.03 * hash12(sk + 1.5)) * pop;
    float len = max(min(spikiness * (0.06 + 0.6 * h * h) * pop, REACH - 1.2 * w0 - rc), 0.0);
    if (len > 0.0) {
      // short spikes are thin too, so that no spikiness leaves a clean body
      float w = w0 * min(len / 0.06, 1.0);
      float ang = (sl + 0.5 + 0.4 * (hash12(sk + 0.5) - 0.5)) / SPIKES * 2.0 * PI - PI;
      vec2 dir = vec2(cos(ang), sin(ang));
      float along = dot(d, dir);
      float across = abs(d.x * dir.y - d.y * dir.x);
      float u = clamp((along - rc) / len, 0.0, 1.0);
      float ray = min(w * (1.0 - 0.7 * u) - across, rc + len - along);
      if (h > 0.5) ray = max(ray, w * 1.2 - length(d - dir * (rc + len)));
      spike = max(spike, ray);
    }
  }
  f = smax(f, spike, 0.08);

  // droplets flung out around the splat
  for (int j = 0; j < 5; j++) {
    vec2 dk = key + vec2(float(j), 29.0);
    float hr = hash12(dk + 0.5);
    float rad = (0.015 + 0.05 * hr * hr) * clamp(droplets * 5.0 - float(j), 0.0, 1.0) * pop;
    if (rad > 0.0) {
      float da = 2.0 * PI * hash12(dk);
      float dist = min(r0 + 0.08 + 0.5 * hash12(dk + 1.5), REACH - rad) * mix(0.5, 1.0, pop);
      f = max(f, rad - length(d - dist * vec2(cos(da), sin(da))));
    }
  }

  // drips running down from the bottom of the splat
  if (drips > 0.0) {
    float run = clamp((progress - t0 - 0.03) / 0.45, 0.0, 1.0);
    run = run * (2.0 - run);
    for (int j = 0; j < 2; j++) {
      vec2 dk = key + vec2(float(j), 43.0);
      float xo = (hash12(dk) - 0.5) * r0;
      float dw = (0.03 + 0.02 * hash12(dk + 0.5)) * pop;
      float top = sqrt(r0 * r0 - xo * xo) * pop;
      float bottom = min(top + drips * (0.25 + 0.75 * hash12(dk + 1.5)) * run, sqrt(REACH * REACH - xo * xo) - 1.6 * dw);
      float dx = abs(d.x - xo);
      float drip = min(dw - dx, min(d.y + bottom, -d.y));
      float tip = dw * 1.4 - length(vec2(dx, d.y + bottom + 0.2 * dw));
      f = smax(f, max(drip, tip), 0.05);
    }
  }
  return f;
}

vec4 transition(vec2 uv) {
  float n = max(1.0, floor(splats + 0.5));
  float cellSize = max(ratio, 1.0) / n;
  vec2 q = vec2(uv.x * ratio, uv.y) / cellSize; // in cells
  vec2 base = floor(q);
  vec2 sd = seed * vec2(7.0, 13.0);
  float f = -1.0;
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 cell = base + vec2(float(i), float(j));
      f = max(f, splat(q, cell, cell + sd));
    }
  }
  float aa = 0.0025 / cellSize; // about a pixel or two, in cells
  float inside = smoothstep(-aa, aa, f);
  vec4 from = getFromColor(uv);
  vec4 to = getToColor(uv);
  // thick paint: a darker rim with a thin glossy line just inside it, gone once the frame is covered
  float e = clamp(f / 0.045, 0.0, 1.0);
  float amount = rim * (1.0 - smoothstep(0.75, 1.0, progress));
  float dark = (1.0 - e) * (1.0 - e) * 0.6;
  float gloss = smoothstep(0.2, 0.4, e) * (1.0 - smoothstep(0.4, 0.7, e)) * 0.3;
  to.rgb = mix(to.rgb * (1.0 - dark * amount), vec3(1.0), gloss * amount * to.a);
  return mix(from, to, inside);
}
