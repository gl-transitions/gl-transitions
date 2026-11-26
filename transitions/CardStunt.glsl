// Author: gre
// License: MIT
// Description: The outgoing image turns into a stadium card-stunt, a mosaic of held-up colored cards over dark stands; a slightly sloppy crowd wave runs across and every card flips over to its color in the incoming image, then the cards melt back into the full incoming image
// Tags: card-stunt, stadium, crowd, mosaic, flip, wave

// @range(16.0, 80.0) Number of cards across the frame
uniform float columns; // = 40.0
// @range(0.0, 1.0) How unevenly the crowd keeps time with the wave
uniform float sloppiness; // = 0.5

const float PI = 3.141592653589793;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec4 transition(vec2 uv) {
  vec2 grid = vec2(columns, floor(columns / ratio + 0.5));
  vec2 cell = floor(uv * grid);
  vec2 f = fract(uv * grid) - 0.5;
  vec2 center = (cell + 0.5) / grid;
  float h = hash12(cell + 7.0);
  float h2 = hash12(cell + vec2(41.0, 17.0));

  float mosaic = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
  // the wave runs along x with a slight diagonal, as a crowd does around the stands
  float along = (cell.x + 0.35 * cell.y) / (grid.x + 0.35 * grid.y);
  float tFlip = clamp((progress - 0.16 - along * 0.55 - (h - 0.5) * 0.12 * sloppiness) / 0.11, 0.0, 1.0);
  float angle = PI * tFlip * tFlip * (3.0 - 2.0 * tFlip);
  float wv = (progress - 0.21 - along * 0.55) / 0.07;
  float crest = exp(-wv * wv);

  float tilt = (h2 - 0.5) * 0.25 * sloppiness * mosaic;
  float lift = crest * 0.16 * mosaic;
  vec2 g = f - vec2(0.0, lift);
  g = mat2(cos(tilt), sin(tilt), -sin(tilt), cos(tilt)) * g;
  float c = cos(angle);
  float edge = mix(0.5, 0.41, mosaic);
  float sy = max(abs(c), 0.001);
  vec2 local = vec2(g.x, g.y / sy);
  float px = grid.x * 0.6 / 300.0 + 0.004;
  float card = (1.0 - smoothstep(edge - px, edge + px, abs(local.x))) * (1.0 - smoothstep(edge - px / sy, edge + px / sy, abs(local.y)));

  bool back = c < 0.0;
  vec4 faceFrom = mix(getFromColor(uv), getFromColor(center), mosaic);
  vec4 faceTo = mix(getToColor(uv), getToColor(center), mosaic);
  vec4 face = back ? faceTo : faceFrom;
  float shade = mix(1.0, 0.55 + 0.45 * abs(c) + 0.12 * (h - 0.5), mosaic);
  face.rgb *= shade * (1.0 + crest * 0.25 * mosaic);

  vec4 stands = mix(getFromColor(uv), getToColor(uv), step(0.5, tFlip));
  stands.rgb *= 1.0 - 0.8 * mosaic;
  return mix(stands, face, card);
}
