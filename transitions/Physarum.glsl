// Author: gre
// License: MIT
// Description: A slime mold spreads over the outgoing picture as in a time-lapse: a glowing yellow fan with a lobed margin creeps out from one spot, and behind the margin it breaks up into a mesh of yellow tubes that open onto the incoming picture; the tubes swell, lose their yellow and merge as they age until the mesh closes into the whole incoming picture
// Tags: nature, organic, growth, reveal

// @range(0, 1) Horizontal position of the spot where the mold starts
uniform float originX; // = 0.18
// @range(0, 1) Vertical position of the spot where the mold starts
uniform float originY; // = 0.25
// @range(2, 8) Density of the tube mesh
uniform float density; // = 4.0
// @color Glowing plasmodium of the front and the young tubes
uniform vec4 moldColor; // = vec4(1.0, 0.84, 0.22, 1.0)

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = p - i;
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
             mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec2 hash2(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

// x: distance to the cell wall (bisector of the two nearest jittered points), y: to the cell center
vec2 cellWall(vec2 p) {
  vec2 c = floor(p);
  vec2 v1 = vec2(9.0);
  vec2 v2 = vec2(9.0);
  for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
      vec2 id = c + vec2(float(i), float(j));
      vec2 v = id + 0.1 + 0.8 * hash2(id) - p;
      if (dot(v, v) < dot(v1, v1)) {
        v2 = v1;
        v1 = v;
      } else if (dot(v, v) < dot(v2, v2)) {
        v2 = v;
      }
    }
  return vec2(dot(0.5 * (v1 + v2), normalize(v2 - v1)), length(v1));
}

// x > 0 in the pores left between tubes of half-width w, which shrink to the cell centers as hole goes to 0
// y < 0 in the plasmodium core of half-width core along the tube
vec2 tubes(vec2 q, float scale, vec2 o, float w, float core, float hole) {
  vec2 p = q * scale + o;
  p += 0.9 * vec2(noise(p * 0.8 + 3.1), noise(p * 0.8 + 8.4)) - 0.45;
  vec2 c = cellWall(p) / scale;
  return vec2(min(c.x - w, hole / scale - 0.01 - c.y), c.x - min(core, w));
}

vec4 transition(vec2 uv) {
  vec2 q = (uv - vec2(originX, originY)) * vec2(ratio, 1.0);
  float r = length(q);
  vec2 dir = q / max(r, 1e-4);
  vec2 c0 = vec2(ratio, 1.0) * 0.5 - vec2(originX * ratio, originY);
  float rmax = length(abs(c0) + vec2(ratio, 1.0) * 0.5);

  // every pixel is reached by 80% so the tubes have time to merge
  float lobe = noise(dir * 3.0 + 4.0) + 0.5 * noise(dir * 9.0 + 1.0);
  float tf = 0.8 * min(r * (0.85 + 0.35 * lobe) / (1.375 * rmax), 1.0);
  float ahead = progress - tf;
  float age = clamp(ahead / (1.0 - tf), -1.0, 1.0);
  float a = max(age, 0.0);
  a *= sqrt(a);

  float aa = 0.0015;
  float young = 1.0 - smoothstep(0.05, 0.75, a);
  float hole = 1.2 * (1.0 - smoothstep(0.3, 0.9, a));
  float wf = -aa + 0.05 * a * a;
  vec2 tm = tubes(q, density, vec2(0.0), 0.004 + 0.04 * a, 0.0045 * young, hole);
  vec2 tn = tubes(q, density * 2.6, vec2(5.2, 1.3), wf, 0.0025 * young, hole);
  float d = min(tm.x, tn.x);
  float born = smoothstep(0.0, 0.01, ahead);
  // the last pores melt instead of lingering as confetti
  float m = max(1.0 - smoothstep(-aa, aa, d), smoothstep(0.55, 0.95, a)) * born;

  vec4 from = getFromColor(uv);
  vec4 to = getToColor(uv);
  vec3 mold = moldColor.rgb;
  float envelope = min(progress * 12.0, 1.0);

  float core = (1.0 - smoothstep(-aa, aa, min(tm.y, tn.y))) * smoothstep(0.2, 0.5, young);
  vec3 tube = mix(to.rgb, mix(mold, vec3(1.0), 0.15), core * moldColor.a * to.a);

  float halo = exp(-max(d, 0.0) / 0.005) * young * born;
  float sheet = smoothstep(-0.01, 0.0, ahead) * (1.0 - smoothstep(0.0, 0.04, ahead));
  float margin = exp(-abs(ahead) / 0.008);
  float glow = clamp(0.5 * halo + 0.6 * sheet + 0.5 * margin, 0.0, 1.0) * envelope * moldColor.a * from.a;
  vec3 old = 1.0 - (1.0 - from.rgb) * (1.0 - mold * glow);
  old = mix(old, mold, 0.35 * margin * envelope * moldColor.a * from.a);

  return mix(vec4(old, from.a), vec4(tube, to.a), m);
}
