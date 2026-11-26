// Author: gre
// License: MIT
// Description: Three translucent colored circles pop onto the outgoing picture one after another and slide together into a Venn diagram; where all three overlap the incoming picture shows, and that middle lens swells until it fills the frame
// Tags: circle, shape, color, graphic, reveal
// Preview: 0.6

// @range(0, 1) Strength of the tint of each circle on the outgoing picture
uniform float tint; // = 0.65
// @color Color of the first circle (its alpha scales its tint)
uniform vec4 color1; // = vec4(1.0, 0.25, 0.6, 1.0)
// @color Color of the second circle (its alpha scales its tint)
uniform vec4 color2; // = vec4(0.2, 0.95, 0.5, 1.0)
// @color Color of the third circle (its alpha scales its tint)
uniform vec4 color3; // = vec4(0.3, 0.45, 1.0, 1.0)

const float AA = 0.003;

float ease(float t) {
  t = clamp(t, 0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

float back(float t) {
  t = clamp(t, 0.0, 1.0) - 1.0;
  return 1.0 + t * t * (2.6 * t + 1.6);
}

vec4 transition(vec2 uv) {
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  float sc = min(ratio, 1.0);
  float t = progress;
  float cover = 0.5 * length(vec2(ratio, 1.0)) + 2.0 * AA;
  float w = clamp((t - 0.4) / 0.6, 0.0, 1.0);
  float spread = mix(0.3, 0.17, ease((t - 0.12) / 0.45)) * sc * (1.0 - w);
  vec4 a = getFromColor(uv);
  float inter = -1e3;
  for (int i = 0; i < 3; i++) {
    float f = float(i);
    float r = mix(0.26 * sc * back((t - 0.06 * f) / 0.22) - 2.0 * AA, cover, pow(w, 2.5));
    float an = 1.5708 + 2.0944 * f + t;
    float d = length(p - spread * vec2(cos(an), sin(an))) - r;
    vec4 col = i == 0 ? color1 : i == 1 ? color2 : color3;
    a.rgb = mix(a.rgb, col.rgb * (0.25 + 0.75 * dot(a.rgb, vec3(0.3, 0.55, 0.15))),tint * col.a * (1.0 - smoothstep(-AA, AA, d)));
    inter = max(inter, d);
  }
  return mix(a, getToColor(uv), 1.0 - smoothstep(-AA, AA, inter));
}
