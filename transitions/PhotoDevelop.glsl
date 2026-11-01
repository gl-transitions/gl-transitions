// Author: gre
// License: MIT
// Description: The outgoing image washes out to a blank cream card, then the incoming image develops on it like an instant photo: shadows first, faint and tinted, then its contrast and colors come up and it settles
// Tags: fade, color, photo, retro

// @color Color of the blank card between the two images
uniform vec4 card; // = vec4(0.93, 0.91, 0.85, 1.0)
// @range(0, 1) How long the outgoing image takes to wash out (from 10% to 70% of the transition)
uniform float wash; // = 0.35
// @range(0, 1) Strength of the cyan and magenta cast while the image develops
uniform float tint; // = 0.8

vec3 saturation(vec3 c, float s) {
  float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
  return mix(vec3(lum), c, s);
}

vec4 transition(vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float p = progress;
  if (p <= 0.0) return a;
  if (p >= 1.0) return b;

  // the card only shows where the images are: it takes the alpha of the outgoing image, then the incoming one's
  float split = mix(0.1, 0.7, clamp(wash, 0.0, 1.0));
  float cardAlpha = card.a * mix(a.a, b.a, smoothstep(0.6 * split, split + 0.1, p));
  vec3 cardColor = card.rgb * cardAlpha;

  // the outgoing image fades and loses its contrast into the card, its lights first
  float w = smoothstep(0.0, split, p);
  float fromLum = dot(a.rgb, vec3(0.2126, 0.7152, 0.0722));
  float wl = clamp(w * (1.0 + 0.5 * fromLum), 0.0, 1.0);
  vec3 washed = mix(a.rgb, mix(vec3(fromLum), a.rgb, 0.4), w) * a.a;
  vec3 outgoing = mix(washed, cardColor, wl);
  float outAlpha = mix(a.a, cardAlpha, wl);

  // development of the incoming image: quick at first, then slowly settling
  float x = clamp((p - split) / max(1.0 - split, 1e-3), 0.0, 1.0);
  float d = 1.0 - pow(1.0 - x, 1.5);
  float lum = dot(b.rgb, vec3(0.2126, 0.7152, 0.0722));
  // the shadows develop first, the highlights last
  float dev = clamp((d - 0.45 * lum) / 0.55, 0.0, 1.0);
  dev = dev * dev * (3.0 - 2.0 * dev);
  // low contrast and nearly no colors at first, with a cast: cyan in the shadows, magenta in the lights
  float early = 1.0 - smoothstep(0.2, 0.95, d);
  vec3 tinted = saturation(b.rgb, smoothstep(0.3, 1.0, d));
  tinted = mix(vec3(0.6), tinted, mix(0.55, 1.0, d));
  vec3 tone = mix(vec3(-0.2, 0.06, 0.1), vec3(0.12, -0.1, 0.06), smoothstep(0.15, 0.6, lum));
  tinted += tone * tint * early;
  vec3 incoming = mix(cardColor, clamp(tinted, 0.0, 1.0) * b.a, dev);
  float inAlpha = mix(cardAlpha, b.a, dev);

  vec3 color = p < split ? outgoing : incoming;
  float alpha = p < split ? outAlpha : inAlpha;
  if (alpha <= 0.0) return vec4(0.0);
  return vec4(clamp(color / alpha, 0.0, 1.0), alpha);
}
