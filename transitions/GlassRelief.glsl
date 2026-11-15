// Author: gre
// License: MIT
// Description: The shapes of the incoming image rise through the outgoing one as clear molded glass, bending it and catching the light along their outlines; then the glass fills with the incoming image's colors, brightest parts first, and melts flat into it
// Tags: glass, relief, refraction, content, dissolve

// @range(0, 2) How strongly the glass bends the picture behind it
uniform float refraction; // = 1.0
// @range(0, 2) Brightness of the light caught by the glass
uniform float shine; // = 1.0
// @param Direction the light comes from when the relief is at its peak; it swings around it during the transition
uniform vec2 light; // = vec2(-0.6, 0.8)

const int TAPS = 24;
// in frame heights: wide enough that fine texture averages out of the height field
const float RADIUS = 0.05;

float luma(vec4 c) {
  return dot(c.rgb, vec3(0.299, 0.587, 0.114)) * c.a + 0.3 * (1.0 - c.a);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  float rise = smoothstep(0.0, 0.4, progress);
  float melt = smoothstep(0.35, 1.0, progress);
  float relief = rise * (1.0 - melt);

  // Gaussian-weighted plane fit of the incoming brightness over a golden-angle spiral
  mat2 turn = mat2(-0.73736, 0.67549, -0.67549, -0.73736);
  vec2 dir = vec2(1.0, 0.0);
  float sw = 0.0, sl = 0.0, sdd = 0.0;
  vec2 sd = vec2(0.0), sld = vec2(0.0);
  for (int i = 0; i < TAPS; i++) {
    float f = (float(i) + 0.5) / float(TAPS);
    vec2 d = RADIUS * sqrt(f) * dir;
    float w = exp(-4.0 * f);
    float l = luma(getToColor(mirror(uv + vec2(d.x / ratio, d.y))));
    sw += w;
    sl += w * l;
    sd += w * d;
    sld += w * l * d;
    sdd += w * dot(d, d);
    dir = turn * dir;
  }
  float h = sl / sw;
  vec2 g = 0.08 * (sld - h * sd) / (sdd - dot(sd, sd) / sw);
  // steep slopes are rounded off so the glass stays smooth on strong edges
  g /= 1.0 + 1.5 * length(g);

  vec2 off = -g * 0.2 * refraction * relief / vec2(ratio, 1.0);
  vec4 behind = getFromColor(mirror(uv + off));
  float fringe = 0.08 * refraction * relief;
  vec4 cr = getFromColor(mirror(uv + off * (1.0 + fringe)));
  vec4 cb = getFromColor(mirror(uv + off * (1.0 - fringe)));
  behind.r = mix(behind.r, cr.r, cr.a);
  behind.b = mix(behind.b, cb.b, cb.a);

  vec3 n = normalize(vec3(-g * 4.0 * relief, 1.0));
  // the light swings over the transition, so the glints slide along the outlines
  float a = 2.0 * (progress - 0.4);
  vec2 ld = mat2(cos(a), sin(a), -sin(a), cos(a)) * light;
  vec3 lt = normalize(vec3(ld, 0.9));
  float diff = dot(n, lt) - lt.z;
  float spec = pow(max(dot(reflect(-lt, n), vec3(0.0, 0.0, 1.0)), 0.0), 40.0);
  float rim = 1.0 - n.z;
  vec3 glass = behind.rgb * (1.0 + 0.6 * shine * diff) + shine * (0.9 * spec * relief * min(length(g) * 6.0, 1.0) + 0.4 * max(diff, 0.0) + 0.4 * rim);

  vec4 to = getToColor(uv);
  float lag = 0.7 * (1.0 - clamp(mix(h, luma(to), 0.3), 0.0, 1.0));
  float fill = smoothstep(lag, lag + 0.3, melt);
  return vec4(clamp(mix(glass, to.rgb, fill), 0.0, 1.0), mix(behind.a, to.a, fill));
}
