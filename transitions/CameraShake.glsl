// Author: gre
// License: MIT
// Description: The camera jolts violently in random directions, with motion blur and color fringes along each jolt; the cut happens at the peak of the shake, which then settles on the incoming image
// Tags: shake, camera, motion-blur, chromatic, impact

// @range(0, 1) How far the camera jolts (and rolls) at the peak of the shake
uniform float strength; // = 0.5
// @range(4, 32) Number of jolts over the transition
uniform float jolts; // = 12.0
// @range(0, 1) Length of the motion blur along each jolt
uniform float blur; // = 0.5
// @range(0, 1) How far the color channels split apart along each jolt
uniform float split; // = 0.5

const int TAPS = 10;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// the camera position at jolt key k: offset (x, y) and roll, each in -1..1
vec3 jolt(float k) {
  // successive jolts go in nearly opposite directions
  float a = 2.4 * k + 1.2 * hash12(vec2(k, 11.0));
  float m = 0.55 + 0.45 * hash12(vec2(k, 23.0));
  return vec3(m * cos(a), m * sin(a), 2.0 * hash12(vec2(k, 37.0)) - 1.0);
}

// how strong the shake is at time t: it builds up quickly, peaks around the cut, then settles
float envelope(float t) {
  float h = clamp(1.6 * (1.0 - abs(2.0 * t - 1.0)), 0.0, 1.0);
  return h * h * (3.0 - 2.0 * h);
}

// the image seen by the camera at time t (in progress units), premultiplied
vec4 shot(vec2 uv, float t, bool incoming) {
  float env = envelope(t);
  // a key every 1/jolts, one of them exactly at the cut
  float s = (t - 0.5) * jolts;
  float k = floor(s);
  float g = 1.0 - (s - k);
  float e = 1.0 - g * g * g; // snaps to the next key, then holds
  vec3 j = mix(jolt(k), jolt(k + 1.0), e) * env;
  float omax = 0.14 * strength * env;
  float rmax = 0.07 * strength * env;
  vec2 off = j.xy * omax;
  float roll = j.z * rmax;
  // zoom in just enough that the frame edges never show, for any offset and roll up to these
  float zoom = (cos(rmax) + sin(rmax) * max(ratio, 1.0 / ratio)) / (1.0 - 2.0 * omax);
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  q = mat2(cos(roll), sin(roll), -sin(roll), cos(roll)) * q / zoom;
  vec2 p = mirror(q / vec2(ratio, 1.0) + 0.5 + off);
  vec4 c = incoming ? getToColor(p) : getFromColor(p);
  return vec4(c.rgb * c.a, c.a);
}

vec4 transition(vec2 uv) {
  // the exposure follows the shake: no blur at the very ends
  float open = envelope(progress);
  float shutter = 0.8 * blur / jolts * open;
  float lag = 0.2 * split / jolts * open;
  // each channel, premultiplied, and its alpha
  vec2 sumR = vec2(0.0);
  vec2 sumG = vec2(0.0);
  vec2 sumB = vec2(0.0);
  float wsum = 0.0;
  for (int i = 0; i < TAPS; i++) {
    float u = (float(i) + 0.5) / float(TAPS) - 0.5;
    float t = progress + u * shutter;
    // the trails fade out at both ends of the exposure
    float w = 1.0 - 1.4 * abs(u);
    // the cut happens during the exposure: the channels of a tap show the same image
    bool incoming = t >= 0.5;
    // red leads and blue trails the motion, so they split by the speed of the jolt
    vec4 r = shot(uv, t + lag, incoming);
    vec4 c = shot(uv, t, incoming);
    vec4 b = shot(uv, t - lag, incoming);
    sumR += w * r.ra;
    sumG += w * c.ga;
    sumB += w * b.ba;
    wsum += w;
  }
  float alpha = (sumR.y + sumG.y + sumB.y) / (3.0 * wsum);
  if (alpha <= 0.0) return vec4(0.0);
  vec3 color = vec3(
    sumR.x / max(sumR.y, 1e-5),
    sumG.x / max(sumG.y, 1e-5),
    sumB.x / max(sumB.y, 1e-5)
  );
  return vec4(color, alpha);
}
