// Author: gre
// License: MIT
// Description: The highlights of the outgoing image blow out into a soft, wide glow that floods the frame; under it the incoming image takes over, then the glow subsides back into its highlights while the image stays sharp
// Tags: light, glow, bloom, dissolve

// @range(0, 0.6) Reach of the glow at the peak, in frame heights
uniform float spread; // = 0.25
// @range(0, 1) Brightness above which the image glows (the whole frame does at the peak)
uniform float threshold; // = 0.6
// @range(0, 4) Brightness of the glow
uniform float intensity; // = 1.5
// @color Tint of the glow, toward its edges
uniform vec3 tint; // = vec3(1.0, 0.9, 0.75)

// pairs of opposite taps: 20 reads per pixel
const int PAIRS = 10;
const float GOLDEN_ANGLE = 2.399963;

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

// mirror the coordinates back into the frame
vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// the image on screen at a point, premultiplied: one image, or both during the short switch
vec4 image(vec2 st, float m) {
  if (m <= 0.0) {
    vec4 c = getFromColor(st);
    return vec4(c.rgb * c.a, c.a);
  }
  if (m >= 1.0) {
    vec4 c = getToColor(st);
    return vec4(c.rgb * c.a, c.a);
  }
  vec4 a = getFromColor(st);
  vec4 b = getToColor(st);
  return mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
}

// the light of a pixel (premultiplied): its color above the knee, full well before white
vec3 glow(vec4 c, float knee) {
  float lum = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
  return c.rgb * smoothstep(knee, knee + max(0.3 * (1.0 - knee), 1e-3), lum);
}

vec4 transition(vec2 uv) {
  float p = progress;
  // the glow blooms on the outgoing image, and subsides on the incoming one
  float amount = 4.0 * p * (1.0 - p);
  float peak = amount * amount;
  // around the middle, the whole frame catches the light and floods with glow
  float flood = peak * peak * peak;
  // the switch, under the glow at its brightest
  float m = smoothstep(0.44, 0.56, p);
  if (amount <= 0.0) return m < 0.5 ? getFromColor(uv) : getToColor(uv);

  // the image stays sharp underneath (premultiplied colors, only the images on screen are read)
  vec4 c = image(uv, m);
  if (c.a <= 0.0) return vec4(0.0);
  c.rgb /= c.a;

  // more and more of the image catches the light as the glow grows
  float knee = threshold * (1.0 - 0.3 * peak) * (1.0 - flood);
  float radius = spread * amount;
  // a rotation and a radial shift of the spiral for each pixel blend the taps into a smooth glow;
  // hashed by integer cell so that every GPU computes the same values
  vec2 cell = floor(uv * vec2(ratio, 1.0) * 997.0);
  float spin = 6.2831853 * hash12(cell);
  float shift = hash12(cell + 71.0);

  // a golden-angle spiral, denser toward the center so the glow is bright at its core with a wide soft tail;
  // each tap is read with its opposite, which cancels most of the noise across smooth gradients
  vec3 bloom = vec3(0.0);
  vec4 soft = vec4(0.0);
  float total = 0.0;
  for (int i = 0; i < PAIRS; i++) {
    float s = (float(i) + shift) / float(PAIRS);
    float r = s * s;
    float a = float(i) * GOLDEN_ANGLE + spin;
    vec2 offset = radius * r * vec2(cos(a) / ratio, sin(a));
    vec4 i0 = image(mirror(uv + offset), m);
    vec4 i1 = image(mirror(uv - offset), m);
    vec3 l = glow(i0, knee) + glow(i1, knee);
    // the sparse outer taps weigh less, so the tail of the glow stays smooth
    float w = 1.0 - 0.75 * s;
    // white at the core, tinted toward the edges
    bloom += w * mix(vec3(1.0), tint, smoothstep(0.0, 0.5, r)) * l;
    total += w;
    // a closer blur of the image, to soften it
    float sw = (1.0 - s) * (1.0 - s);
    soft += sw * (i0 + i1);
  }
  bloom /= 2.0 * total;
  // at the peak the light softens the image itself, which hides the switch
  vec3 blurred = soft.a > 0.0 ? soft.rgb / soft.a : c.rgb;
  vec3 base = mix(c.rgb, blurred, 0.7 * flood);
  bloom *= intensity * peak * (1.0 + 2.0 * flood);
  // compressed, so that the glow floods the frame without flattening into white
  bloom = 0.92 * (1.0 - exp(-bloom));

  // the glow is a light screened over the image: it adds nothing to its alpha
  base = min(base * (1.0 + 0.25 * peak), 1.0);
  return vec4(base + bloom - base * bloom, c.a);
}
