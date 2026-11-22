// Author: gre
// License: MIT
// Description: The camera dives down through a deck of clouds: sunlit billows with shadowed undersides drift in over the outgoing picture and rush past the lens layer after layer, a brief white-out inside the cloud, then the billows thin and part as the incoming picture opens out below them
// Tags: clouds, sky, flight, depth, light, dissolve

// @range(0, 1) How much of the sky the clouds cover
uniform float density; // = 0.85
// @color Shadowed side of the clouds
uniform vec4 shade; // = vec4(0.56, 0.62, 0.74, 1.0)

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yxz + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

float fbm(vec2 p) {
  float s = 0.0, a = 0.5;
  // rotate between octaves instead of offsetting, so coordinates stay small for low-precision targets
  mat2 r = mat2(1.6, 1.2, -1.2, 1.6);
  for (int i = 0; i < 5; i++) {
    s += a * noise(p);
    p = r * p;
    a *= 0.48;
  }
  return s;
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 c = (uv - 0.5) * vec2(ratio, 1.0);
  float m = smoothstep(0.46, 0.54, p);
  vec2 sa = c / (1.0 + 0.5 * p * p) / vec2(ratio, 1.0) + 0.5;
  vec2 sb = c / (1.0 + 0.3 * (1.0 - p) * (1.0 - p)) / vec2(ratio, 1.0) + 0.5;
  vec4 a = getFromColor(sa);
  vec4 b = getToColor(sb);
  vec4 col = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);
  col.rgb = col.a > 0.0 ? col.rgb / col.a : vec3(0.0);

  vec2 sun = normalize(vec2(-0.5, 0.8));
  float up = smoothstep(-0.5, 0.5, c.y);
  float sky = 0.88 + 0.12 * up;
  // far layers first; each one approaches, swells past the lens and is gone
  for (int k = 0; k < 6; k++) {
    float fi = float(5 - k);
    float t = 1.6 * p - 0.12 * fi;
    float z = 2.2 - 2.0 * clamp(t, 0.0, 1.0);
    float life = smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.75, 1.0, t));
    vec2 q = c / z * 1.8 + vec2(fi * 1.7, fi * 0.9);
    float cov = 1.0 - density * (0.34 + 0.34 * life);
    float d = fbm(q);
    float body = smoothstep(cov, cov + 0.1, d);
    // density met on the way to the sun: Beer's law self-shadowing
    float ds = fbm(q + sun * 0.12);
    float lit = exp(-6.0 * max(ds - cov, 0.0));
    // thin edges glow when the sun shines through them
    float rim = (1.0 - smoothstep(0.0, 0.1, d - cov)) * 0.35;
    vec3 cl = mix(shade.rgb, vec3(1.0, 0.98, 0.94), clamp(lit + rim, 0.0, 1.0));
    col.rgb = mix(col.rgb, cl * sky, body * life);
  }
  float white = smoothstep(0.38, 0.5, p) * (1.0 - smoothstep(0.5, 0.62, p));
  col.rgb = mix(col.rgb, vec3(0.96, 0.97, 1.0) * (0.92 + 0.08 * up), white);
  return col;
}
