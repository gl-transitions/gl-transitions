// Author: gre
// License: MIT
// Description: A hand plane takes long strokes along the outgoing picture in overlapping lanes; each stroke lifts the picture off as a thin shaving that rolls up into a fat curl riding ahead of the blade, and the freshly planed surface left behind is the incoming picture
// Tags: wood, curl, roll, wipe, craft

// @range(1, 8, 1) Number of lanes the plane strokes
uniform float lanes; // = 4.0
// @range(0, 7, 1) Shifts the order of the strokes
uniform float seed; // = 3.0

const float PI = 3.14159265;
const float AA = 1.5 / 400.0;

// coprime with the lane count so the stroke order is a permutation
float stride(float n) {
  return mod(n, 3.0) == 0.0 ? 5.0 : 3.0;
}

float progressOf(float lane, float n) {
  float start = mod(lane * stride(n) + seed, n) / max(n - 1.0, 1.0) * 0.42;
  float f = clamp((progress - start) / 0.58, 0.0, 1.0);
  return mix(f, f * f * (3.0 - 2.0 * f), 0.5);
}

float bandOf(float lane, vec2 uv, float n) {
  float by = (uv.y * n - lane - 0.5) / 1.2 + 0.5;
  float m = 0.03 * sin(uv.x * ratio * 23.0 + lane * 5.0);
  return smoothstep(m - 0.03, m, by) * smoothstep(m - 0.03, m, 1.0 - by);
}

vec4 transition(vec2 uv) {
  float n = floor(lanes + 0.5);
  float own = min(floor(uv.y * n), n - 1.0);
  float nb = own + (fract(uv.y * n) < 0.5 ? -1.0 : 1.0);
  float lo = min(own, nb), hi = max(own, nb);
  if (mod(lo * stride(n) + seed, n) > mod(hi * stride(n) + seed, n)) { float s = lo; lo = hi; hi = s; }
  float px = uv.x * ratio;
  float rmax = 0.6 / n;
  float cut = 0.0;
  vec4 col = vec4(0.0);
  float cv = 0.0;
  float shadow = 0.0;
  for (int k = 0; k < 2; k++) {
    float lane = k == 0 ? lo : hi;
    if (lane < 0.0 || lane > n - 1.0) continue;
    float e = progressOf(lane, n);
    float X = mix(-0.9 * rmax, ratio + 2.0 * rmax + 0.01, e);
    float r = rmax * (0.4 + 0.6 * sqrt(clamp(X / ratio, 0.0, 1.0)));
    float band = bandOf(lane, uv, n);
    cut = max(cut, band * smoothstep(-AA, AA, X - r - px));
    float live = e * (1.0 - e) * 4.0;
    float d = px - X;
    shadow = max(shadow, band * live * smoothstep(0.08, 0.0, d) * smoothstep(-0.02, 0.0, d) * 0.45);
    float u = (px - (X - r)) / r;
    float a = asin(clamp(u, -1.0, 1.0));
    float sx = abs((X - r - r * (a + PI * 0.5) * 2.2) / ratio);
    vec4 c = getFromColor(vec2(1.0 - abs(1.0 - sx), uv.y));
    c.rgb *= 0.35 + 0.8 * sqrt(max(1.0 - u * u, 0.0));
    c.rgb += 0.25 * pow(max(1.0 - abs(u + 0.4) * 2.5, 0.0), 2.0);
    float cov = (1.0 - smoothstep(1.0 - 2.0 * AA / r, 1.0, abs(u))) * band;
    col = cv > 0.0 ? mix(col, c, cov) : c;
    cv = max(cv, cov);
  }
  vec4 back = mix(getFromColor(uv), getToColor(uv), cut);
  back.rgb *= 1.0 - shadow;
  return mix(back, col, cv);
}
