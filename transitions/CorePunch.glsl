// Author: gre
// License: MIT
// Description: The outgoing image is a thick solid block: a round core is scored in its middle and punched straight back through it, showing the bore's shaded walls, and drops away behind; then a wider ring is punched out around the hole, then another, until the outer frame is punched back and falls, leaving the incoming image
// Tags: 3d, punch, core, rings, depth, shadow, physical

// @range(0.05, 0.8) Thickness of the block, in frame heights
uniform float thickness; // = 0.35
// @range(0, 1) How much the bore walls and the punched pieces darken
uniform float shading; // = 0.7

const int N = 4;
const float EYE = 2.2;
const float SCORE = 0.25;
const float FALL = 0.6;
const vec3 L = vec3(-0.45, 0.65, 0.61);

const float BEAT = 1.0 / (float(N) + FALL);

float localU(int k) {
  return (progress - float(k) * BEAT) / BEAT;
}

// the last piece is the outer frame; the rings stay inside the shorter side so the frame is one piece
float outerR(int k, float hmin) {
  return k >= N - 1 ? 1e3 : hmin * (0.3 + 0.28 * float(k));
}

float lit(vec3 n) {
  return mix(1.0, (0.3 + 0.7 * max(dot(n, L), 0.0)) / (0.3 + 0.7 * L.z), shading);
}

// exit (x) and entry (y) depths where the ray q(d) = b + a d crosses the circle of radius r
vec2 crossings(vec2 a, vec2 b, float r) {
  float A = dot(a, a);
  float B = dot(a, b);
  float C = dot(b, b) - r * r;
  float disc = B * B - A * C;
  if (A < 1e-9 || disc < 0.0) return vec2(-1.0);
  float sq = sqrt(disc);
  // each root in its cancellation-free form
  float far = B > 0.0 ? -C / (B + sq) : (sq - B) / A;
  float near = B < 0.0 ? C / (sq - B) : -(B + sq) / A;
  return vec2(far, near);
}

vec3 rotX(vec3 v, float c, float s) {
  return vec3(v.x, c * v.y - s * v.z, s * v.y + c * v.z);
}

float score(vec2 q, float hmin) {
  float g = 1.0;
  for (int k = 0; k < N - 1; k++) {
    float u = localU(k);
    float sc = smoothstep(0.0, SCORE, u) * (1.0 - smoothstep(SCORE, SCORE + 0.25, u));
    g *= 1.0 - 0.7 * sc * (1.0 - smoothstep(0.0015, 0.004, abs(length(q) - outerR(k, hmin))));
  }
  return g;
}

