// Author: gre
// License: MIT
// Description: A band of intense light sweeps across the frame like a glint on glass, blooming the highlights of both images, and leaves the incoming image behind it
// Tags: wipe, light, glow, glint

// @param Direction the band of light moves toward
uniform vec2 direction; // = vec2(1.0, -0.35)
// @range(0.005, 0.2) Width of the bright core of the band, in frame heights
uniform float width; // = 0.04
// @range(0, 3) Brightness of the light
uniform float intensity; // = 1.2
// @color Tint of the light, toward the edges of the band (its core burns white)
uniform vec3 color; // = vec3(1.0, 0.86, 0.66)

const int TAPS = 12;

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// a gentle ease in and out, which does not linger at the ends
float ease(float t) {
  return 0.5 * (t + t * t * (3.0 - 2.0 * t));
}

// the image on screen at a point: the outgoing one ahead of the switch, the incoming one behind it
// (both always sampled, so that no texture read sits in a branch that differs between pixels)
vec4 frame(vec2 st, float m) {
  return mix(getFromColor(st), getToColor(st), m);
}

// the light of a pixel (premultiplied): its color above a soft knee
vec3 highlight(vec4 c) {
  float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  return c.rgb * c.a * smoothstep(0.45, 1.0, lum);
}

vec4 transition(vec2 uv) {
  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(1.0, 0.0);
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  // half extent of the frame along the direction
  float e = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
  float w = max(width, 0.001);
  float s = 0.35 * w;
  // the band starts and ends outside of the frame, with the switch out of sight
  float margin = s + 2.0 * w;
  float pos = -e - margin + 2.0 * (e + margin) * ease(progress);
  // signed distance to the middle of the band: < 0 has been swept
  float d = dot(p, dir) - pos;
  float m = 1.0 - smoothstep(-s, s, d);

  // the light ignites as it enters and dies away as it leaves: exactly none at both ends
  float env = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
  // a hot core, a thinner glint trailing behind it, and a wide soft halo
  float core = exp(-d * d / (w * w));
  float g = (d + 2.2 * w) / (0.3 * w);
  float glint = 0.45 * exp(-g * g);
  float halo = 0.35 * exp(-abs(d) / (5.0 * w));
  float band = (core + glint + halo) * env * intensity;
  // the moving glint itself, where the highlights bloom
  float glow = (core + glint) * env * intensity;

  vec4 c = frame(uv, m);

  // the highlights near the band bloom along it: taps across the band, sampled where the band is brightest
  vec3 bloom = vec3(0.0);
  // spread over the band, short enough that its taps blend into a smooth glow
  float spread = min(3.0 * w, 0.12);
  for (int i = 0; i < TAPS; i++) {
    float t = (float(i) + 0.5) / float(TAPS) * 2.0 - 1.0;
    vec2 st = mirror((p + dir * (t * spread)) / vec2(ratio, 1.0) + 0.5);
    // the image on screen where the tap reads, on the same side of the switch
    float dq = dot((st - 0.5) * vec2(ratio, 1.0), dir) - pos;
    bloom += (1.0 - abs(t)) * highlight(frame(st, 1.0 - smoothstep(-s, s, dq)));
  }
  // the sum of the tent weights
  bloom /= 0.5 * float(TAPS);

  // white at the heart of the core, tinted toward the edges of the band
  vec3 hue = mix(color, vec3(1.0), core * core);
  float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  // the light lifts the image, the bright parts more: exposure that rolls off softly to white, never clipping
  vec3 light = hue * band * (0.3 + 0.9 * lum) + hue * bloom * glow * 4.0 + hue * core * env * intensity * 1.6;
  vec3 rgb = 1.0 - (1.0 - c.rgb) * exp(-light);
  // light adds to the image, not to its alpha
  return vec4(rgb, c.a);
}
