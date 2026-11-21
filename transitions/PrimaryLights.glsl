// Author: gre
// License: MIT
// Description: The lights dim on the outgoing image and three round beams of red, green and blue light glide in from three sides, each showing the incoming image in its own color; where they overlap the colors add up, and where all three meet the incoming image appears in full color, until the merged beam fills the frame
// Tags: light, color, rgb, additive, circles, spotlight

// @range(0, 1) How dark the outgoing image gets outside the beams
uniform float darkness; // = 0.6
// @range(0, 0.2) Softness of the beam edges
uniform float softness; // = 0.06
// @range(0, 1) Strength of the glow the beams spill around them
uniform float glow; // = 0.5

const float PI = 3.1415927;

// x: beam coverage, y: its brightness profile, z: its halo
vec3 beam(vec2 p, float k, float t, float size, float s, float g, float far) {
  // each beam starts a little later than the previous one and swings in on a curve, slowing as it lands
  float u = clamp((t - 0.06 * k) / 0.62, 0.0, 1.0);
  float v = 1.0 - u;
  float travel = 1.0 - v * v * v - 0.9 * sin(PI * u) * u * v;
  float a = PI * (0.5 + 2.0 * k / 3.0) + 0.6 * travel;
  vec2 c = vec2(0.5 * ratio, 0.5) + vec2(cos(a), sin(a)) * (far + 0.4 * size) * (1.0 - travel);
  float r = mix(0.38 * size * smoothstep(0.0, 0.25, u), far + 2.0 * s, g);
  float l = length(p - c);
  float d = l - r;
  float m = 1.0 - smoothstep(-s, s, d + s * (1.0 - 2.0 * smoothstep(0.9, 1.0, t)));
  float hot = 1.0 + 0.35 * (1.0 - smoothstep(0.0, 1.0, l / max(r, 1e-3)));
  float halo = exp(-max(d, 0.0) * 6.0 / size) * (1.0 - m) * smoothstep(0.0, 0.1, r);
  return vec3(m, m * hot, halo);
}

vec4 transition(vec2 uv) {
  vec2 p = vec2(uv.x * ratio, uv.y);
  // narrow frames get smaller beams
  float size = min(1.0, 1.25 * ratio);
  float s = max(softness * size, 0.002);
  float g = smoothstep(0.6, 0.97, progress);
  float far = 0.5 * length(vec2(ratio, 1.0));
  vec3 R = beam(p, 0.0, progress, size, s, g, far);
  vec3 G = beam(p, 1.0, progress, size, s, g, far);
  vec3 B = beam(p, 2.0, progress, size, s, g, far);
  vec3 m = vec3(R.x, G.x, B.x);
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  float lit = max(m.r, max(m.g, m.b));
  float env = sin(PI * progress);
  float dim = smoothstep(0.0, 0.25, progress) * (1.0 - smoothstep(0.75, 1.0, progress));
  float settle = smoothstep(0.85, 1.0, progress);
  // a beam washes out what it lands on, so the outgoing image fades under it
  vec3 base = a.rgb * (1.0 - darkness * dim) * (1.0 - 0.85 * lit);
  // the hot spot and the spill fade out as the merged beam settles on the exact incoming image
  vec3 light = mix(vec3(R.y, G.y, B.y), m, settle);
  // the haze in the beams and around them glows even where the image is black
  vec3 haze = env * (0.08 * light * b.a + 0.5 * glow * vec3(R.z, G.z, B.z) * a.a);
  float cover = mix((m.r + m.g + m.b) / 3.0, 1.0, settle);
  float alpha = mix(a.a, b.a, cover);
  // premultiplied while the lights add up, so hidden colors of transparent pixels never show
  vec3 pre = mix(base * a.a + light * b.rgb * b.a + haze, b.rgb * b.a, settle);
  vec3 c = alpha > 0.0 ? pre / alpha : mix(a.rgb, b.rgb, cover);
  return vec4(min(c, 1.0), alpha);
}
