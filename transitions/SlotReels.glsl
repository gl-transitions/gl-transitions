// Author: gre
// License: MIT
// Description: The frame is cut into vertical reels that spin downward like drums, motion-blurred with speed, carrying the outgoing image then the incoming one, and stop one after another from left to right with a small mechanical bounce
// Tags: 3d, spin, stripes, motion-blur

// @range(1, 16, 1) Number of reels
uniform int reels; // = 5
// @range(0, 1) Amount of vertical motion blur while the reels spin fast
uniform float blur; // = 0.6
// @range(0, 0.9) Delay between the first and the last reel's stop, as a part of the transition
uniform float stagger; // = 0.45
// @range(0, 1) Size of the bounce when a reel stops
uniform float bounce; // = 0.5
// @color Color of the separators between the reels
uniform vec4 separator; // = vec4(0.04, 0.04, 0.05, 1.0)

const float PI = 3.141592653589793;
// half of the arc of the drum seen in the frame, in radians
const float ARC = 1.15;
// duration of the bounce, as a part of the transition
const float SETTLE = 0.1;
// width of the separators, in frame heights
const float LINE = 0.006;
// width of the anti-aliased edges, in frame heights
const float EDGE = 0.0015;

// the time at which the reel stops, before its bounce
float stopTime(float i, float n) {
  float order = n > 1.0 ? i / (n - 1.0) : 1.0;
  return (1.0 - SETTLE) * (1.0 - clamp(stagger, 0.0, 0.9) * (1.0 - order));
}

// how far the reel has turned at time t, in image heights: it speeds up, slows down to its stop
// a little past the incoming image and springs back onto it
float reelOffset(float t, float stopT, float turns) {
  float amp = 0.07 * bounce;
  // speed at the stop, matched with the start of the bounce
  float v1 = amp * PI * stopT / (turns * SETTLE);
  float u = clamp(t / stopT, 0.0, 1.0);
  float g = u * u * (3.0 - 2.0 * u) + v1 * (u * u * u - u * u);
  float b = clamp((t - stopT) / SETTLE, 0.0, 1.0);
  return turns * g + amp * sin(PI * b) * (1.0 - b) * (1.0 - b);
}

// the reel's speed at time t, the derivative of reelOffset, in image heights per transition
float reelSpeed(float t, float stopT, float turns) {
  float amp = 0.07 * bounce;
  float v1 = amp * PI * stopT / (turns * SETTLE);
  if (t < stopT) {
    float u = max(t / stopT, 0.0);
    return turns * (6.0 * u * (1.0 - u) + v1 * u * (3.0 * u - 2.0)) / stopT;
  }
  float b = min((t - stopT) / SETTLE, 1.0);
  return amp * (1.0 - b) * (PI * cos(PI * b) * (1.0 - b) - 2.0 * sin(PI * b)) / SETTLE;
}

vec4 transition (vec2 uv) {
  float n = max(float(reels), 1.0);
  float i = min(floor(uv.x * n), n - 1.0);
  float lx = uv.x * n - i;
  float stopT = stopTime(i, n);
  // an odd number of turns, more for the reels that spin longer, so they land on the incoming image
  float turns = 2.0 * floor(stopT * 4.0) + 1.0;

  // the reel is a drum while it spins, and flattens back as it settles
  float drum = smoothstep(0.0, 0.12, progress) * (1.0 - smoothstep(stopT, stopT + SETTLE, progress));
  float y = 2.0 * uv.y - 1.0;
  // theta: the angle around the drum's axis, 0 facing the viewer
  float theta = asin(clamp(y * sin(ARC), -1.0, 1.0));
  float v = mix(uv.y, 0.5 + theta / (2.0 * ARC), drum);
  // the far edges of the drum look narrower
  float depth = (1.0 - cos(theta)) * drum;
  float px = 0.5 + (lx - 0.5) * (1.0 + 0.2 * depth);

  // offset from the resting position, -turns at the start, 0 once landed
  float off = reelOffset(progress, stopT, turns) - turns;
  float speed = abs(reelSpeed(progress, stopT, turns));
  // the blur spans the distance the reel travels in about a frame
  float spread = blur * min(speed * 0.02, 0.22) * drum;

  // up to 8 taps along the reel, weighted toward the middle, one when it stands still
  vec4 c = vec4(0.0);
  float wsum = 0.0;
  for (int k = 0; k < 8; k++) {
    float f = float(k) / 7.0 - 0.5;
    float w = 1.0 - abs(f);
    float vv = v + off + spread * f;
    float seg = floor(vv);
    vec2 q = vec2((i + clamp(px, 0.0, 1.0)) / n, vv - seg);
    // the drum carries the incoming image on even segments, the outgoing one on odd segments
    vec4 s = mod(seg, 2.0) < 0.5 ? getToColor(q) : getFromColor(q);
    // a thin shadow at the seams between the images, not at the frame's top and bottom edges
    s.rgb *= 1.0 - 0.6 * drum * (1.0 - y * y) * (1.0 - smoothstep(0.0, 0.02, min(q.y, 1.0 - q.y)));
    c += w * s;
    wsum += w;
    if (spread < 1e-4) break;
  }
  c /= wsum;

  // the drum's faces darken as they turn away, with a soft highlight above its middle
  float facing = cos(theta);
  c.rgb *= mix(1.0, 0.25 + 0.75 * facing * facing, drum);
  c.rgb += drum * 0.07 * c.a * exp(-12.0 * (y - 0.3) * (y - 0.3));

  // separators between the reels, and the background around the narrower far edges of the drums
  float env = smoothstep(0.0, 0.1, progress) * (1.0 - smoothstep(0.9, 1.0, progress));
  float reelW = ratio / n;
  float persp = reelW / (1.0 + 0.2 * depth);
  // distance to the reel's sides, and to its sides next to the other reels
  float dSide = min(px, 1.0 - px) * persp;
  float dInner = min(i > 0.5 ? px : 2.0, i < n - 1.5 ? 1.0 - px : 2.0) * persp;
  float line = 1.0 - smoothstep(0.5 * LINE - EDGE, 0.5 * LINE + EDGE, dInner);
  float outside = 1.0 - smoothstep(-EDGE, 0.0, dSide);
  // a soft shadow cast by the separators on the reels
  c.rgb *= 1.0 - 0.35 * env * (1.0 - smoothstep(0.0, 0.03 * reelW + LINE, dInner));
  return mix(c, separator, max(line * env, outside));
}
