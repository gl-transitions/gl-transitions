// Author: gre
// License: MIT
// Description: The frame is cut into concentric rings that spin like the dials of a combination lock, in alternating directions and blurred with speed, one after another from the center outward; each ring overshoots a little and locks into place on the incoming image
// Tags: rotate, circle, rings, motion-blur

// @range(2, 12, 1) Number of rings, from the center to the farthest corner
uniform int rings; // = 6
// @param Square rings, like nested frames, instead of round ones
uniform bool square; // = false
// @range(1, 3, 1) Full turns made by each ring
uniform int turns; // = 1
// @range(0, 0.8) Delay between the first ring and the last one, as a part of the transition
uniform float stagger; // = 0.5
// @range(0, 1) Amount of angular motion blur while the rings spin fast
uniform float blur; // = 0.6
// @range(0, 1) Size of the overshoot when a ring locks
uniform float settle; // = 0.5

const float PI = 3.141592653589793;
// part of a ring's time spent overshooting and coming back
const float SETTLE = 0.2;
// half width of the gaps between the rings, width of their rims and of the anti-aliased edges, in frame heights
const float GAP = 0.0035;
const float RIM = 0.012;
const float EDGE = 0.0015;

vec2 mirrorUV(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec2 rotate(vec2 v, float a) {
  float c = cos(a), s = sin(a);
  return vec2(c * v.x + s * v.y, c * v.y - s * v.x);
}

// the delay between two rings, kept shorter than the time a ring moves so that the motion never pauses
float ringDelay(float n) {
  float m = max(n - 1.0, 1.0);
  return min(clamp(stagger, 0.0, 0.8) / m, 0.7 / (1.0 + 0.7 * m));
}

// local time of ring i: 0 until it starts, 1 once it is locked
float ringTime(float i, float n) {
  float d = ringDelay(n);
  return progress >= 1.0 ? 1.0 : clamp((progress - d * i) / (1.0 - d * (n - 1.0)), 0.0, 1.0);
}

// how much a ring is moving, which opens the gaps around it
float activity(float i, float n) {
  float t = ringTime(i, n);
  return smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.88, 1.0, t));
}

// the ring's angle at its time t: it speeds up, reaches `total` a little fast, overshoots and springs back
float spin(float t, float total) {
  float amp = 0.1 * settle * sign(total);
  float stopT = 1.0 - SETTLE;
  // speed at the stop, matched with the start of the overshoot
  float v1 = amp * PI * stopT / (total * SETTLE);
  float u = clamp(t / stopT, 0.0, 1.0);
  float b = clamp((t - stopT) / SETTLE, 0.0, 1.0);
  return total * (u * u * (3.0 - 2.0 * u) + v1 * (u * u * u - u * u)) + amp * sin(PI * b) * (1.0 - b) * (1.0 - b);
}

vec4 transition(vec2 uv) {
  vec2 aspect = vec2(ratio, 1.0);
  vec2 c = (uv - 0.5) * aspect;
  float r = square ? max(abs(c.x), abs(c.y)) : length(c);
  float n = clamp(float(rings), 1.0, 12.0);
  float w = (square ? 0.5 * max(ratio, 1.0) : length(0.5 * aspect)) / n;
  float f = r / w;
  float i = min(floor(f), n - 1.0);
  float t = ringTime(i, n);

  vec4 col;
  if (t <= 0.0) col = getFromColor(uv);
  else if (t >= 1.0) col = getToColor(uv);
  else {
    float total = 2.0 * PI * max(float(turns), 1.0) * (mod(i, 2.0) < 0.5 ? 1.0 : -1.0);
    float a = spin(t, total);
    // angular speed per unit of progress, without the small overshoot; the blur spans what the ring
    // travels in about a frame, at most a short arc so that the 8 taps stay close together
    float u = min(t / (1.0 - SETTLE), 1.0);
    float omega = abs(total) * 6.0 * u * (1.0 - u) / ((1.0 - SETTLE) * (1.0 - ringDelay(n) * (n - 1.0)));
    float span = blur * min(omega * 0.015, 0.1 / max(r, 0.01));
    // the incoming image takes over at full speed, hidden by the blur; the whole turns bring it back upright
    float m = smoothstep(0.3, 0.5, t);
    col = vec4(0.0);
    float ws = 0.0;
    for (int k = 0; k < 8; k++) {
      float x = float(k) / 7.0 - 0.5;
      vec2 q = mirrorUV(rotate(c, a + span * x) / aspect + 0.5);
      vec4 s = mix(getFromColor(q), getToColor(q), m);
      col += (1.0 - abs(x)) * s;
      ws += 1.0 - abs(x);
    }
    col /= ws;
  }

  // the nearest boundary between two rings, open while one of them moves: a dark gap
  // with a bevelled rim on each side, lit from the top left
  float bj = clamp(floor(f + 0.5), 1.0, max(n - 1.0, 1.0));
  float act = n > 1.5 ? max(activity(bj - 1.0, n), activity(bj, n)) : 0.0;
  float d = (f - bj) * w;
  vec2 nr = square ? (abs(c.x) > abs(c.y) ? vec2(sign(c.x), 0.0) : vec2(0.0, sign(c.y))) : c / max(r, 1e-4);
  // the outer ring's inner rim faces the center, the inner ring's outer rim faces away from it
  float light = -sign(d) * dot(nr, vec2(-0.6, 0.8)) * (1.0 - smoothstep(GAP, GAP + RIM, abs(d))) * act;
  col.rgb = light > 0.0 ? mix(col.rgb, vec3(col.a), 0.35 * light) : col.rgb * (1.0 + 0.45 * light);
  col.rgb *= 1.0 - 0.85 * act * (1.0 - smoothstep(GAP - EDGE, GAP + EDGE, abs(d)));
  return col;
}
