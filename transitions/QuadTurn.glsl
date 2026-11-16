// Author: gre
// License: MIT
// Description: The image is cut into square tiles that turn in blocks of four like little turntables, a quarter turn at a time on two staggered grids, lifting over their neighbours and scrambling the outgoing image; a wave flips the tiles over to the incoming image, then the blocks turn back the same way until every tile is home
// Tags: tiles, rotate, puzzle, shuffle, flip, mechanical

// @range(3, 8, 1) Number of tiles along the short side of the frame
uniform int tiles; // = 4
// @range(0, 0.8) Delay between the first and the last block of each turn, as a part of the turn
uniform float stagger; // = 0.4
// @range(0, 1) Darkness of the shadows cast by the lifted tiles
uniform float shadow; // = 0.6
// @color Color of the tray seen under the turning blocks
uniform vec4 backColor; // = vec4(0.12, 0.12, 0.13, 1.0)

const float PI = 3.141592653589793;
const float FLIP = 1.3;
// share of the flip beat over which the wave crosses the frame; each tile flips in the rest
const float WAVE = 0.8;
const float EYE = 3.0;
const float AA = 0.015;
const vec2 SHADOW_OFFSET = vec2(0.1, -0.14);

vec2 rot(vec2 v, float a) {
  float c = cos(a), s = sin(a);
  return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// beats 0, 1 turn on grids offset by 0 then 1 tile; beat 2 flips; beats 3, 4 undo 1 then 0
float offsetOf(float i) {
  return mod(i < 2.5 ? i : 4.0 - i, 2.0);
}

float dirOf(float i) {
  return i < 2.5 ? 1.0 : -1.0;
}

bool inside(vec2 lo, float size, vec2 dims) {
  return all(greaterThanEqual(lo, vec2(0.0))) && all(lessThanEqual(lo + size, dims));
}

vec2 turn(vec2 p, float i, float way, vec2 dims) {
  float o = offsetOf(i);
  vec2 lo = o + 2.0 * floor((p - o) / 2.0);
  if (!inside(lo, 2.0, dims)) return p;
  vec2 c = lo + 1.0;
  return c + rot(p - c, way * dirOf(i) * 0.5 * PI);
}

float smooth3(float f) {
  return f * f * (3.0 - 2.0 * f);
}

float turnAngle(float f, vec2 c, float o, vec2 dims) {
  vec2 last = o + 2.0 * floor((dims - o) / 2.0) - 1.0;
  float k = c.x + 0.3 * c.y - 1.3 * (o + 1.0);
  float d = stagger * k / max(last.x + 0.3 * last.y - 1.3 * (o + 1.0), 1.0);
  return 0.5 * PI * smooth3(clamp((f - d) / (1.0 - stagger), 0.0, 1.0));
}

// doubled smoothstep rushes through the edge-on moment
float flipAngle(float f, vec2 c, vec2 dims) {
  float d = WAVE * (c.x + c.y - 1.0) / max(dims.x + dims.y - 2.0, 1.0);
  return PI * smooth3(smooth3(clamp((f - d) / (1.0 - WAVE), 0.0, 1.0)));
}

// clamped: sin(PI) is slightly negative in float
float liftOf(float a, bool flip) {
  return max(flip ? sin(a) : sin(2.0 * a), 0.0);
}

// xy: point on the card relative to its center, z: lift, w: distance to its edge on screen
vec4 card(vec2 P, vec2 c, float a, bool flip, float dir) {
  if (flip) {
    float sa = sin(a), ca = cos(a);
    float s = 1.0 + 0.2 * sa;
    vec2 d = (P - c) / s;
    float den = EYE * ca + d.x * sa;
    den = abs(den) < 1e-5 ? (den < 0.0 ? -1e-5 : 1e-5) : den;
    float x = clamp(d.x * EYE / den, -0.5, 0.5);
    float y = d.y * (EYE - x * sa) / EYE;
    float u0 = -0.5 * ca * EYE / (EYE + 0.5 * sa);
    float u1 = 0.5 * ca * EYE / (EYE - 0.5 * sa);
    float wx = min(d.x - min(u0, u1), max(u0, u1) - d.x);
    return vec4(ca < 0.0 ? -x : x, y, liftOf(a, true), s * min(wx, 0.5 - abs(y)));
  }
  float lift = liftOf(a, false);
  float s = 1.0 + 0.06 * lift;
  vec2 l = rot(P - c, -dir * a) / s;
  return vec4(l, lift, s * (1.0 - max(abs(l.x), abs(l.y))));
}

vec4 layer(vec2 Q, float a, bool flip, float beat, vec2 dims) {
  bool incoming = flip ? cos(a) < 0.0 : beat > 2.5;
  vec2 H = Q;
  if (incoming) {
    for (int i = 3; i < 5; i++) {
      if (float(i) >= beat) H = turn(H, float(i), 1.0, dims);
    }
  } else {
    for (int i = 1; i >= 0; i--) {
      if (float(i) < beat) H = turn(H, float(i), -1.0, dims);
    }
  }
  vec2 st = clamp(H / dims, 0.0, 1.0);
  vec4 col = incoming ? getToColor(st) : getFromColor(st);
  float env = sin(PI * clamp(progress, 0.0, 1.0));
  vec2 tf = abs(fract(Q) - 0.5);
  float seam = smoothstep(0.485, 0.5, max(tf.x, tf.y)) * env;
  float light = 1.0;
  if (flip) {
    float sa = sin(a), ca = cos(a);
    light = 1.0 - 0.5 * sa * sa + 0.2 * abs(ca) * sa;
  }
  col.rgb *= (1.0 - 0.5 * seam) * light;
  return col;
}

vec4 transition(vec2 uv) {
  float n = float(tiles);
  vec2 dims = ratio >= 1.0 ? vec2(floor(n * ratio + 0.5), n) : vec2(n, floor(n / ratio + 0.5));
  vec2 P = uv * dims;
  float t = progress * (4.0 + FLIP);
  float beat = t < 2.0 ? floor(t) : t < 2.0 + FLIP ? 2.0 : min(floor(t - FLIP) + 1.0, 4.0);
  float start = beat < 2.5 ? beat : beat - 1.0 + FLIP;
  bool flip = beat == 2.0;
  float f = clamp((t - start) / (flip ? FLIP : 1.0), 0.0, 1.0);

  float size = flip ? 1.0 : 2.0;
  vec2 org = vec2(flip ? 0.0 : offsetOf(beat));
  vec2 b0 = floor((P - org) / size);
  float dir = dirOf(beat);

  // two topmost cards: the second shows through the antialiased edge of the first
  vec2 q1 = P, q2 = P;
  float a1 = 0.0, a2 = 0.0, lift1 = -1.0, lift2 = -1.0, cov1 = 0.0, cov2 = 0.0;
  for (int j = 0; j < 9; j++) {
    vec2 lo = org + size * (b0 + vec2(mod(float(j), 3.0), floor(float(j) / 3.0)) - 1.0);
    if (inside(lo, size, dims)) {
      vec2 c = lo + 0.5 * size;
      float a = flip ? flipAngle(f, c, dims) : turnAngle(f, c, org.x, dims);
      vec4 k = card(P, c, a, flip, dir);
      if (k.w >= 0.0) {
        float cov = k.z > 1e-3 ? clamp(k.w / AA, 0.0, 1.0) : 1.0;
        if (k.z > lift1) {
          q2 = q1; a2 = a1; lift2 = lift1; cov2 = cov1;
          q1 = c + k.xy; a1 = a; lift1 = k.z; cov1 = cov;
        } else if (k.z > lift2) {
          q2 = c + k.xy; a2 = a; lift2 = k.z; cov2 = cov;
        }
      }
    }
  }
  // tiles outside every block of this grid stay in place, under the turning blocks
  if (!flip && !inside(org + 2.0 * b0, 2.0, dims)) {
    if (lift1 < 0.0) {
      q1 = P; a1 = 0.0; lift1 = 0.0; cov1 = 1.0;
    } else if (lift2 < 0.0) {
      q2 = P; a2 = 0.0; lift2 = 0.0; cov2 = 1.0;
    }
  }

  float shade = 0.0;
  for (int j = 0; j < 9; j++) {
    vec2 lo = org + size * (b0 + vec2(mod(float(j), 3.0), floor(float(j) / 3.0)) - 1.0);
    if (inside(lo, size, dims)) {
      vec2 c = lo + 0.5 * size;
      float a = flip ? flipAngle(f, c, dims) : turnAngle(f, c, org.x, dims);
      float lift = liftOf(a, flip);
      if (lift > lift1 + 0.01) {
        vec4 k = card(P - SHADOW_OFFSET * lift, c, a, flip, dir);
        shade = max(shade, (lift - max(lift1, 0.0)) * smoothstep(flip ? -0.08 : -0.25, 0.04, k.w));
      }
    }
  }

  vec4 col = flip ? layer(P, PI, true, beat, dims) : backColor;
  if (lift2 >= 0.0) col = mix(col, layer(q2, a2, flip, beat, dims), cov2);
  if (lift1 >= 0.0) col = mix(col, layer(q1, a1, flip, beat, dims), cov1);
  col.rgb *= 1.0 - shadow * 0.7 * shade;
  return col;
}
