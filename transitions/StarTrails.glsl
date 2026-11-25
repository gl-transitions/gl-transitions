// Author: gre
// License: MIT
// Description: The outgoing image starts to turn around a pole like the night sky in a long exposure: its lights leave trails that lengthen into concentric arcs over the smeared image, their colors change to those of the incoming image along the arcs, and the trails catch up into the sharp incoming image
// Tags: rotate, trails, long-exposure, light, motion-blur, sky

// @range(-2, 2) How far the sky turns counterclockwise, in radians
uniform float turn; // = 1.0
// @range(0.5, 2) How closely packed the trails are
uniform float density; // = 1.0
// @range(0, 2) Brightness of the trails
uniform float glow; // = 1.0
// @param Point the sky turns around
uniform vec2 pole; // = vec2(0.5, 0.58)

const int TAPS = 13;

float hash(vec2 p) {
  vec3 q = fract(vec3(p.xyx) * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

vec2 mirrored(vec2 u) {
  return 1.0 - abs(1.0 - mod(u, 2.0));
}

vec2 rot(vec2 v, float a) {
  float c = cos(a);
  float s = sin(a);
  return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

vec4 premultiplied(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec4 fromAt(vec2 v) {
  return premultiplied(getFromColor(mirrored(v / vec2(ratio, 1.0) + pole)));
}

vec4 toAt(vec2 v) {
  return premultiplied(getToColor(mirrored(v / vec2(ratio, 1.0) + pole)));
}

// share of the incoming image in the light that has turned by a part of the whole turn
float incoming(float a) {
  return smoothstep(0.3, 0.7, a);
}

// bright lights burn in more than the dark
float burn(vec4 c, float k) {
  return 1.0 + 2.5 * k * dot(c.rgb, c.rgb) / 3.0;
}

vec4 transition(vec2 uv) {
  float head = smoothstep(0.0, 0.76, progress);
  float tail = smoothstep(0.24, 1.0, progress);
  float k = smoothstep(0.03, 0.45, head - tail);
  vec2 d = (uv - pole) * vec2(ratio, 1.0);
  float r = length(d);

  // each image is averaged over its own part of the exposure
  vec2 f = min(vec2(tail, head), 0.7);
  vec2 g = max(vec2(tail, head), 0.3);
  f.y = max(f.y, f.x + 1e-5);
  g.y = max(g.y, g.x + 1e-5);
  // shifted from one thin arc to the next, the taps blend into grain that runs along the trails
  float shift = hash(vec2(floor(r * 300.0), 7.0));
  vec4 sum = vec4(0.0);
  float total = 0.0;
  for (int i = 0; i < TAPS; i++) {
    float u = (float(i) + shift) / float(TAPS);
    float a = mix(f.x, f.y, u);
    vec4 c = fromAt(rot(d, -a * turn));
    float w = (f.y - f.x) * (1.0 - incoming(a)) * burn(c, k);
    sum += w * c;
    total += w;
    a = mix(g.x, g.y, u);
    c = toAt(rot(d, (1.0 - a) * turn));
    w = (g.y - g.x) * incoming(a) * burn(c, k);
    sum += w * c;
    total += w;
  }
  vec4 col = sum / total;
  if (col.a <= 0.0) return vec4(0.0);
  col.rgb *= 1.0 - 0.45 * k;

  vec2 e = d / max(r, 1e-4);
  float middle = 0.5 * (head + tail) * turn;
  float reach = 0.5 * (head - tail) * abs(turn);
  for (int l = 0; l < 2; l++) {
    float w = (l == 0 ? 0.014 : 0.027) / max(density, 0.1);
    float ring = floor(r / w);
    float x = r / w - ring;
    float rim = smoothstep(0.0, 0.2, min(x, 1.0 - x));
    // only the brightest trail of each ring is drawn, so that only its light is read
    float best = 0.0;
    float at = 0.0;
    vec2 home = vec2(0.0);
    for (int j = 0; j < 6; j++) {
      vec2 id = vec2(ring + 400.0 * float(l), float(j));
      float rc = (ring + 0.3 + 0.4 * hash(id + 5.0)) * w;
      float ta = 6.2831853 * (float(j) + hash(id)) / 6.0;
      // measured from the middle of the arc, so the branch cut of atan falls on the far side
      vec2 q = rot(e, -ta - middle);
      float off = q.x < -0.9 ? 3.0 : atan(q.y, q.x);
      float on = clamp(off, -reach, reach);
      float dist = length(vec2(r - rc, (off - on) * r));
      float mag = hash(id + 31.0);
      float wide = w * mix(0.1, 0.24, mag * mag);
      float aged = mix(0.4, 1.0, 0.5 + 0.5 * on * sign(turn) / max(reach, 1e-4));
      float lit = exp(-dist * dist / (wide * wide)) * (0.3 + 0.9 * mag) * aged * rim;
      if (lit > best) {
        best = lit;
        at = on;
        home = rc * vec2(cos(ta), sin(ta));
      }
    }
    vec4 c = mix(fromAt(home), toAt(rot(home, turn)), incoming(0.5 * (head + tail) + at / (abs(turn) < 1e-3 ? 1e-3 : turn)));
    col.rgb += k * glow * best * c.rgb * (0.5 + 1.1 * dot(c.rgb, vec3(0.333)));
  }
  return vec4(min(col.rgb / col.a, 1.0), col.a);
}
