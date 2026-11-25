// Author: gre
// License: MIT
// Description: Seen from under water, the surface mirrors the outgoing picture everywhere except in a trembling round window where the light gets through, and there the whole incoming picture is crammed; waves tear the rim of the window into drifting islands as it widens until the surface is all open and calm
// Tags: light, water, refraction, reflection, optical

// @range(0, 2) Height of the waves
uniform float waves; // = 1.0
// @range(0, 0.1) Rainbow fringe of the window
uniform float dispersion; // = 0.035
// @range(0, 1) Tint of the water
uniform float tint; // = 0.6

vec4 pm(vec4 c) {
  return vec4(c.rgb * c.a, c.a);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec2 slope(vec2 q, float t) {
  vec2 g = vec2(0.0);
  q += 0.06 * vec2(sin(7.0 * q.y + t * 3.0), sin(6.0 * q.x - t * 4.0));
  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    float a = 2.39996 * fi + 1.0;
    float k = 6.0 + 4.2 * fi;
    vec2 n = vec2(cos(a), sin(a));
    g += n * cos(k * dot(n, q) + t * (9.0 + 2.5 * fi) + 1.9 * fi) / (1.0 + 0.35 * fi);
  }
  return g;
}

// refraction index 1 / sc
vec2 through(vec3 d, vec3 n, float sc, float fov) {
  float c = dot(d, n);
  vec3 t = (d - n * c) / max(sc, 0.02);
  float k = sqrt(max(1.0 - dot(t, t), 0.0));
  t += n * k;
  return t.xy / max(t.z, 0.35) / fov;
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * asp;
  float env = pow(max(sin(3.14159265 * p), 0.0), 1.5);
  // the frame covers the same angle whatever its shape
  float fov = 2.1 / length(asp);
  float amp = 0.075 * waves * env * (1.0 - 0.5 * p);
  vec2 g = slope(q, p);
  vec3 d = normalize(vec3(q * fov, 1.0));
  vec3 n = normalize(vec3(-g * amp, 1.0));
  float c = dot(d, n);
  float si = sqrt(max(1.0 - c * c, 0.0));
  // sine of the critical angle, 1 when the water bends light no more
  float lim = p * (1.45 - 0.45 * p);
  vec3 R = reflect(d, n);
  vec2 qa = R.xy / max(-R.z, 0.3) / fov;
  vec4 A = pm(getFromColor(mirror(qa / asp + 0.5)));
  // the whole sky stays in the window
  float rc = 2.0 * (1.0 - pow(p, 5.0));
  vec4 B = vec4(0.0);
  vec3 m = vec3(0.0);
  for (int i = 0; i < 3; i++) {
    float f = (float(i) - 1.0) * dispersion * env * (1.0 - 0.6 * p);
    float l = max(lim * (1.0 - f), 1e-3);
    vec2 qb = through(d, n, l, fov);
    vec2 box = qb / asp * rc;
    box *= box;
    qb /= pow(1.0 + dot(box, box), 0.25);
    vec4 b = pm(getToColor(mirror(qb / asp + 0.5)));
    float w = smoothstep(-0.012, 0.012, l - si - 0.0135 * (1.0 - p));
    if (i == 0) { B.r = b.r; m.r = w; }
    if (i == 1) { B.g = b.g; B.a = b.a; m.g = w; }
    if (i == 2) { B.b = b.b; m.b = w; }
  }
  vec3 rgb = mix(A.rgb, B.rgb, m);
  float al = mix(A.a, B.a, m.g);
  float rim = 1.0 - smoothstep(0.0, 0.07, abs(lim - si));
  rgb += 0.3 * env * rim * m.g * al * vec3(0.9, 1.0, 1.0);
  // slopes towards the light shine through the water, the others darken
  float facet = waves * env * (1.0 - m.g);
  rgb *= 1.0 + facet * clamp(0.16 * dot(g, vec2(-0.5, 0.8)), -0.3, 0.45);
  rgb += 0.35 * facet * al * smoothstep(1.4, 2.6, dot(g, vec2(-0.5, 0.8))) * vec3(0.8, 1.0, 1.0);
  rgb = mix(rgb, rgb * vec3(0.42, 0.86, 1.0) + vec3(0.0, 0.03, 0.05) * al, tint * env * (1.0 - m.g));
  return al > 0.0 ? vec4(min(rgb / al, 1.0), al) : vec4(0.0);
}
