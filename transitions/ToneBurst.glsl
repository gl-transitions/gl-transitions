// Author: gre
// License: MIT
// Description: The brightest parts of the outgoing image burst into flat vivid color, and a run of five colors pours down through its tones from light to dark; the contours bend into the shapes of the incoming image, whose lights open first and whose shadows close the run
// Tags: color, flat, poster, pop, luminance, contour, abstract

// @color First color, over the lights of the outgoing image
uniform vec4 color1; // = vec4(1.0, 0.86, 0.3, 1.0)
// @color Second color
uniform vec4 color2; // = vec4(1.0, 0.42, 0.3, 1.0)
// @color Third color
uniform vec4 color3; // = vec4(0.86, 0.16, 0.5, 1.0)
// @color Fourth color
uniform vec4 color4; // = vec4(0.36, 0.16, 0.62, 1.0)
// @color Last color, giving way to the incoming image
uniform vec4 color5; // = vec4(0.1, 0.5, 0.75, 1.0)
// @range(0, 1) How far the colors spread from the brightest place rather than follow the shapes
uniform float spread; // = 0.3
// @range(0, 0.06) Smoothness of the contours, in frame heights
uniform float softness; // = 0.03

const int SPOTS = 7;
const int TAPS = 16;

float luma(vec4 c) {
  return dot(c.rgb, vec3(0.299, 0.587, 0.114));
}

vec2 fold(vec2 p) {
  return 1.0 - abs(1.0 - mod(p, 2.0));
}

vec2 spot(int i) {
  return fract(vec2(0.754878, 0.569840) * float(i) + 0.4);
}

vec4 pixel(vec2 p, bool incoming) {
  return incoming ? getToColor(p) : getFromColor(p);
}

// x: when the colors reach this place, from 0 on the lights to 1 in the shadows; y: how torn the contour is there
vec2 delay(vec2 uv, vec4 here, bool incoming, float sharp) {
  vec2 k = vec2(ratio, 1.0);
  vec2 tone[SPOTS];
  vec3 stats = vec3(0.0, 0.0, 1e-4);
  for (int i = 0; i < SPOTS; i++) {
    vec4 c = pixel(spot(i), incoming);
    tone[i] = vec2(luma(c), c.a);
    stats += vec3(tone[i].x, tone[i].x * tone[i].x, 1.0) * c.a;
  }
  float mean = stats.x / stats.z;
  float dev = sqrt(max(stats.y / stats.z - mean * mean, 0.0)) + 0.02;

  vec3 light = vec3(0.5, 0.5, 1.0) * 1e-4;
  vec2 broad = vec2(mean, 1.0) * 1e-3;
  for (int i = 0; i < SPOTS; i++) {
    vec2 d = (uv - spot(i)) * k;
    broad += vec2(tone[i].x, 1.0) * tone[i].y * exp(-22.0 * dot(d, d));
    light += vec3(spot(i), 1.0) * tone[i].y * exp(2.5 * (tone[i].x - mean) / dev);
  }
  float y = mean + 1.4 * (broad.x / broad.y - mean);

  float grain = 0.0;
  if (sharp > 0.0) {
    float l = luma(here);
    vec3 acc = vec3(l, l * l, 1.0) * here.a + vec3(0.0, 0.0, 1e-4);
    for (int i = 0; i < TAPS; i++) {
      float q = (float(i) + 0.5) / float(TAPS);
      float a = 2.399963 * float(i);
      vec4 c = pixel(fold(uv + softness * sqrt(q) * vec2(cos(a), sin(a)) / k), incoming);
      l = luma(c);
      acc += vec3(l, l * l, 1.0) * c.a * (1.0 - 0.7 * q);
    }
    l = acc.x / acc.z;
    grain = sharp * sqrt(max(acc.y / acc.z - l * l, 0.0)) / dev;
    // the tone is drawn to those of the spots, which irons out the grain of plain areas
    vec2 near = vec2(l, 1.0) * 0.02;
    for (int i = 0; i < SPOTS; i++) {
      float d = (tone[i].x - l) / dev;
      near += vec2(tone[i].x, 1.0) * tone[i].y * exp(-9.0 * d * d);
    }
    y = mix(y, near.x / near.y, sharp);
  }

  vec2 c = light.xy / light.z;
  float far = length((uv - c) * k) / length((0.5 + abs(c - 0.5)) * k);
  // a plain image has no shapes to follow
  float w = mix(0.9, spread, smoothstep(0.03, 0.12, dev));
  float dark = 1.0 - smoothstep(-1.8, 1.8, (y - mean) / dev);
  return vec2(mix(dark, far, w), min(0.06 * (1.0 - w) * grain, 0.04));
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  // the shapes of one image melt before those of the other form, so a pixel reads the details of one only
  vec2 da = delay(uv, a, false, 1.0 - smoothstep(0.38, 0.5, progress));
  vec2 db = delay(uv, b, true, smoothstep(0.5, 0.62, progress));
  float t = mix(-0.02, 2.5, progress);
  float lead = t - da.x;
  float tail = 1.4 + db.x - t;
  float s = 5.0 * clamp(lead / (lead + tail), 0.0, 1.0);
  // contours that run through fine texture are drawn softer, as it would tear them
  float aa = 0.015 + 2.0 * (da.y + db.y);
  vec4 col = mix(color1, color2, smoothstep(1.0 - aa, 1.0 + aa, s));
  col = mix(col, color3, smoothstep(2.0 - aa, 2.0 + aa, s));
  col = mix(col, color4, smoothstep(3.0 - aa, 3.0 + aa, s));
  col = mix(col, color5, smoothstep(4.0 - aa, 4.0 + aa, s));
  col.a *= mix(a.a, b.a, 0.2 * s);
  col = mix(a, col, smoothstep(0.0, 0.012 + 2.0 * da.y, lead));
  return mix(col, b, smoothstep(0.0, 0.012 + 2.0 * db.y, -tail));
}