// the nearest surface of piece k on the ray through p: (ray parameter or 1e4, light, point of the picture)
vec4 hitPiece(int k, vec2 p, float T, float hmin) {
  float u = localU(k);
  float t = clamp((u - SCORE) / (1.0 - SCORE), 0.0, 1.0);
  bool frame = k == N - 1;
  // the frame starts to topple while it is still being pushed back
  float w0 = frame ? 0.6 : 1.0;
  float w = clamp((u - w0) / (1.0 + FALL - w0), 0.0, 1.0);
  if (w >= 1.0) return vec4(1e4);
  float s = T * (1.0 - (1.0 - t) * (1.0 - t) * (1.0 - t)) + 0.3 * w;
  // enough to carry even the top of the toppled frame below the picture
  float drop = (1.3 + 1.2 * T) * w * w;
  // the rings tumble about their centre, the frame topples back over its bottom edge
  float tilt = frame ? -1.2 * w * w : -1.4 * w;
  vec3 pv = frame ? vec3(0.0, -0.5, -T) : vec3(0.0, 0.0, -0.5 * T);
  float c = cos(tilt), sn = sin(tilt);
  vec3 ol = rotX(vec3(0.0, drop, EYE + s) - pv, c, -sn) + pv;
  vec3 dl = rotX(vec3(p, -EYE), c, -sn);
  float rin = k == 0 ? 0.0 : outerR(k - 1, hmin);
  float rout = outerR(k, hmin);
  float sink = 1.0 - (frame ? 0.2 : 0.5) * shading * smoothstep(0.0, T, s);
  vec2 hw = vec2(0.5 * ratio, 0.5);
  vec4 best = vec4(1e4);

  if (abs(dl.z) > 1e-6) {
    // the front face, or the back one once the piece has turned it toward the eye
    bool front = dl.z < 0.0;
    float r = ((front ? 0.0 : -T) - ol.z) / dl.z;
    vec2 q = ol.xy + r * dl.xy;
    float rq = length(q);
    bool onFace = frame ? abs(q.x) <= hw.x && abs(q.y) <= hw.y : rq <= rout;
    if (r > 0.0 && rq >= rin && onFace) {
      float l = front ? sink * (t > 0.0 ? 1.0 : score(q, hmin)) : 0.6 * sink;
      best = vec4(r, lit(rotX(vec3(0.0, 0.0, front ? 1.0 : -1.0), c, sn)) * l, q);
    }
  }
  if (k > 0) {
    float r = crossings(dl.xy, ol.xy, rin).x;
    float z = ol.z + r * dl.z;
    if (r > 0.0 && z <= 0.0 && z >= -T && r < best.x) {
      vec2 q = ol.xy + r * dl.xy;
      float rim = 1.0 - smoothstep(0.0, 0.012, -z);
      float l = lit(rotX(vec3(-q / rin, 0.0), c, sn)) * (1.0 - 0.6 * shading * -z / T) + 0.3 * shading * rim;
      best = vec4(r, l * sink, q);
    }
  }
  if (!frame) {
    float r = crossings(dl.xy, ol.xy, rout).y;
    float z = ol.z + r * dl.z;
    if (r > 0.0 && z <= 0.0 && z >= -T && r < best.x) {
      vec2 q = ol.xy + r * dl.xy;
      best = vec4(r, lit(rotX(vec3(q / rout, 0.0), c, sn)) * sink, q);
    }
  } else {
    // the frame's outer sides, each seen only from outside
    for (int i = 0; i < 4; i++) {
      vec2 n = i == 0 ? vec2(0.0, 1.0) : i == 1 ? vec2(0.0, -1.0) : i == 2 ? vec2(1.0, 0.0) : vec2(-1.0, 0.0);
      float dn = dot(dl.xy, n);
      if (dn >= 0.0) continue;
      float r = (dot(hw, abs(n)) - dot(ol.xy, n)) / dn;
      vec3 x = ol + r * dl;
      vec2 off = abs(x.xy) - hw;
      if (r > 0.0 && x.z <= 0.0 && x.z >= -T && dot(off, abs(n.yx)) <= 0.0 && r < best.x) {
        vec2 q = x.xy - n * 0.001;
        best = vec4(r, lit(rotX(vec3(n, 0.0), c, sn)) * (1.0 - 0.4 * shading * -x.z / T) * sink, q);
      }
    }
  }
  return best;
}

vec4 scene(vec2 p, vec4 back, float T, float hmin) {
  vec4 best = vec4(1e4);
  for (int k = 0; k < N; k++) {
    vec4 h = hitPiece(k, p, T, hmin);
    if (h.x < best.x) best = h;
  }
  if (best.x > 1e3) return back;
  vec4 c = getFromColor(best.zw / vec2(ratio, 1.0) + 0.5);
  return vec4(c.rgb * min(best.y, 1.15), c.a);
}

vec4 transition(vec2 uv) {
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  float T = max(thickness, 0.01);
  float hmin = 0.5 * min(ratio, 1.0);
  vec4 back = getToColor(uv);
  // 2x2 supersampling for the edges, collapsing to one point at both ends
  float j = 0.0012 * sin(3.14159265 * progress);
  return 0.25 * (scene(p + vec2(-j, -j), back, T, hmin) + scene(p + vec2(j, -j), back, T, hmin)
    + scene(p + vec2(-j, j), back, T, hmin) + scene(p + vec2(j, j), back, T, hmin));
}
