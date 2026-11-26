// Author: gre
// License: MIT
// Description: The outgoing image is photocopied again and again on a beat, each copy flashing out more skewed, shrunk and crushed to grainy black-and-white toner with dust and dark lid borders; at the worst copy it has become the incoming image, whose copies then come back cleaner until it is the original
// Tags: photocopy, copier, toner, print, grain, generation-loss

// @range(2, 6, 1) Number of copies made on the way out (and back)
uniform float copies; // = 4.0
// @range(0, 1) How much each copy loses
uniform float loss; // = 0.8
// @color Color of the toner, which prints the dark tones, the dust and the lid borders
uniform vec4 toner; // = vec4(0.07, 0.07, 0.08, 1.0)
// @color Color of the copier lamp flashing as each copy comes out (its alpha is its strength)
uniform vec4 lamp; // = vec4(0.86, 1.0, 0.9, 0.55)

float h2(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

// gen in 0..1: how many generations of copying the image has gone through; k seeds the copy's misregistration
vec3 copyOf(vec2 uv, float gen, float k, bool incoming) {
  float a = (h2(vec2(k, 3.0)) - 0.5) * 0.09 * gen;
  vec2 off = (vec2(h2(vec2(k, 7.0)), h2(vec2(k, 9.0))) - 0.5) * 0.07 * gen;
  float z = 1.0 - 0.05 * gen;
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  p = mat2(cos(a), sin(a), -sin(a), cos(a)) * p / z;
  vec2 s = p / vec2(ratio, 1.0) + 0.5 + off;
  vec3 c = incoming ? getToColor(mirror(s)).rgb : getFromColor(mirror(s)).rgb;
  vec2 o = max(-s, s - 1.0);
  float outside = smoothstep(-0.004, 0.004, max(o.x, o.y));
  float l = dot(c, vec3(0.299, 0.587, 0.114));
  float w = mix(0.5, 0.07, gen);
  vec2 cell = uv * vec2(ratio, 1.0);
  float grain = h2(floor(cell * 420.0) + k) - 0.5;
  float bw = smoothstep(0.52 - w, 0.52 + w, l + 0.18 * gen * grain);
  vec3 printed = mix(toner.rgb, vec3(0.97, 0.97, 0.95), bw);
  vec3 col = mix(c, printed, smoothstep(0.0, 0.7, gen));
  // the lid and the bare glass around the shrunk original print as toner
  col = mix(col, toner.rgb, outside * smoothstep(0.0, 0.3, gen));
  float dust = step(1.0 - 0.012 * gen, h2(floor(cell * 260.0) + k * 13.0));
  col = mix(col, toner.rgb, dust);
  float streak = smoothstep(0.985, 1.0, h2(vec2(floor(uv.x * 400.0), k))) * gen;
  return mix(col, toner.rgb, 0.6 * streak);
}

vec4 transition(vec2 uv) {
  float n = copies;
  float s = progress * 2.0 * n;
  float k = floor(s);
  float f = fract(s);
  // each copy comes out in a quick step, then holds
  float stepped = (k + smoothstep(0.0, 0.25, f)) / n;
  float gen = min((progress < 0.5 ? stepped : 2.0 - stepped) * loss, 1.0);
  bool inc = progress >= 0.5;
  vec3 col = copyOf(uv, gen, inc ? 2.0 * n - k : k + 1.0, inc);
  float flash = (1.0 - smoothstep(0.0, 0.25, f)) * smoothstep(0.0, 0.03, f) * sin(3.14159 * progress);
  col = mix(col, lamp.rgb, lamp.a * flash);
  return vec4(col, inc ? getToColor(uv).a : getFromColor(uv).a);
}
