// Author: gre
// License: MIT
// Description: Faint mortar joints turn the outgoing image into a brick wall: one brick of the bottom course is yanked out downward, the steep wedge of bricks it held drops through the hole, and the collapse spreads sideways course by course until the last bricks at the edges tumble out and the incoming image stands where the wall was
// Tags: bricks, wall, collapse, fall, gravity, physical

// @range(3, 12, 1) Number of brick courses along the short side of the frame
uniform int rows; // = 7
// @range(0, 1) Horizontal position of the pulled brick
uniform float origin; // = 0.5
// @range(0, 1) Darkness of the mortar joints, brick edges and shadows
uniform float shading; // = 0.6

const float G = 14.0;
const float PULL = 0.16;
const float EDGE = 0.0012;

float hash(vec2 p) {
  vec3 q = fract(p.xyx * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

mat2 rot(float a) {
  float c = cos(a), s = sin(a);
  return mat2(c, -s, s, c);
}

float courseOffset(float r, float bw) {
  return mod(r, 2.0) * 0.5 * bw;
}

// when brick i of course r starts to fall, -1 for the pulled brick
float fallStart(float r, float i, float bh, float bw, float x0, float reach) {
  float d = abs((i + 0.5) * bw + courseOffset(r, bw) - x0);
  if (r < 0.5 && d < 0.5 * bw) return -1.0;
  // the bricks the pulled one held form a steep wedge; outside it, the collapse spreads sideways
  float v = 0.5 * bw + 0.3 * r * bh * min(ratio, 1.0);
  float far = max(reach - v, bw);
  // the latest start that still lets the brick, grown and spun, fall out of the frame before the end
  float deadline = 0.95 - sqrt((r + 3.0) * bh / G);
  float excess = max(d - v, 0.0);
  float jitter = 0.05 * (hash(vec2(i, r) + 3.7) - 0.5) * step(0.001, excess);
  return mix(PULL * 0.7 + r * bh * 0.2, deadline, clamp(excess / far + jitter, 0.0, 1.0));
}

float rectCover(vec2 q, vec2 halfSize, float soft) {
  vec2 d = halfSize - abs(q);
  return clamp(min(d.x, d.y) / soft + 0.5, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  float bh = min(ratio, 1.0) / clamp(float(rows), 1.0, 12.0);
  float bw = 2.1 * bh;
  vec2 hs = vec2(0.5 * bw, 0.5 * bh);
  vec2 P = vec2(uv.x * ratio, uv.y);
  float x0 = (clamp(floor(clamp(origin, 0.0, 1.0) * ratio / bw), 0.0, max(floor(ratio / bw - 0.5), 0.0)) + 0.5) * bw;
  float reach = max(x0, ratio - x0);
  float k = clamp(shading, 0.0, 1.0);
  float appear = smoothstep(0.0, 0.06, progress);

  float ao = 0.0, shadow = 0.0;
  vec4 wall = vec4(0.0);
  float wallCov = 0.0;
  vec4 fall = vec4(0.0);
  float fallCov = 0.0, fallGrow = 0.0;

  for (int j = 0; j < 48; j++) {
    float r = float(j);
    if (r * bh >= 1.0) break;
    // bricks only fall, so a course well below P can't reach it
    if (P.y - (r + 0.5) * bh > bw) continue;
    float off = courseOffset(r, bw);
    for (int n = -1; n < 2; n++) {
      float i = floor((P.x - off) / bw) + float(n);
      float t0 = fallStart(r, i, bh, bw, x0, reach);
      vec2 home = vec2((i + 0.5) * bw + off, (r + 0.5) * bh);
      vec2 q;
      float s, grow = 1.0;
      vec2 shadowOffset = vec2(0.0);
      if (t0 < 0.0) {
        s = clamp(progress / PULL, 0.0, 1.0);
        q = P - home + vec2(0.0, 1.1 * bh * s * s);
      } else {
        s = max(progress - t0, 0.0);
        float spin = (hash(vec2(i, r) + 1.3) - 0.5) * 2.2 * G * s * s;
        float drift = sign(x0 - home.x) * 0.25 * G * s * s * bh;
        // the bricks topple forward, toward the eye, and cast their shadow on what is behind
        grow = 1.0 + 0.7 * s;
        mat2 m = rot(spin);
        q = m * (P - home - vec2(drift, -G * s * s)) / grow;
        shadowOffset = m * vec2(0.25, -0.45) * bh * min(4.0 * s, 1.0) / grow;
      }
      float falling = step(0.0001, s);
      float moving = smoothstep(0.0, 0.05, s);
      float e = min(hs.x - abs(q.x), hs.y - abs(q.y));
      if (falling > 0.0) {
        float soft = 0.15 * bh * min(4.0 * s, 1.0) + EDGE;
        shadow = max(shadow, rectCover(q - shadowOffset, hs, soft / grow) * min(8.0 * s, 1.0));
      }
      // standing bricks overlap by a hair so that rounding leaves no seam
      if (e < -1e-4 - 0.5 * EDGE * moving / grow) {
        ao = max(ao, exp(e / (0.25 * bh)) * appear * (1.0 - moving));
        continue;
      }
      vec2 src = home + q;
      // the frame cuts the wall's edge bricks: their part outside it is never drawn
      vec4 b = getFromColor(falling > 0.0 ? vec2(src.x / ratio, src.y) : uv);
      vec2 inFrame = clamp(min(src, vec2(ratio, 1.0) - src) * grow / EDGE + 1.0, 0.0, 1.0);
      vec2 l = q / vec2(bw, bh) + 0.5;
      float lit = min(s * 8.0, 1.0);
      float joint = 1.0 - smoothstep(0.0, 0.004 + 0.004 * lit, e);
      b.rgb *= 1.0 - 0.45 * k * joint * appear;
      b.rgb *= 1.0 + 0.25 * k * lit * (l.y - l.x);
      b.rgb *= 1.0 - 0.35 * k * falling * min(s * 4.0, 1.0) * (1.0 - l.y);
      if (falling > 0.0) {
        float a = mix(1.0, clamp(e * grow / EDGE + 0.5, 0.0, 1.0), moving) * inFrame.x * inFrame.y;
        // the brick that has grown most is nearest to the eye
        if (grow > fallGrow) {
          float nc = a + fallCov * (1.0 - a);
          if (nc > 0.0) fall = mix(fall, b, a / nc);
          fallCov = nc;
          fallGrow = grow;
        } else {
          float w = a * (1.0 - fallCov);
          fallCov += w;
          if (w > 0.0) fall = mix(fall, b, w / fallCov);
        }
      } else {
        wall = b;
        wallCov = 1.0;
      }
    }
  }
  vec4 c = getToColor(uv);
  c.rgb *= 1.0 - 0.55 * k * ao;
  c = mix(c, wall, wallCov);
  c.rgb *= 1.0 - 0.45 * k * shadow;
  return mix(c, fall, fallCov);
}
