// Author: gre
// License: MIT
// Description: The outgoing picture becomes a board of square tiles; groups of three tiles in a row flash and pop, the tiles above drop into the gaps with a little bounce and tiles of the incoming picture fall in from the top, round after round, until the board is all incoming picture
// Tags: tiles, game, puzzle, grid, drop, playful

// @range(0, 1) Brightness of the flash when a match pops
uniform float flash; // = 0.8
// @color Board showing between the tiles
uniform vec4 boardColor; // = vec4(0.07, 0.07, 0.09, 1.0)

const float R = 6.0;
const float ROUND = 0.145;

float hash(vec2 p) {
  vec3 q = fract(p.xyx * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

// Every round, each column loses one tile, so all stacks keep the same height and a group's tiles stay in one row.
float group(float c, float r) {
  return floor((c + mod(r * 2.0, 3.0)) / 3.0);
}

// neighboring groups take rows of opposite parity, so they never merge into a longer run
float matchRow(float c, float r) {
  float g = group(c, r);
  float par = mod(g, 2.0);
  float n = floor((R - r - par + 1.0) / 2.0);
  return n > 0.0 ? par + 2.0 * floor(hash(vec2(g, r + 7.0)) * n) : 0.0;
}

vec4 transition(vec2 uv) {
  float C = floor(R * ratio + 0.5);
  float c = min(floor(uv.x * C), C - 1.0);
  float yp = uv.y * R;
  float env = smoothstep(0.0, 0.05, progress) * (1.0 - smoothstep(0.93, 1.0, progress));

  float rt = (progress - 0.06) / ROUND;
  float r = clamp(floor(rt), 0.0, R);
  float u = rt - r;
  float yr = matchRow(c, r);
  float jit = hash(vec2(group(c, r), r + 19.0)) * 0.3;
  float pop = r < R ? clamp((u - jit) / 0.25, 0.0, 1.0) : 0.0;
  float x = r < R ? clamp((u - jit - 0.24) / 0.36, 0.0, 1.0) : 0.0;
  float g = x * x;
  g -= 0.06 * sin(3.14159265 * clamp((u - jit - 0.6) / 0.1, 0.0, 1.0)) * step(1.0, x);

  float q = floor(yp);
  float shift = 0.0;
  bool popping = false;
  bool hole = false;
  if (r < R && yp >= yr) {
    if (g > 0.0) {
      q = floor(yp + g);
      shift = g;
      hole = q <= yr;
    } else {
      popping = q == yr;
    }
  }
  float fy = yp + shift - q;

  float h = R - r;
  float row;
  bool isTo = q >= h;
  if (isTo) {
    row = q - h;
  } else {
    row = q;
    for (int k = 0; k < 6; k++) {
      float i = r - 1.0 - float(k);
      if (i < 0.0) break;
      if (row >= matchRow(c, i)) row += 1.0;
    }
  }

  vec2 suv = vec2(uv.x, clamp((row + fy) / R, 0.0, 1.0));
  vec4 col = isTo ? getToColor(suv) : getFromColor(suv);

  vec2 local = vec2(fract(uv.x * C), fy) - 0.5;
  float s = 1.0;
  if (popping) {
    s = 1.0 - smoothstep(0.35, 1.0, pop);
    float fl = sin(3.14159265 * min(pop * 1.6, 1.0));
    col.rgb = mix(col.rgb, vec3(1.0, 0.97, 0.85), flash * fl);
    col.rgb *= 1.0 + 0.3 * fl;
  }
  vec2 d = abs(local) - (0.5 * s - 0.022 * env);
  vec2 aspect = vec2(R * ratio / C, 1.0) / R;
  float rr = 0.08 * env;
  float sd = (length(max(d + rr, 0.0)) + min(max(d.x, d.y) + rr, 0.0) - rr);
  float inside = clamp(0.5 - sd * min(aspect.x, aspect.y) * 1080.0 / 1.5, 0.0, 1.0);
  inside = mix(1.0, inside, max(env, step(0.001, 1.0 - s)));
  if (hole) inside = 0.0;
  col.rgb *= 1.0 - 0.25 * env * smoothstep(-0.12, 0.0, sd);
  return mix(boardColor, col, inside);
}
