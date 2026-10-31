// Author: gre
// License: MIT
// Description: The image breaks into printed halftone dots whose size follows its shades, the dots reshape into the incoming image, then merge back into it
// Tags: dots, pattern, retro

// @range(4, 80) Number of dots across the shorter side
uniform float dots; // = 28.0
// @range(0, 90) Angle of the dot grid, in degrees
uniform float angle; // = 45.0
// @color Color of the paper between the dots
uniform vec4 paper; // = vec4(1.0, 1.0, 1.0, 1.0)

// Dot radius, in cells, of a halftone printing this color (darker is bigger)
float dotRadius(vec4 c) {
  float shade = 1.0 - dot(c.rgb, vec3(0.299, 0.587, 0.114));
  return mix(0.1, 0.74, sqrt(clamp(shade, 0.0, 1.0))) * c.a;
}

vec4 transition(vec2 uv) {
  // the image turns into dots until 0.3, the dots reshape from left to right, then merge back from 0.7
  float h = smoothstep(0.0, 0.3, progress) * (1.0 - smoothstep(0.7, 1.0, progress));
  float t = (progress - 0.3) / 0.4;
  // rotated square grid, in cells
  float a = radians(angle);
  mat2 rot = mat2(cos(a), sin(a), -sin(a), cos(a));
  vec2 scale = vec2(ratio, 1.0) * dots / min(ratio, 1.0);
  vec2 g = rot * ((uv - 0.5) * scale);
  vec2 base = floor(g - 0.5) + 0.5;
  vec4 pixel = progress < 0.5 ? getFromColor(uv) : getToColor(uv);
  // the dots of the 4 nearest cells may overlap this point: keep the one it is deepest in
  float best = 1e3;
  vec4 ink = pixel;
  for (int i = 0; i < 4; i++) {
    vec2 center = base + vec2(mod(float(i), 2.0), floor(float(i) / 2.0));
    vec2 cuv = (center * rot) / scale + 0.5; // inverse rotation
    vec4 cf = getFromColor(cuv);
    vec4 ct = getToColor(cuv);
    float m = smoothstep(0.0, 1.0, clamp(2.5 * t - 1.5 * cuv.x, 0.0, 1.0));
    // at h = 0, the dots cover their whole cell with the image itself
    float r = mix(0.78, mix(dotRadius(cf), dotRadius(ct), m), h);
    float sd = length(g - center) - r;
    if (sd < best) {
      best = sd;
      ink = mix(pixel, mix(cf, ct, m), h);
    }
  }
  return mix(paper, ink, 1.0 - smoothstep(-0.06, 0.06, best));
}
