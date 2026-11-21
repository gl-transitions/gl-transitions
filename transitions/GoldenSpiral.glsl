// Author: gre
// License: MIT
// Description: Thin guide lines divide the outgoing image like a golden rectangle into ever smaller squares; a hand sweeps a quarter turn through the biggest one, then the next and the next, faster and faster into the eye of the spiral, revealing the incoming image and tracing the golden spiral behind it
// Tags: wipe, spiral, golden-ratio, geometry, radial

// @range(0, 1) Opacity of the guide lines, the hand and the traced spiral
uniform float lines; // = 0.85
// @color Color of the guide lines, the hand and the traced spiral
uniform vec4 lineColor; // = vec4(1.0, 0.95, 0.85, 1.0)

const int PIECES = 12;
const float PHI = 1.618034;
const float HALF_PI = 1.5707963;
// each smaller piece sweeps faster, so the spiral accelerates into its eye
const float DECAY = 0.64;
// the first piece's share of the time; the twelve shares add up to 0.97
const float DUR0 = 0.35086;
// line width, in frame heights
const float PX = 0.004;

vec4 transition(vec2 uv) {
  float s = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.5);
  vec2 asp = vec2(ratio, 1.0);
  vec2 P = uv * asp;
  vec2 lo = vec2(0.0);
  vec2 hi = asp;
  // direction from each piece's pivot to where its sweep starts; turns clockwise piece after piece
  vec2 e = ratio >= 1.0 ? vec2(-1.0, 0.0) : vec2(0.0, 1.0);
  float dur = DUR0;
  float t0 = 0.0;
  float mask = smoothstep(0.97, 1.0, s);
  float ink = 0.0;
  float shade = 0.0;
  for (int i = 0; i < PIECES; i++) {
    vec2 ax = abs(e);
    vec2 sz = hi - lo;
    float L = dot(sz, ax);
    float S = dot(sz, 1.0 - ax);
    // the leftover's aspect is pulled toward the golden ratio, so pieces of any frame stay close to squares
    float rn = max(PHI - 0.4 * (L / S - PHI), 1.2);
    float cut = L - S / rn;
    vec2 bl = lo;
    vec2 tr = hi;
    if (e.x + e.y < 0.0) {
      tr = mix(hi, lo + cut, ax);
      lo = mix(lo, lo + cut, ax);
    } else {
      bl = mix(lo, hi - cut, ax);
      hi = mix(hi, hi - cut, ax);
    }
    vec2 f = vec2(e.y, -e.x);
    if (all(greaterThanEqual(P, bl)) && all(lessThanEqual(P, tr))) {
      vec2 psz = tr - bl;
      vec2 pivot = 0.5 * (bl + tr) - 0.5 * psz * (e + f);
      vec2 q = vec2(dot(P - pivot, e), dot(P - pivot, f));
      vec2 ext = vec2(dot(psz, ax), dot(psz, 1.0 - ax));
      float a = clamp((s - t0) / dur, 0.0, 1.0);
      float th = a * HALF_PI;
      vec2 h = vec2(cos(th), sin(th));
      float dist = q.x * h.y - q.y * h.x;
      mask = smoothstep(-PX, PX, dist + PX * (2.0 * a - 1.0));
      float busy = 4.0 * a * (1.0 - a);
      shade = busy * exp(min(dist, 0.0) * 25.0) * (1.0 - mask);
      float hand = (1.0 - smoothstep(0.0, PX, abs(dist))) * step(0.0, dot(q, h)) * busy;
      vec2 l = q / ext;
      float g = length(l);
      float arcDist = (g - 1.0) * g / max(length(l / ext), 1e-4);
      float arc = (1.0 - smoothstep(0.0, PX, abs(arcDist))) * smoothstep(-PX, PX, dist);
      // the frame's own edges get no rule
      vec2 inner = min(P - bl + step(bl, vec2(1e-4)), tr - P + step(asp - 1e-4, tr));
      float grid = 0.6 * (1.0 - smoothstep(0.0, PX, min(inner.x, inner.y)));
      ink = max(max(grid, arc), hand);
      break;
    }
    e = f;
    t0 += dur;
    dur *= DECAY;
  }
  vec4 c = mix(getFromColor(uv) * vec4(vec3(1.0 - 0.4 * shade), 1.0), getToColor(uv), mask);
  float w = ink * lines * lineColor.a * 4.0 * s * (1.0 - s);
  float alpha = mix(c.a, 1.0, w);
  return vec4(mix(c.rgb, lineColor.rgb, w / max(alpha, 1e-6)), alpha);
}
