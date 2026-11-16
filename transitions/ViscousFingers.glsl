// Author: gre
// License: MIT
// Description: The incoming image is pushed into the outgoing one like air into oil squeezed between two glass plates: a bubble grows into a few rounded fingers that keep splitting in two at their tips, shoving the old picture aside into thin glossy threads, until the fingers swell and close the last gaps
// Tags: liquid, branching, organic, radial, physical

// @param Where the incoming image is pushed in
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(3, 8, 1) Number of fingers leaving the first bubble
uniform int fingers; // = 5

const float TAU = 6.2831853;
const float AA = 0.0025;
const float R0 = 0.07;
const vec3 LIGHT = vec3(-0.4511, 0.5514, 0.7018);
const vec3 HALFWAY = vec3(-0.2445, 0.2989, 0.9224);

float vfHash(float p) {
  p = fract(p * 0.1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

float vfCap(float r, float lim, float w) {
  float x = clamp((lim - r) / max(w, 1e-4), 0.0, 1.0);
  return sqrt(x * (2.0 - x));
}

vec2 vfMirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// s = 2^(l + 1), passed exactly: exp2 is approximate on some targets
float vfSplit(float c, float l, float s) {
  return R0 * s * (0.8 + 0.4 * vfHash(c + 97.0 * l + 11.7));
}

// a finger of level l in cell c of n, at offset a (in cells) from the cell's middle
float vfFinger(float l, float n, float c, float a, float r, float n0, float Rt, float fill) {
  float g = 1.0;
  float ck = c;
  float lk = l;
  // a finger reaches no further than its ancestors, so no branch floats free
  for (int k = 0; k < 5; k++) {
    if (lk < 0.0) break;
    g = min(g, 0.68 + 0.32 * vfHash(ck + 97.0 * lk + 3.1));
    ck = floor(ck * 0.5);
    lk -= 1.0;
  }
  float split = vfSplit(c, l, 2.0 * n / n0);
  float rs = l < 0.5 ? 0.0 : vfSplit(floor(c * 0.5), l - 1.0, n / n0) * (1.0 - 0.3 * TAU * 2.0 / n);
  float cell = TAU * r / n;
  // children leave from their parent's middle at its full width, then settle into their own cell
  float fork = l < 0.5 ? 1.0 : smoothstep(rs, rs + 0.6 * (split - rs), r);
  float ac = (mod(c, 2.0) < 0.5 ? 0.5 : -0.5) * (1.0 - fork);
  float tip = Rt * mix(g, 1.0, fill);
  float w = mix(mix(0.2, 0.3, smoothstep(0.0, 0.3, tip - r)), 0.56, fill) * (2.0 - fork) * cell + 3.0 * AA * fill;
  float end = l < 3.5 ? min(tip, split + w) : tip;
  return max(abs(a - ac) * cell - w * vfCap(r, end, w), max(r - end, rs - r));
}

// distance-like field to the air, negative inside the fingers
float vfField(vec2 q, float Rt, float fill) {
  float r = length(q);
  float th = atan(q.y, dot(q, q) > 0.0 ? q.x : 1.0) / TAU + 0.5;
  th += (0.012 * sin(r * 11.0 + TAU * th * 3.0) + 0.007 * sin(r * 23.0 - TAU * th * 7.0)) / (0.3 + r);

  float n0 = float(fingers);
  float dist = r - min(Rt, R0);
  float n = n0;
  for (int l = 0; l < 5; l++) {
    float fl = float(l);
    float x = th * n;
    float c = floor(x);
    float a = x - c - 0.5;
    float side = a < 0.0 ? -1.0 : 1.0;
    // the neighbour on the near side too, so the field stays continuous across cell borders
    dist = min(dist, vfFinger(fl, n, mod(c, n), a, r, n0, Rt, fill));
    dist = min(dist, vfFinger(fl, n, mod(c + side, n), a - side, r, n0, Rt, fill));
    n *= 2.0;
  }
  return dist;
}

vec4 transition(vec2 uv) {
  vec2 asp = vec2(ratio, 1.0);
  vec2 q = (uv - center) * asp;
  vec2 dir = q / max(length(q), 1e-4);
  float rmax = length(max(center, 1.0 - center) * asp);

  float t = progress;
  float Rt = t * (rmax + 0.1) / 0.55;
  float fill = clamp((t - 0.45) / 0.55, 0.0, 1.0);
  float grow = smoothstep(0.0, 0.08, Rt) * (1.0 - fill * fill);

  const vec2 EPS = vec2(0.002, 0.0);
  float d = vfField(q, Rt, fill);
  vec2 grad = vec2(vfField(q + EPS, Rt, fill) - d, vfField(q + EPS.yx, Rt, fill) - d) / EPS.x;
  vec2 gdir = grad / max(length(grad), 1e-4);

  float slope = 0.4 * exp(-max(d, 0.0) / 0.01) * grow;
  vec3 nrm = normalize(vec3(-slope * gdir, 1.0));
  float diffuse = max(1.0 + 0.9 * (dot(nrm, LIGHT) - LIGHT.z), 0.0);
  float spec = max(pow(max(dot(nrm, HALFWAY), 0.0), 40.0) - pow(HALFWAY.z, 40.0), 0.0);

  // pushed radially, not away from the nearest finger, which would tear the oil along its mid-lines
  vec2 suv = uv - dir * 0.03 * exp(-max(d, 0.0) / 0.05) * grow / asp;
  vec4 oil = getFromColor(vfMirror(suv));
  oil.rgb = oil.rgb * diffuse + 0.4 * spec * oil.a;

  vec4 air = getToColor(uv);
  air.rgb *= 1.0 - 0.35 * grow * exp(min(d, 0.0) / 0.006);

  return mix(air, oil, smoothstep(-2.0 * AA, 0.0, d));
}
