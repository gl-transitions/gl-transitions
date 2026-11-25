// Author: gre
// License: MIT
// Description: The outgoing picture is the reflection in a puddle when a shower starts: drops land all over it, each sending out little rings that bend the reflection and catch the light, the rings crowd as the rain gets heavy and open onto the incoming picture, then the shower stops and the water settles calm
// Tags: rain, water, ripples, reflection, weather
// Preview: 0.5

// @range(0.5, 2) Size of the rings
uniform float dropSize; // = 1.0
// @range(0, 1) How much the rings bend the reflection
uniform float refraction; // = 0.6
// @range(0, 1) Light caught by the rings and the splashes
uniform float shine; // = 0.6

vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * asp;
  float size = max(dropSize, 0.1);
  float S = 0.17 * size;

  vec2 slope = vec2(0.0);
  float h = 0.0, opened = 0.0, splash = 0.0;
  for (int l = 0; l < 3; l++) {
    float fl = float(l);
    vec2 g = q / S + vec2(5.7, 1.3) * fl;
    vec2 gi = floor(g);
    for (int j = 0; j < 9; j++) {
      vec2 cell = gi + vec2(mod(float(j), 3.0) - 1.0, floor((float(j) + 0.5) / 3.0) - 1.0);
      vec2 h1 = hash22(cell + 17.0 * fl);
      vec2 h2 = hash22(cell + 53.0 + 29.0 * fl);
      // landings cluster in the middle: the shower builds up then stops
      float t0 = 0.01 + 0.82 * (mix(h2.x, 0.25 + 0.5 * h2.y, 0.45) - 0.11);
      float age = p - t0;
      if (age <= 0.0) continue;
      vec2 d = (g - cell - 0.2 - 0.6 * h1) * S;
      float dl = length(d);
      float R = S * 1.15 * (1.0 - exp(-age * 2.6));
      float w = 0.009 * size + 0.02 * age * size;
      float x = (dl - R) / w;
      float a = exp(-x * x * 0.45) * exp(-age * 7.0) * (0.55 + 0.45 * h2.y) * smoothstep(0.0, 0.025, age) * (1.0 - smoothstep(0.3, 0.4, age));
      float wave = cos(x * 2.2);
      slope += a * (-2.2 * sin(x * 2.2) - 0.9 * x * wave) / w * d / max(dl, 1e-4);
      h += a * wave;
      // the edge of an opening blurs as the ring that carried it dies out
      float soft = min(0.6 * w + 0.5 * age * S, 0.2 * S);
      float late = step(0.28, t0);
      opened = max(opened, late * (1.0 - smoothstep(-soft, soft, dl - min(R, 0.8 * S) + w)) * smoothstep(0.0, 0.04, age));
      float flash = smoothstep(0.0, 0.008, age) * (1.0 - smoothstep(0.01, 0.045, age));
      float crown = 0.004 * size + 0.2 * size * age;
      splash = max(splash, flash * (1.0 - smoothstep(0.0, 0.0035 * size, abs(dl - crown) - 0.001)));
    }
  }
  float calm = 1.0 - smoothstep(0.76, 1.0, p);
  float heavy = smoothstep(0.15, 0.45, p) * (1.0 - smoothstep(0.5, 0.8, p));
  slope *= calm * size;
  h *= calm;

  vec2 tuv = uv + slope * (0.00028 + 0.00022 * heavy) * refraction / asp;
  tuv = 1.0 - abs(1.0 - mod(tuv, 2.0));
  float m = max(opened, smoothstep(0.46, 0.68, p + 0.03 * h + 0.07 * sin(5.0 * q.x + 2.0) * sin(6.0 * q.y + 1.0)));
  vec4 a = getFromColor(tuv), b = getToColor(tuv);
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);

  vec3 n = normalize(vec3(-slope * 0.012, 1.0));
  vec3 H = normalize(vec3(-0.35, 0.5, 1.9));
  float glint = pow(max(dot(n, H), 0.0), 60.0);
  // grazing slopes reflect the dark sky away from the light
  float tilt = dot(n.xy, normalize(H.xy));
  c.rgb *= 1.0 + shine * 0.3 * tilt;
  float rest = pow(H.z, 60.0);
  float light = shine * (0.8 * clamp(glint - rest, 0.0, 1.0) * smoothstep(0.02, 0.2, length(n.xy)) + 0.7 * splash * calm);
  c.rgb += light * (c.a - 0.5 * c.rgb);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
