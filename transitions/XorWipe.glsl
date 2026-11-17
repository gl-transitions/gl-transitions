// Author: gre
// License: MIT
// Description: Discs grow one after another from five points across the frame and every disc edge flips what it passes over, so crescents and lenses of the two images alternate until the last disc sweeps the frame onto the incoming image
// Tags: circle, xor, overlap, graphic, wipe

// @range(0, 0.2) Width of the shade inside each disc edge
uniform float rim; // = 0.06

const float SHARP = 300.0;

float ease(float x) { x = clamp(x, 0.0, 1.0); return x * x * (3.0 - 2.0 * x); }

vec2 seed(int i) {
  return i == 0 ? vec2(0.3, 0.38) : i == 1 ? vec2(0.74, 0.62) : i == 2 ? vec2(0.52, 0.18) : i == 3 ? vec2(0.18, 0.8) : vec2(0.86, 0.22);
}

vec4 transition(vec2 uv) {
  vec2 a = vec2(ratio, 1.0);
  vec2 P = uv * a;
  float par = 1.0, shade = 0.0, line = 0.0;
  // the disc count must stay odd so the parity ends on the incoming image
  for (int i = 0; i < 5; i++) {
    vec2 S = seed(i) * a;
    // the margin pushes the edge and its shade past the farthest corner
    float r = (length(max(S, a - S)) + 0.01 + rim) * ease((progress - float(i) * 0.12) / 0.52);
    float d = r - length(P - S);
    // fades a disc in from radius 0 so it adds nothing at progress 0
    float born = min(r * SHARP, 1.0);
    float c = clamp(d * SHARP + 0.5, 0.0, 1.0) * born;
    par *= 1.0 - 2.0 * c;
    float k = 1.0 - smoothstep(0.0, min(rim, 0.5 * r) + 1e-4, d);
    shade += c * k * k;
    line += max(1.0 - abs(d) * SHARP * 0.5, 0.0) * born;
  }
  vec4 col = mix(getFromColor(uv), getToColor(uv), 0.5 - 0.5 * par);
  float env = 4.0 * progress * (1.0 - progress);
  col.rgb *= 1.0 - 0.35 * min(shade, 1.0) * env;
  col.rgb = mix(col.rgb, vec3(1.0), 0.35 * min(line, 1.0) * env);
  return col;
}
