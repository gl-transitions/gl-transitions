// Author: gre
// License: MIT
// Description: The outgoing image is pinched at one point like a handkerchief: its sides drop and swing in under the pinch, gathering into hanging pleats, then it is let go and falls down out of the frame, revealing the incoming image behind its shadow
// Tags: fabric, fold, gravity, shadow

// Point where the cloth is pinched
uniform vec2 center; // = vec2(0.5, 0.8)
// @range(4, 24, 1) Number of pleats hanging from the pinch
uniform float pleats; // = 9.0
// @range(0, 1) Depth of the pleats and of their shading
uniform float depth; // = 0.8
// @range(0, 1) How far the hanging cloth swings before it settles
uniform float swing; // = 0.5
// @range(0, 1) Darkness of the soft shadow cast on the incoming image
uniform float shadow; // = 0.6

const float PI = 3.14159265;

// width of the hanging fan (1 = flat picture, small = cloth hanging straight down) at distance r from the pinch
float fanWidth(float t, float r) {
  // the far cloth swings a longer arc and arrives later, so the hem lags behind in a curve
  float a = clamp((t - 0.03 - 0.1 * r) / 0.45, 0.0, 1.0);
  // the sides start slowly as they fall, swing in past the vertical and come back
  float s = a * a * (3.0 - 2.0 * a) + 0.15 * sin(PI * a) * a * a;
  // when let go, air pushes the hem up and the folds open a little
  float m = smoothstep(0.5, 1.0, t);
  return mix(1.0, 0.3, s) + 0.12 * m * min(r, 1.0);
}

float pleatPhase(float th) {
  return floor(pleats + 0.5) * th + 0.8 * sin(3.0 * th + 1.0) + 0.5 * sin(5.0 * th + 2.0);
}

// angle of d away from straight down below the pinch, in -PI..PI
float hangAngle(vec2 d, float sway) {
  float th = abs(d.x) + abs(d.y) > 0.0 ? atan(d.x, -d.y) : 0.0;
  return mod(th - sway + PI, 2.0 * PI) - PI;
}

// xy: point of the outgoing image (aspect units), z: gathering (0 flat .. 1 hanging), w: distance to the fan edge
vec4 cloth(vec2 d, float t, vec2 P, float sway) {
  float r = length(d);
  float th = hangAngle(d, sway);
  float w = fanWidth(t, r);
  float th0 = th / w;
  float A = clamp((1.0 - w) / 0.7, 0.0, 1.0);
  // pleats fold the angle back and forth, so the extra width hides in the folds
  // (not at the fan's edges, which stay on the image's top edge above the pinch)
  float k = pleatPhase(th0);
  float th1 = th0 + 0.9 * A * sin(k) * smoothstep(0.0, 0.3, PI - abs(th0)) / floor(pleats + 0.5);
  // more cloth hangs along the valleys: the hem turns scalloped
  float r0 = r * (1.0 + 0.12 * A * (0.5 - 0.5 * cos(k)));
  vec2 o = P + r0 * vec2(sin(th1), -cos(th1));
  return vec4(o, A, (PI * w - abs(th)) * r);
}

vec4 transition(vec2 uv) {
  float t = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 P = center * asp;
  // let go: it falls with gravity, out through the bottom
  float m = clamp((t - 0.52) / 0.48, 0.0, 1.0);
  vec2 C = P - vec2(0.0, m * m * (P.y + 0.25));
  // it swings on the pinch, settles, then tips a little as it falls
  float a = clamp((t - 0.1) / 0.45, 0.0, 1.0);
  float sway = swing * (0.22 * sin(2.6 * PI * a) * (1.0 - a) * a * 3.0 - 0.08 * m);

  vec2 d = uv * asp - C;
  float r = length(d);
  vec4 c = cloth(d, t, P, sway);
  vec2 src = c.xy / asp;
  vec2 bd = min(src, 1.0 - src) * asp;
  // antialiased edge (no edge on the frame's border at the start)
  float e = 0.002 * (1.0 + 2.0 * c.z) * min(1.0, 30.0 * t) + 1e-5;
  float cov = clamp(min(bd.x, bd.y) / e + 0.5, 0.0, 1.0);
  // the opening above the pinch, filtered over the pixel: x is the distance to the seam
  // straight above the pinch and h the opening's half width, so nothing opens while the fan is flat
  float w = fanWidth(t, r);
  float h = PI * (1.0 - w) * r;
  float x = c.w + h;
  cov *= 1.0 - clamp((min(x + 0.5 * e, h) - max(x - 0.5 * e, -h)) / e, 0.0, 1.0);

  vec4 img = vec4(0.0);
  if (cov > 0.0) {
    img = getFromColor(clamp(src, 0.0, 1.0));
    float th = hangAngle(d, sway) / w;
    float N = floor(pleats + 0.5);
    float k = pleatPhase(th);
    float amp = 0.6 + 0.4 * sin(2.0 * th + 2.5) * sin(3.0 * th + 0.7);
    // the pleats deepen away from the pinch, where the cloth hangs looser
    float A = sqrt(c.z) * depth * amp * smoothstep(0.0, 0.25, r);
    // each pleat has a lit wall and a turned-away wall, with a crisp crease between them
    float aw = 0.003 * N / max(r * w, 1e-3) + 0.05;
    float face = clamp(sin(k) / aw, -1.0, 1.0);
    float valley = pow(0.5 - 0.5 * cos(k), 3.0);
    float shade = 1.0 + A * (0.45 * face * (0.4 + 0.6 * abs(sin(k))) - 0.55 * valley);
    // bright knot at the pinch, cloth turning away into shade toward the hem
    shade += 0.2 * depth * c.z * (1.0 - smoothstep(0.0, 0.06, r));
    shade -= 0.15 * depth * c.z * smoothstep(0.2, 1.0, r);
    // the free sides roll away from the light where the cloth opens above the pinch
    shade -= 0.35 * depth * sqrt(c.z) * exp(-c.w / 0.025);
    img.rgb *= max(shade, 0.0);
    if (cov >= 1.0) return img;
  }

  vec4 bg = getToColor(uv);
  float lift = sin(PI * t);
  if (lift > 0.0) {
    // soft shadow on the incoming image, offset down and to the right
    vec4 cs = cloth(d - vec2(0.03, -0.035), t, P, sway);
    vec2 ss = cs.xy / asp;
    vec2 sb = min(ss, 1.0 - ss) * asp;
    float sh = smoothstep(-0.05, 0.04, min(min(sb.x, sb.y), cs.w));
    // and a darker contact shade in the opening above the pinch, so it reads as a fold, not a crack
    float edge = (hangAngle(d, sway) < 0.0 ? -PI : PI) * w * 0.999 + sway;
    vec2 es = cloth(r * vec2(sin(edge), -cos(edge)), t, P, sway).xy / asp;
    vec2 eb = min(es, 1.0 - es) * asp;
    float gap = (1.0 - m * m) * smoothstep(-0.01, 0.0, -c.w) * (1.0 - smoothstep(0.0, 0.05, -c.w));
    gap *= smoothstep(-0.01, 0.01, min(eb.x, eb.y));
    bg.rgb *= (1.0 - shadow * 0.55 * sh * lift) * (1.0 - shadow * 0.55 * gap);
  }
  return mix(bg, img, cov);
}
