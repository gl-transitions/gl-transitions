// Author: gre
// License: MIT
// Description: The outgoing image comes apart like interlaced lines of data: its even rows slide up and its odd rows slide down into two half-height copies, each copy splits again into four, then eight; the copies flip over to the incoming image, whose rows interleave back into one picture
// Tags: stripes, interlace, split, flip, 3d, graphic

// @range(1, 4, 1) Number of splitting rounds: the image ends up as 2, 4, 8 or 16 copies
uniform int stages; // = 3
// @color Color showing between the rows while they are apart
uniform vec4 gap; // = vec4(0.08, 0.08, 0.09, 1.0)

const float PI = 3.14159265;

float ease3(float x) {
  x = clamp(x, 0.0, 1.0);
  float y = 2.0 - 2.0 * x;
  return x < 0.5 ? 4.0 * x * x * x : 1.0 - 0.5 * y * y * y;
}

// inverse of one round at amount a: in each block of B rows, even rows gather in its top half, odd rows in its bottom half
float unweave(float z, float B, float a, inout float lit) {
  float bo = floor(z / B) * B;
  float lz = z - bo;
  float c = 1.0 - 0.5 * a;
  float off = a * (B - 1.0) * 0.5;
  // rows of one parity are at least one row apart, so only the last one starting before lz can cover it
  float io = floor((lz - off) / c);
  float ko = io - mod(io + 1.0, 2.0);
  float f = lz - ko * c - off;
  if (ko >= 1.0 && ko < B && f < 1.0) return bo + ko + f;
  float ie = floor(lz / c);
  float ke = ie - mod(ie, 2.0);
  f = lz - ke * c;
  if (ke >= 0.0 && ke < B && f < 1.0) {
    // dimming the even rows while they move makes the odd ones read as passing over them
    lit *= 1.0 - 0.25 * sin(PI * a);
    return bo + ke + f;
  }
  lit = -1.0;
  return z;
}

vec4 transition(vec2 uv) {
  float S = clamp(float(stages), 1.0, 4.0);
  // built by doubling so block sizes stay exact integers
  float copies = 1.0;
  for (int i = 0; i < 4; i++) {
    if (float(i) < S) copies *= 2.0;
  }
  // rows per copy: at least 6, and at least 48 rows over the frame
  float rows = max(6.0, 48.0 / copies);
  float M = rows * copies;
  float z = (1.0 - uv.y) * M;
  float band = floor(z / rows);
  float th = PI * ease3((progress - 0.43 - 0.07 * band / (copies - 1.0)) / 0.07);
  float ca = cos(th);
  bool inc = ca < 0.0;
  // each copy flips about its horizontal axis, seen from 2.5 frame heights away
  float kp = sin(th) * sign(ca) / (2.5 * copies);
  float ys = fract(z / rows) - 0.5;
  float v = ys / max(abs(ca) - ys * kp, 1e-4);
  float x = 0.5 + (uv.x - 0.5) * (1.0 + v * kp);
  z = (band + 0.5 + clamp(v, -0.5, 0.4999)) * rows;
  float q = clamp((inc ? 1.0 - progress : progress) / 0.43, 0.0, 1.0);
  // rounds overlap so the rows never stop between them
  float w = 1.0 / (0.6 * (S - 1.0) + 1.0);
  float lit = 1.0;
  float B = 2.0 * rows;
  for (int i = 4; i >= 1; i--) {
    if (float(i) > S) continue;
    z = unweave(z, B, ease3((q - 0.6 * w * float(i - 1)) / w), lit);
    if (lit < 0.0) break;
    B *= 2.0;
  }
  vec2 p = vec2(x, 1.0 - z / M);
  vec4 c = inc ? getToColor(p) : getFromColor(p);
  c.rgb *= max(lit, 0.0) * (0.55 + 0.45 * abs(ca));
  float aa = 400.0 / copies;
  float edge = clamp((0.5 - abs(v)) * aa + 1.0, 0.0, 1.0) * clamp((0.5 - abs(x - 0.5)) * 400.0 * ratio + 1.0, 0.0, 1.0);
  return mix(gap, c, step(0.0, lit) * edge);
}
