// Author: gre
// License: MIT
// Description: A clock hand sweeps the outgoing image away to reveal a scratched film countdown, with crosshair rings and big numbers counting down, each sweep wiping in the next one, and the last sweep reveals the incoming image in its wake
// Tags: retro, film, countdown, radial, clock

// @range(1, 5, 1) Number of numbers counted down before the incoming image
uniform int count; // = 3
// @range(0, 1) Amount of film wear on the countdown: grain, scratches, dust and flicker
uniform float wear; // = 0.5
// @color Color of the countdown film
uniform vec4 leaderColor; // = vec4(0.80, 0.78, 0.74, 1.0)
// @color Color of the numbers, rings, crosshair and clock hand
uniform vec4 inkColor; // = vec4(0.07, 0.07, 0.07, 1.0)

const float PI = 3.141592653589793;
const float TAU = 6.283185307179586;
// anti-aliasing width, in frame heights
const float AA = 0.0015;

float hash11(float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

float segment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// distance to an arc of a circle of center c and radius r, spanning halfAngle on both sides of the
// direction mid (radians, counterclockwise from +x)
float arc(vec2 p, vec2 c, float r, float mid, float halfAngle) {
  vec2 q = p - c;
  float t = PI * 0.5 - mid;
  q = vec2(q.x * cos(t) - q.y * sin(t), q.x * sin(t) + q.y * cos(t));
  q.x = abs(q.x);
  vec2 sc = vec2(sin(halfAngle), cos(halfAngle));
  return sc.y * q.x > sc.x * q.y ? length(q - sc * r) : abs(length(q) - r);
}

// distance to the center line of the strokes of the number n (1 to 5), p within about [-0.6, 0.6] x [-1, 1]
float numeral(vec2 p, float n) {
  float w = 0.14;
  float top = 1.0 - w;
  float bottom = -1.0 + w;
  if (n < 1.5) {
    return min(segment(p, vec2(0.08, bottom), vec2(0.08, top)), segment(p, vec2(0.08, top), vec2(-0.32, 0.62)));
  }
  if (n < 2.5) {
    float d = arc(p, vec2(0.0, 0.42), 0.44, 1.05, 1.75);
    d = min(d, segment(p, vec2(0.337, 0.137), vec2(-0.46, bottom)));
    return min(d, segment(p, vec2(-0.46, bottom), vec2(0.5, bottom)));
  }
  if (n < 3.5) {
    float d = arc(p, vec2(0.0, 0.47), 0.40, 0.6, 2.35);
    return min(d, arc(p, vec2(0.0, -0.42), 0.46, -0.6, 2.35));
  }
  if (n < 4.5) {
    float d = segment(p, vec2(0.26, bottom), vec2(0.26, top));
    d = min(d, segment(p, vec2(0.26, top), vec2(-0.52, -0.36)));
    return min(d, segment(p, vec2(-0.52, -0.36), vec2(0.56, -0.36)));
  }
  float d = segment(p, vec2(-0.36, top), vec2(0.46, top));
  d = min(d, segment(p, vec2(-0.36, top), vec2(-0.40, 0.06)));
  return min(d, arc(p, vec2(0.0, -0.40), 0.52, -0.09, 2.5));
}

// the countdown frame showing the number n at the point q (centered, scaled to fit the frame), where
// px is the size of one frame height; the tone of the film alternates between numbers
vec3 leaderFrame(vec2 q, float n, float px) {
  float tone = mod(n, 2.0) < 0.5 ? 0.86 : 1.0;
  vec3 c = leaderColor.rgb * tone;
  float r = length(q);
  float aa = AA * px;
  float ink = 1.0 - smoothstep(0.003 - aa, 0.003 + aa, abs(r - 0.31));
  ink = max(ink, 1.0 - smoothstep(0.0045 - aa, 0.0045 + aa, abs(r - 0.37)));
  ink = max(ink, 1.0 - smoothstep(0.0015 - aa, 0.0015 + aa, min(abs(q.x), abs(q.y))));
  // the number, 0.4 frame heights tall
  float d = numeral(q / 0.21, n) * 0.21 - 0.031;
  float num = 1.0 - smoothstep(-aa, aa, d);
  // the number sits on a plain disc that hides the crosshair
  float disc = 1.0 - smoothstep(0.31 - 0.003 - aa, 0.31 - 0.003, r);
  ink = max(ink * (1.0 - disc), num);
  // the disc is a little lighter, like the hot spot of a lamp
  c *= 1.0 + 0.06 * disc;
  return mix(c, inkColor.rgb, ink * inkColor.a);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);
  vec4 from = getFromColor(uv);
  vec4 to = getToColor(uv);

  float n = clamp(float(count), 1.0, 5.0);
  float sweeps = n + 1.0;
  // the hand turns a little slower on the first and last sweeps
  float e = progress - 0.35 * sin(TAU * progress) / TAU;
  float t = e * sweeps;
  float k = min(floor(t), sweeps - 1.0);
  float f = t - k;

  // film frames, for the wear that changes from one frame to the next
  float frame = floor(progress * 12.0 * sweeps);
  float weave = wear * 0.0015;
  vec2 jitter = vec2(hash11(frame * 1.3 + 0.7) - 0.5, hash11(frame * 2.1 + 5.3) - 0.5) * weave;
  float s = min(ratio, 1.0);
  vec2 p = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  vec2 q = (p + jitter) / s;
  float px = 1.0 / s;

  // the hand, clockwise from 12 o'clock
  float ha = f * TAU;
  vec2 dir = vec2(sin(ha), cos(ha));
  float along = dot(p, dir);
  // signed distance to the hand's line, positive on its trailing side
  float across = dot(p, vec2(-dir.y, dir.x));
  // the swept wedge, between the ray at 12 o'clock and the hand: the intersection of the two half
  // planes for half a turn, then their union (signed distance in frame heights, positive inside).
  // It grows by an edge's width at the end of a sweep and shrinks by one at its start, so the
  // anti-aliased edges never leave a seam when the next sweep starts
  float dWedge = f <= 0.5 ? min(p.x, across) : max(p.x, across);
  dWedge += AA * (smoothstep(0.9, 1.0, f) - 1.0 + smoothstep(0.0, 0.1, f));
  float behind = clamp(dWedge / AA + 0.5, 0.0, 1.0);

  // before the hand: state k (0 is the outgoing image), behind it: state k + 1 (sweeps is the incoming
  // image); in between, number n - state + 1
  float ahead = k;
  float swept = k + 1.0;
  bool aheadLeader = ahead > 0.5;
  bool sweptLeader = swept < sweeps - 0.5;
  // the countdown darkens in the wake of the hand, and the wake goes on around the dial into the
  // part still ahead of the hand, left by the previous sweep
  float ang = dot(p, p) > 0.0 ? fract(atan(p.x, p.y) / TAU + 1.0) : 0.0;
  float nearCenter = smoothstep(0.0, 0.05, length(p) / s);
  vec3 aheadColor = from.rgb;
  float aheadAlpha = from.a;
  if (behind < 1.0 && aheadLeader) {
    aheadColor = leaderFrame(q, n - ahead + 1.0, px) * (1.0 - 0.18 * exp(-(f + 1.0 - ang) * TAU * 2.5) * nearCenter);
    aheadAlpha = leaderColor.a;
  }
  vec3 sweptColor = to.rgb;
  float sweptAlpha = to.a;
  if (behind > 0.0 && sweptLeader) {
    sweptColor = leaderFrame(q, n - swept + 1.0, px) * (1.0 - 0.18 * exp(-max(f - ang, 0.0) * TAU * 2.5) * nearCenter);
    sweptAlpha = leaderColor.a;
  }
  vec3 c = mix(aheadColor, sweptColor, behind);
  float a = mix(aheadAlpha, sweptAlpha, behind);
  float onLeader = mix(aheadLeader ? 1.0 : 0.0, sweptLeader ? 1.0 : 0.0, behind);

  // film wear: strongest on the countdown, lighter over the images in the middle of the transition
  float env = smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.9, 1.0, progress));
  float amount = wear * mix(0.35 * env, 1.0, onLeader);
  // grain
  vec2 cell = floor(uv * vec2(ratio, 1.0) * 300.0);
  c += (hash12(cell + frame * 37.0) - 0.5) * 0.09 * amount;
  // scratches running down the film, each one shows on some frames only
  for (int i = 0; i < 4; i++) {
    float fi = float(i);
    float seg = floor(frame / 3.0);
    float on = step(0.45, hash11(seg * 7.0 + fi * 13.0 + 1.0));
    float x = hash11(fi * 3.7 + 2.0) + 0.04 * (hash11(seg + fi * 5.1) - 0.5);
    float dx = abs(uv.x - x) * ratio;
    float line = 1.0 - smoothstep(0.0, 0.0008 + AA * 0.5, dx);
    float fade = 0.6 + 0.4 * sin(uv.y * (5.0 + fi) + fi * 2.0 + seg);
    c = mix(c, vec3(1.0), line * on * fade * 0.55 * amount);
  }
  // dust: a few dark specks in different places on every frame
  vec2 grid = vec2(9.0, 6.0);
  vec2 dc = floor(uv * grid);
  float h = hash12(dc + frame * 17.0);
  vec2 center = (dc + 0.2 + 0.6 * vec2(h, hash12(dc.yx + frame * 11.0 + 3.0))) / grid;
  float speck = 1.0 - smoothstep(0.0015, 0.0015 + AA, length((uv - center) * vec2(ratio, 1.0)) - 0.002 * h);
  c *= 1.0 - speck * step(0.9, h) * 0.85 * amount;
  // flicker and the lamp's vignette, on the countdown only
  float lamp = 1.0 - 0.06 * (hash11(frame + 0.5) - 0.5) * wear;
  lamp *= 1.0 - 0.35 * smoothstep(0.35, 0.95, length(q));
  c *= mix(1.0, lamp, onLeader);

  // the clock hand, with a soft shadow on its trailing side
  float handOn = smoothstep(0.0, 0.03, progress) * (1.0 - smoothstep(0.97, 1.0, progress));
  float handW = 0.0022 * s;
  float hand = (1.0 - smoothstep(handW - AA, handW + AA, abs(across))) * step(0.0, along);
  float shadow = exp(-max(across, 0.0) / (0.012 * s)) * step(0.0, across) * step(0.0, along) * 0.35;
  c *= 1.0 - shadow * handOn;
  c = mix(c, inkColor.rgb, hand * handOn * inkColor.a);
  a = mix(a, max(a, inkColor.a), hand * handOn);
  return vec4(clamp(c, 0.0, 1.0), a);
}
