// Author: gre
// License: MIT
// Description: The highlights of the outgoing image flare into long horizontal (or vertical) lens streaks while it smears with motion blur; at the peak the incoming image takes over and its streaks shrink back into its highlights as it sharpens
// Tags: light, flare, motion-blur, glow

// @range(0, 2) Length of the streaks at the peak, in frame widths
uniform float reach; // = 0.6
// @range(0, 1) Brightness above which the image flares
uniform float threshold; // = 0.7
// @range(0, 4) Brightness of the streaks
uniform float intensity; // = 1.5
// @color Tint of the streaks, toward their ends
uniform vec3 tint; // = vec3(0.45, 0.7, 1.0)
// @range(0, 0.5) Length of the motion blur at the peak
uniform float blur; // = 0.1
// @param Streak and smear vertically instead
uniform bool vertical; // = false

const int BLUR_TAPS = 6;
// taps on each side of a streak, spaced further and further apart along its falloff
const int STREAK_TAPS = 11;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// the image on screen: the outgoing one, then the incoming one after a short switch
vec4 frame(vec2 st, float m) {
  if (m <= 0.0) return getFromColor(st);
  if (m >= 1.0) return getToColor(st);
  return mix(getFromColor(st), getToColor(st), m);
}

// the light of a pixel: its color above the threshold
vec3 glow(vec4 c, float knee) {
  float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  return c.rgb * c.a * smoothstep(knee, knee + 0.2, lum);
}

// one image only, for the blur and streak taps: during the switch, every other tap reads each image
vec4 light(vec2 st, float m, bool incoming) {
  if (m <= 0.0) return getFromColor(st);
  if (m >= 1.0) return getToColor(st);
  return incoming ? getToColor(st) : getFromColor(st);
}

float lightWeight(float m, bool incoming) {
  if (m <= 0.0 || m >= 1.0) return 1.0;
  return incoming ? 2.0 * m : 2.0 * (1.0 - m);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // eased in on the outgoing side, and quickly out after the switch so the incoming image lands sharp
  float amount = p < 0.5 ? smoothstep(0.0, 0.5, p) : pow(2.0 - 2.0 * p, 3.0);
  float peak = amount * amount * amount;
  float m = smoothstep(0.44, 0.56, p);
  vec2 axis = vertical ? vec2(0.0, 1.0) : vec2(1.0, 0.0);
  // a small shift of the taps, under their spacing, blends their copies into a smooth smear;
  // hashed by integer cell so that every GPU computes the same shift
  float jitter = hash12(floor(uv * vec2(ratio, 1.0) * 997.0)) - 0.5;

  // the image smears along the streaks (a tent filter)
  float smear = blur * amount;
  vec3 base = vec3(0.0);
  float alpha = 0.0;
  float total = 0.0;
  for (int i = 0; i < BLUR_TAPS; i++) {
    float t = (float(i) + 0.5 + jitter) / float(BLUR_TAPS) - 0.5;
    float w = 1.0 - abs(t);
    total += w;
    bool incoming = mod(float(i), 2.0) > 0.5;
    w *= lightWeight(m, incoming);
    vec4 c = light(mirror(uv + axis * t * smear), m, incoming);
    base += w * c.rgb * c.a;
    alpha += w * c.a;
  }
  base /= total;
  alpha /= total;

  // the streaks: the light above the threshold, spread along the axis with an exponential falloff
  float falloff = 0.25 * reach * amount;
  float knee = mix(threshold, 0.8 * threshold, peak);
  vec3 streak = glow(frame(uv, m), knee);
  float weights = 1.0;
  for (int k = 1; k <= STREAK_TAPS; k++) {
    // the distance in units of the falloff, and the stretch of the streak this tap stands for
    float d = exp(0.14 * (float(k) + 0.8 * jitter)) - 1.0;
    float span = 0.14 * (d + 1.0);
    // white at the source, tinted along the streak, red fading first so the tails turn blue and violet
    vec3 hue = mix(vec3(1.0), tint, smoothstep(0.0, 0.8, d));
    hue *= exp(-d * vec3(0.6, 0.2, -0.15));
    float w = exp(-d) * span * 4.0;
    bool incoming = mod(float(k), 2.0) > 0.5;
    vec4 ahead = light(mirror(uv + axis * d * falloff), m, incoming);
    vec4 behind = light(mirror(uv - axis * d * falloff), m, !incoming);
    streak += w * hue * (glow(ahead, knee) * lightWeight(m, incoming) + glow(behind, knee) * lightWeight(m, !incoming));
    weights += 2.0 * w;
  }
  streak *= intensity * amount * (0.6 + 2.4 * peak) * 2.0 / weights;
  // compressed, so that bright skies never flatten into white
  streak = 0.85 * (1.0 - exp(-streak));

  // a lift of the exposure at the peak, then the streaks screened on top (premultiplied colors)
  base = min(base * (1.0 + 0.2 * peak), vec3(alpha));
  vec3 color = base + streak - base * streak;
  float a = alpha + max(streak.r, max(streak.g, streak.b)) * (1.0 - alpha);
  return vec4(clamp(color / max(a, 1e-5), 0.0, 1.0), a);
}
