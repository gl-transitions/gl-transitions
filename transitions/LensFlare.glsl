// Author: gre
// License: MIT
// Description: A bright light sweeps across the frame and flares the lens: a long thin horizontal streak, a glowing core and a trail of colored ghost reflections; at its peak the incoming image spreads out from the light under its glare
// Tags: light, flare, glow, streak

// @range(-90, 90) Angle of the path of the light, in degrees (0 sweeps from left to right)
uniform float angle; // = -12.0
// @range(-0.5, 0.5) How far above the center of the frame the light passes
uniform float height; // = 0.18
// @range(0, 2) Brightness of the flare
uniform float intensity; // = 1.0
// @color Color of the streak and of the glare
uniform vec3 color; // = vec3(0.35, 0.6, 1.0)

const int BLOOM_TAPS = 12;
const int GHOSTS = 6;

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 premultiplied(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

// the image on screen (premultiplied): the outgoing one, then the incoming one after the cut
vec4 frame(vec2 st, float m) {
  if (m <= 0.0) return premultiplied(getFromColor(st));
  if (m >= 1.0) return premultiplied(getToColor(st));
  return mix(premultiplied(getFromColor(st)), premultiplied(getToColor(st)), m);
}

// the light of a pixel (premultiplied): its color above a knee
vec3 highlight(vec4 c) {
  float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  return c.rgb * smoothstep(0.55, 0.95, lum);
}

vec4 transition(vec2 uv) {
  float p = progress;
  if (p <= 0.0) return getFromColor(uv);
  if (p >= 1.0) return getToColor(uv);

  // 0 at both ends, 1 at the peak
  float env = 4.0 * p * (1.0 - p);
  float peak = pow(env, 24.0);
  // frame coordinates, centered, with square units
  vec2 aspect = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * aspect;
  float r = radians(angle);
  vec2 dir = vec2(cos(r), -sin(r));
  vec2 normal = vec2(-dir.y, dir.x);
  // the light crosses the frame, slowing down as it passes the middle
  float t = p - 0.5;
  float travel = 0.5 * (abs(dir.x) * ratio + abs(dir.y)) + 0.3;
  float along = travel * (2.0 * t) * (0.55 + 1.8 * t * t);
  vec2 src = dir * along + normal * height;

  vec2 d = q - src;
  float dist = length(d);
  float k = intensity * env;

  // the cut, under the glare: the incoming image spreads out from the light in a soft circle,
  // slower as the flare gets dimmer so that it still reads as intended
  float cut = mix(0.2, 0.06, clamp(intensity, 0.0, 1.0));
  float s = clamp((p - 0.5 + cut) / (2.0 * cut), 0.0, 1.0);
  float soft = 0.3;
  float reach = 0.5 * length(aspect) + length(src) + soft;
  float front = s * (reach + soft);
  float m = smoothstep(front, front - soft, dist);
  vec4 base = frame(uv, m);

  // the anamorphic streak: long and thin, always horizontal, white at the center and tinted along
  float ax = abs(d.x);
  float ay = abs(d.y);
  float thin = exp(-ay * 140.0) * exp(-ax * 0.7);
  float wide = exp(-ay * 30.0) * exp(-ax * 1.6);
  vec3 tint = color;
  vec3 streak = (thin * mix(vec3(1.0), tint, smoothstep(0.0, 0.3, ax)) + 0.5 * wide * tint) * 3.0;

  // the core and its halo
  vec3 core = vec3(1.0, 0.97, 0.92) * exp(-dist * dist * 600.0) * 3.0 + mix(vec3(1.0), tint, 0.5) * exp(-dist * 7.0) * 0.6;

  // ghosts on the line from the light through the center of the frame
  vec3 ghosts = vec3(0.0);
  for (int i = 0; i < GHOSTS; i++) {
    float fi = float(i);
    float f = -0.45 + 0.42 * fi + 0.08 * sin(fi * 2.3);
    vec2 g = -src * f;
    float size = 0.025 + 0.06 * fract(fi * 0.618 + 0.2);
    float gd = length(q - g) / size;
    // a soft disc with a brighter rim
    float disc = smoothstep(1.0, 0.8, gd) * (0.35 + 0.65 * smoothstep(0.4, 0.95, gd));
    vec3 hue = mix(tint, vec3(1.0, 0.65, 0.35), fract(fi * 0.53));
    hue = mix(hue, vec3(0.5, 1.0, 0.6), step(4.5, fi) * 0.6);
    ghosts += disc * hue * 0.45;
  }

  // the highlights of the image bloom at the peak
  vec3 bloom = vec3(0.0);
  if (peak > 1e-3) {
    float radius = 0.06 * env;
    for (int i = 0; i < BLOOM_TAPS; i++) {
      float fi = float(i);
      float a = fi * 2.39996;
      float rr = radius * sqrt((fi + 0.5) / float(BLOOM_TAPS));
      vec2 o = vec2(cos(a), sin(a)) * rr / aspect;
      bloom += highlight(frame(mirror(uv + o), m));
    }
    bloom /= float(BLOOM_TAPS);
  }

  // at the peak, the glare: a wide halo around the light and a light veil over the frame, to hide the cut
  vec3 glare = mix(vec3(1.0), tint, 0.5) * peak * (0.45 + 2.2 * exp(-dist * 3.0));

  vec3 light = k * (streak + core + ghosts) + intensity * (bloom * 2.5 * peak + glare);
  light = 1.0 - exp(-light);

  // screened over the image; the flare only shows on the image, so transparency is kept
  vec3 c = base.rgb + light * base.a - base.rgb * light;
  if (base.a <= 0.0) return vec4(0.0);
  return vec4(clamp(c / base.a, 0.0, 1.0), base.a);
}
