// Author: gre
// License: MIT
// Description: A slide projector changes slides: the outgoing picture is jerked up out of the frame, blurring as it leaves the focal plane, the bare lamp flickers on the screen for an instant, then the incoming picture drops in from the top, bounces and hunts for focus before it sharpens
// Tags: retro, projector, slide, vertical, bounce, focus, flicker

// @range(0, 1) How high the incoming slide bounces when it lands in the gate
uniform float bounce; // = 0.5
// @range(0, 1) How out of focus the slides get while they move
uniform float defocus; // = 0.5
// @range(0, 1) How much the lamp flickers during the change
uniform float flicker; // = 0.5
// @color Color of the lamp light on the screen while the gate is empty
uniform vec4 lampColor; // = vec4(1.0, 0.95, 0.84, 1.0)

const float PI = 3.14159265;
const float MOUNT = 0.07;
const float CLEAR = 1.0 + MOUNT;
const int TAPS = 16;

float hash(float n) {
  vec3 p3 = fract(vec3(n) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// height of the outgoing picture on the screen: a short dip as the lift arm grabs the slide, then
// it is jerked up, still accelerating as it leaves the frame
float liftOut(float p) {
  float u = clamp((p - 0.05) / 0.3, 0.0, 1.0);
  float d = clamp(p / 0.12, 0.0, 1.0);
  float s = sin(PI * d);
  return CLEAR * u * u * (0.6 + 0.4 * u) - (0.004 + 0.012 * bounce) * s * s;
}

// height of the incoming picture: it falls into the gate under gravity, then makes two small hops
float dropIn(float p) {
  float v = clamp((p - 0.37) / 0.19, 0.0, 1.0);
  float y = CLEAR * (1.0 - v * v);
  float w = clamp((p - 0.56) / 0.22, 0.0, 1.0);
  float h = 0.06 * bounce;
  // hop lengths in proportion to the square root of their heights (1 and 0.15)
  float s1 = clamp(w / 0.72, 0.0, 1.0);
  float s2 = clamp((w - 0.72) / 0.28, 0.0, 1.0);
  return y + h * 4.0 * s1 * (1.0 - s1) + h * 0.15 * 4.0 * s2 * (1.0 - s2);
}

// how far out of focus the projection is (0 to 1): the outgoing slide leaves the focal plane as it
// is lifted, the incoming one lands out of focus, sharpens, overshoots and comes back sharp
float blurAmount(float p) {
  float s = clamp((p - 0.56) / 0.4, 0.0, 1.0);
  float k = 1.0 - s;
  float hunt = abs(cos(s * PI * 1.5)) * k;
  return smoothstep(0.04, 0.3, p) * (p < 0.56 ? 1.0 : hunt);
}

float band(float y, float a, float b, float aa) {
  return clamp((min(y - a, b - y)) / aa + 0.5, 0.0, 1.0);
}

// the gate seen on the screen at y (frame coordinates) with the outgoing slide at height yf and
// the incoming one at height yt, premultiplied; light is the brightness of the bare lamp there and
// shade the one of the pictures
vec4 gate(vec2 q, float yf, float yt, float light, float shade) {
  // edges get sharp as a slide comes to rest, so that it then covers the whole frame
  float af = 0.0015 * min(abs(yf) * 400.0, 1.0) + 1e-6;
  float at = 0.0015 * min(abs(yt) * 400.0, 1.0) + 1e-6;
  vec4 c = vec4(lampColor.rgb * lampColor.a * light, lampColor.a);
  float mf = band(q.y, yf - MOUNT, yf + 1.0 + MOUNT, af);
  float mt = band(q.y, yt - MOUNT, yt + 1.0 + MOUNT, at);
  c.rgb *= 1.0 - 0.96 * max(mf, mt);
  float pf = band(q.y, yf, yf + 1.0, af);
  if (pf > 0.0) {
    vec4 t = getFromColor(vec2(q.x, q.y - yf));
    c = mix(c, vec4(t.rgb * t.a * shade, t.a), pf);
  }
  float pt = band(q.y, yt, yt + 1.0, at);
  if (pt > 0.0) {
    vec4 t = getToColor(vec2(q.x, q.y - yt));
    c = mix(c, vec4(t.rgb * t.a * shade, t.a), pt);
  }
  return c;
}

vec4 transition(vec2 uv) {
  float p = progress;

  float yf = liftOut(p);
  float yt = dropIn(p);
  // vertical speed of the slide that moves (one at a time), for the motion blur
  float dp = 0.004;
  float vf = (liftOut(p + dp) - liftOut(p - dp)) / (2.0 * dp);
  float vt = (dropIn(p + dp) - dropIn(p - dp)) / (2.0 * dp);
  float smear = min(max(abs(vf), abs(vt)) * 0.012, 0.07);

  float b = blurAmount(p);
  float radius = defocus * 0.02 * b;
  float zoom = 1.0 + 0.025 * defocus * b;
  vec2 c0 = (uv - 0.5) / zoom + 0.5;

  float env = smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.72, 1.0, p));
  float fc = p * 30.0;
  float fl = mix(hash(floor(fc)), hash(floor(fc) + 1.0), smoothstep(0.3, 0.7, fract(fc)));
  vec2 d = (uv - 0.5) * vec2(ratio, 1.0) / (0.5 * sqrt(ratio * ratio + 1.0));
  float light = (1.0 - 0.3 * dot(d, d)) * (1.0 - 0.3 * flicker * fl * env);
  float shade = mix(1.0, 0.92 * light, env);

  vec4 c;
  if (radius + smear < 1e-4) {
    c = gate(c0, yf, yt, light, shade);
    return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
  }
  c = vec4(0.0);
  for (int i = 0; i < TAPS; i++) {
    float fi = float(i);
    float a = fi * 2.39996;
    vec2 o = sqrt((fi + 0.5) / float(TAPS)) * vec2(cos(a) / ratio, sin(a)) * radius;
    o.y += ((fi + 0.5) / float(TAPS) - 0.5) * smear;
    // the gate is the frame: fold the taps back so its edges stay sharp
    vec2 q = 1.0 - abs(1.0 - abs(c0 + o));
    c += gate(q, yf, yt, light, shade);
  }
  c /= float(TAPS);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
