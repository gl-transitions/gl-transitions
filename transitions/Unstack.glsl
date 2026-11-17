// Author: gre
// License: MIT
// Description: The outgoing image is a stack of horizontal bands with the incoming image stacked on top of it, out of frame: bands are yanked out sideways one at a time in a shuffled order, and each time everything above drops into the gap with a small bounce, so the incoming image comes down into the frame in beats
// Tags: stack, bands, gravity, bounce, rhythm

// @range(2, 12, 1) Number of bands in the outgoing image
uniform int bands; // = 6
// @range(0, 1) Height of the bounce after each drop
uniform float bounce; // = 0.5
// @color Color of the slot left empty by a pulled band
uniform vec4 slot; // = vec4(0.1, 0.095, 0.09, 1.0)

const float PULL = 0.11;
const float FALL = 0.1;
// the stack starts to fall once the pulled band has nearly cleared its slot
const float LAG = 0.85;
const float IMPACT = 0.62;
// past 1 so the smeared tail has left the frame too
const float REACH = 1.3;
const float EDGE = 0.0015;
const int TAPS = 16;

float hash(float n) {
  vec2 p = fract(vec2(n) * vec2(0.1031, 0.1030));
  p += dot(p, p.yx + 33.33);
  return fract((p.x + p.y) * p.x);
}

float count() {
  return clamp(float(bands), 2.0, 12.0);
}

float rank(float i, float n) {
  float r = 0.0, hi = hash(i + 7.0);
  for (int j = 0; j < 12; j++) {
    if (float(j) >= n) break;
    float h = hash(float(j) + 7.0);
    if (h < hi || (h == hi && float(j) < i)) r += 1.0;
  }
  return r;
}

float startTime(float r, float n) {
  return 0.02 + r * (0.96 - LAG * PULL - FALL) / (n - 1.0);
}

float pullPhase(float t0) {
  return clamp((progress - t0) / PULL, 0.0, 1.0);
}

float pullOffset(float u, float r) {
  return (mod(r, 2.0) < 0.5 ? 1.0 : -1.0) * REACH * u * u;
}

float hump(float s) {
  return 4.0 * s * (1.0 - s);
}

float dropOf(float t0) {
  float t = clamp((progress - t0 - LAG * PULL) / FALL, 0.0, 1.0);
  if (t < IMPACT) return (t / IMPACT) * (t / IMPACT);
  // two rebounds, the second a third as high and shorter
  float s = (t - IMPACT) / (1.0 - IMPACT);
  float h = s < 0.6 ? hump(s / 0.6) : 0.3 * hump((s - 0.6) / 0.4);
  return 1.0 - 0.2 * clamp(bounce, 0.0, 1.0) * h;
}

float box(float v, float a, float b, float soft) {
  return smoothstep(a - soft, a + soft, v) * (1.0 - smoothstep(b - soft, b + soft, v));
}

vec4 transition(vec2 uv) {
  float n = count(), H = 1.0 / n;
  vec4 c = vec4(0.0);
  float covered = 0.0;
  float above = 1.0, below = 1.0;
  vec4 front = vec4(0.0);
  float frontA = 0.0, shadow = 1.0;
  float D = 0.0, floorY = 0.0;
  for (int k = 0; k < 24; k++) {
    float j = float(k);
    if (j >= 2.0 * n) break;
    float b = (j - D) * H;
    float y = uv.y - b;
    float u = 0.0, r = 0.0, t0 = 0.0;
    if (j < n) {
      r = rank(j, n);
      t0 = startTime(r, n);
      u = pullPhase(t0);
    }
    if (u > 0.0) {
      float x = pullOffset(u, r);
      float lift = smoothstep(0.0, 0.35, u);
      float off = 0.22 * H * lift;
      float grow = 1.0 + 0.08 * lift;
      shadow *= 1.0 - 0.55 * lift * box(uv.x - x - sign(x) * off * 0.4, 0.0, 1.0, off)
        * box(uv.y + off - b - 0.5 * H, -0.5 * H * grow, 0.5 * H * grow, off);
      // a lifted band is closer to the eye, so it looks a bit taller
      float ly = (y - 0.5 * H) / grow + 0.5 * H;
      float ya = clamp(min(ly, H - ly) / (EDGE * lift + 1e-5) + 0.5, 0.0, 1.0);
      // smear over the distance travelled in about half a frame
      float v = sign(x) * max(min(0.012 * 2.0 * REACH * u / PULL, 0.1), EDGE);
      float s0 = uv.x - x;
      float lo = min(s0, s0 + v), hi = max(s0, s0 + v);
      float a = ya * max(min(hi, 1.0) - max(lo, 0.0), 0.0) / abs(v);
      if (a > 0.0) {
        ly = clamp(ly, 0.0, H);
        vec4 sum = vec4(0.0);
        for (int m = 0; m < TAPS; m++) {
          vec4 t = getFromColor(vec2(mix(max(lo, 0.0), min(hi, 1.0), (float(m) + 0.5) / float(TAPS)), j * H + ly));
          sum += vec4(t.rgb * t.a, t.a);
        }
        vec4 band = vec4(sum.rgb / max(sum.a, 1e-6), sum.a / float(TAPS));
        band.rgb *= 1.0 - 0.3 * lift * (1.0 - smoothstep(0.0, 0.2 * H, min(ly, H - ly)));
        front = mix(front, band, frontA > 0.0 ? a : 1.0);
        frontA = a + frontA * (1.0 - a);
      }
    } else {
      // only edges facing an open gap are softened, and only inside it, so closed seams stay exact
      float e = max(min(EDGE, 0.5 * (b - floorY)), 0.0) + 1e-6;
      float m = clamp(y / e + 1.0, 0.0, 1.0) * step(y, H);
      if (m > 0.0) {
        vec4 img = j < n
          ? getFromColor(vec2(uv.x, j * H + max(y, 0.0)))
          : getToColor(vec2(uv.x, (j - n) * H + max(y, 0.0)));
        c = mix(c, img, covered > 0.0 ? m : 1.0);
        covered = max(covered, m);
      }
      if (y < 0.0) above = min(above, -y);
      if (y > H) below = min(below, y - H);
      floorY = b + H;
    }
    if (j < n) D += dropOf(t0);
  }
  vec4 gap = slot;
  gap.rgb *= (1.0 - 0.65 * exp(-above / (0.2 * H))) * (1.0 - 0.35 * exp(-below / (0.1 * H)));
  c = mix(gap, c, covered);
  c.rgb *= shadow;
  return mix(c, front, frontA);
}
