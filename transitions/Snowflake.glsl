// Author: gre
// License: MIT
// Description: A six-armed paper snowflake is cut out of the outgoing picture: the rest of the sheet drops away around it, its punched holes fall out, and the snowflake, still made of the picture, hangs by a thin tab from the top edge, swings and turns, then tears loose and falls, revealing the incoming picture
// Tags: paper, cut, gravity, shape

// @range(0.35, 0.5) Size of the snowflake, in frame heights from its center to an arm tip
uniform float size; // = 0.47

const float PI = 3.141592653589793;
const vec2 SHADOW = vec2(0.016, -0.028);
const vec3 PAPER = vec3(0.94, 0.93, 0.9);

float aa(float d) { return clamp(d * 400.0 + 1.0, 0.0, 1.0); }
float frameDist(vec2 S) { vec2 d = min(S, vec2(ratio, 1.0) - S); return min(d.x, d.y); }
float drop(float t) { t = clamp(t, 0.0, 1.0); return t * t; }
mat2 rot(float a) { float c = cos(a), s = sin(a); return mat2(c, -s, s, c); }

float segment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// signed angle from the nearest arm, the arms pointing up so the tab sits on an arm tip
// the offset keeps atan defined at the center
float armAngle(vec2 v) { return mod(atan(v.x, v.y + 1e-6) + PI / 6.0, PI / 3.0) - PI / 6.0; }

vec2 fold6(vec2 v) {
  float a = abs(armAngle(v));
  return length(v) * vec2(cos(a), sin(a));
}

float flakeShape(vec2 v) {
  vec2 q = fold6(v);
  float d = length(q) - 0.38;
  d = min(d, max(abs(q.y) - 0.12 + 0.05 * q.x, q.x - 0.9));
  d = min(d, segment(q, vec2(0.46, 0.0), vec2(0.61, 0.25)) - 0.072);
  d = min(d, segment(q, vec2(0.7, 0.0), vec2(0.79, 0.15)) - 0.058);
  d = min(d, length(q - vec2(0.9, 0.0)) - 0.095);
  return d;
}

float holes(vec2 v) {
  vec2 q = fold6(v);
  float h = min(length(q - vec2(0.24, 0.0)) - 0.05, length(q - vec2(0.24, 0.14)) - 0.035);
  return min(h, length(q) - 0.07);
}

// the flake and its hanging tab, which ends at the top of the frame
float flake(vec2 S, vec2 c, float sc) {
  float tab = max(abs(S.x - c.x) - 0.02 * sc, max(c.y + 0.9 * sc - S.y, S.y - 1.0));
  return min(flakeShape((S - c) / sc) * sc, tab);
}

// the sheet point seen at Q on the hanging flake, which turns about the vertical through the tab
vec2 hang(vec2 Q, vec2 tab, float ang, float squeeze) {
  vec2 d = rot(ang) * (Q - tab);
  return tab + vec2(d.x / squeeze, d.y);
}

vec2 sheet(vec2 Q, float t) {
  return rot(0.15 * t) * (Q + vec2(0.0, 2.6 * t - 1.0)) + vec2(0.0, 1.0);
}

float cutSweep(vec2 v, float t) { return step(fract(atan(v.x, v.y + 1e-6) * 0.5 / PI + 1.0), t); }

vec4 transition(vec2 uv) {
  float p = progress, R = ratio;
  vec2 Q = vec2(uv.x * R, uv.y);
  float sc = size * min(1.0, R * 1.1);
  vec2 c = vec2(0.5 * R, 0.97 - 0.9 * sc);
  vec2 tab = vec2(c.x, 1.0);

  float cutT = 1.2 * smoothstep(0.0, 0.13, p) - 0.1;
  float cutA = smoothstep(0.0, 0.05, p) * (1.0 - smoothstep(0.75, 0.95, p));
  float wasteT = drop((p - 0.13) / 0.34);
  float holeT = drop((p - 0.26) / 0.3);
  float s = clamp((p - 0.36) / 0.64, 0.0, 1.0);
  float fall = drop((p - 0.7) / 0.3);
  float ang = 0.3 * sin(s * 10.0) * exp(-3.5 * s) * smoothstep(0.0, 0.12, s) + 0.6 * fall;
  float turn = 0.5 * sin(s * 7.0 + 0.6) * exp(-2.5 * s) * smoothstep(0.0, 0.15, s) + 1.1 * fall;
  float squeeze = cos(turn);
  float lift = smoothstep(0.08, 0.3, p);
  vec2 drop2 = vec2(0.0, 2.2 * fall);

  vec4 col = getToColor(uv);
  vec2 Ssh = hang(Q - SHADOW + drop2, tab, ang, squeeze);
  float fsh = max(flake(Ssh, c, sc), -holes((Ssh - c) / sc) * sc);
  col.rgb *= 1.0 - 0.4 * lift * smoothstep(0.02, -0.02, fsh);

  vec2 W = sheet(Q, wasteT);
  vec2 Wsh = sheet(Q - SHADOW, wasteT);
  col.rgb *= 1.0 - 0.35 * smoothstep(0.0, 0.1, wasteT) * smoothstep(-0.03, 0.03, min(frameDist(Wsh), flake(Wsh, c, sc)));
  float f = flake(W, c, sc);
  vec4 a = getFromColor(clamp(vec2(W.x / R, W.y), 0.0, 1.0));
  a.rgb *= 1.0 - 0.45 * cutA * smoothstep(0.004, 0.0, f) * cutSweep(W - c, cutT);
  col = mix(col, a, aa(f) * aa(frameDist(W)));

  vec2 H = Q + vec2(0.0, 2.6 * holeT);
  float h = holes((H - c) / sc) * sc;
  a = getFromColor(clamp(vec2(H.x / R, H.y), 0.0, 1.0));
  a.rgb *= 1.0 - 0.45 * cutA * smoothstep(0.004, 0.0, -h);
  col = mix(col, a, aa(-h));

  vec2 S = hang(Q + drop2, tab, ang, squeeze);
  vec2 v = (S - c) / sc;
  f = flake(S, c, sc);
  h = holes(v) * sc;
  float edge = min(-f, h);
  a = getFromColor(clamp(vec2(S.x / R, S.y), 0.0, 1.0));
  // folded paper: each arm is lit a little differently on either side of its crease
  float aA = armAngle(v);
  float crease = sign(aA) * smoothstep(0.0, 0.02, abs(aA) * length(v)) * smoothstep(0.0, 0.02, (PI / 6.0 - abs(aA)) * length(v));
  a.rgb *= 1.0 + lift * (0.04 * crease - 0.12 * abs(sin(turn)));
  a.rgb = mix(a.rgb, PAPER, 0.65 * lift * (1.0 - smoothstep(0.0, 0.0035, edge)));
  a.rgb *= 1.0 - 0.45 * cutA * (1.0 - lift) * smoothstep(0.004, 0.0, edge) * max(cutSweep(v, cutT), step(h, 0.01));
  col = mix(col, a, aa(-f) * aa(h) * aa(frameDist(S)));
  return col;
}
