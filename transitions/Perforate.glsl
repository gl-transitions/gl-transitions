// Author: gre
// License: MIT
// Description: A row of perforation holes is punched across the outgoing picture along a gentle wave; the lower half tears away along the holes from left to right, bending down behind the tear and dropping off, then the upper half tears off the top edge from right to left and falls the same way, revealing the incoming picture
// Tags: paper, tear, gravity

// @range(0, 0.12) Height of the wave of the perforation line, in frame heights
uniform float wave; // = 0.05

const float SPACING = 0.03;
const float HOLE = 0.0065;
const float RIM = 0.0025;
const vec2 SHADOW = vec2(0.02, -0.03);

float aa(float d) { return clamp(d * 400.0 + 1.0, 0.0, 1.0); }
float frameDist(vec2 S) { vec2 d = min(S, vec2(ratio, 1.0) - S); return min(d.x, d.y); }
float line(float x) { return 0.5 + wave * sin(x * 4.0 + 1.0); }
float drop(float t) { t = clamp(t, 0.0, 1.0); return t * t; }

// sheet point and bend angle seen at Q, the free part (on side dir of the tear front T) swung down about T;
// the swing grows with the screen angle around T, which keeps the map one-to-one and needs no solve
vec3 bend(vec2 Q, vec2 T, float an, float dir) {
  vec2 d = Q - T;
  d.x *= dir;
  float r = length(d);
  float a = an * smoothstep(0.0, 0.25, r) * smoothstep(-0.2, 2.2, atan(d.x, -d.y));
  float c = cos(a), s = sin(a);
  return vec3(T + vec2(dir * (d.x * c - d.y * s), d.y * c + d.x * s), a);
}

float punch(float x) {
  float t = 0.12 * x / ratio;
  return smoothstep(t, t + 0.05, progress);
}

// side: 1 for the upper half, -1 for the lower one
float lineDist(vec2 S, float side) { return side * (S.y - line(S.x)); }

// the torn edge whitens where the lower front at tornX has passed
vec4 drawPiece(vec4 col, vec3 B, float side, float tornX) {
  vec2 S = B.xy;
  float dl = lineDist(S, side);
  float cx = (floor(S.x / SPACING) + 0.5) * SPACING;
  float h = length(vec2(S.x - cx, dl)) - HOLE * punch(cx);
  float m = aa(dl) * aa(h) * aa(frameDist(S));
  if (m <= 0.0) return col;
  vec4 c = getFromColor(clamp(vec2(S.x / ratio, S.y), 0.0, 1.0));
  c.rgb *= 1.0 - 0.22 * sin(min(B.z, 1.5));
  float rim = max((1.0 - smoothstep(0.0, RIM, h)) * punch(cx), (1.0 - smoothstep(0.0, RIM, dl)) * smoothstep(0.0, 0.02, tornX - S.x));
  c.rgb = mix(c.rgb, vec3(0.93, 0.91, 0.87), 0.6 * rim);
  return mix(col, c, m);
}

float shadowOf(vec3 B, float side) {
  return smoothstep(-0.03, 0.03, min(lineDist(B.xy, side), frameDist(B.xy))) * smoothstep(0.0, 0.25, B.z);
}

vec4 transition(vec2 uv) {
  float p = progress, R = ratio;
  vec2 Q = vec2(uv.x * R, uv.y);
  float k1 = smoothstep(0.06, 0.44, p);
  float k2 = smoothstep(0.44, 0.82, p);
  // each half drops only once its tear front has left the frame
  float d1 = drop((p - 0.4) / 0.3);
  float d2 = drop((p - 0.78) / 0.22);
  float fall1 = 2.4 * d1, fall2 = 2.6 * d2;
  float an1 = 1.1 * k1 + 0.5 * d1;
  float an2 = 1.1 * k2 + 0.5 * d2;
  float x1 = R * (k1 * 1.1 - 0.05);
  vec2 T1 = vec2(x1, line(x1));
  vec2 T2 = vec2(R * (1.05 - 1.1 * k2), 1.0);

  vec4 col = getToColor(uv);
  float sh = max(
    shadowOf(bend(Q - SHADOW + vec2(0.0, fall1), T1, an1, -1.0), -1.0),
    shadowOf(bend(Q - SHADOW + vec2(0.0, fall2), T2, an2, 1.0), 1.0));
  col.rgb *= 1.0 - 0.5 * sh;

  col = drawPiece(col, bend(Q + vec2(0.0, fall1), T1, an1, -1.0), -1.0, T1.x);
  col = drawPiece(col, bend(Q + vec2(0.0, fall2), T2, an2, 1.0), 1.0, T1.x);
  return col;
}
