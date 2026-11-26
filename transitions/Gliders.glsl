// Author: gre
// License: MIT
// Description: A flock of tiny five-cell gliders from the cellular automaton wriggles diagonally across a faint grid on the outgoing picture; every cell a glider brings to life turns into the incoming picture, so the new image is laid down in their wake
// Tags: grid, cells, game, pixel, diagonal, playful

// @range(0, 1) Brightness of the live cells
uniform float glow; // = 0.85
// @color Light of the live cells
uniform vec4 cellColor; // = vec4(1.0, 0.95, 0.7, 1.0)

const float ROWS = 12.0;

float hash(float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

// The four phases of a glider as 4x4 bit masks; it moves one cell right and down every four generations.
float alive(vec2 rel, float phase) {
  if (rel.x < 0.0 || rel.y < 0.0 || rel.x > 3.0 || rel.y > 3.0) return 0.0;
  float m = phase < 0.5 ? 1858.0 : (phase < 1.5 ? 9808.0 : (phase < 2.5 ? 25920.0 : 27680.0));
  // powers of two picked by hand rather than exp2, which is approximate on some targets
  float row = rel.y < 0.5 ? 1.0 : (rel.y < 1.5 ? 16.0 : (rel.y < 2.5 ? 256.0 : 4096.0));
  float bit = rel.x < 0.5 ? 1.0 : (rel.x < 1.5 ? 2.0 : (rel.x < 2.5 ? 4.0 : 8.0));
  return mod(floor(m / (row * bit)), 2.0);
}

vec4 transition(vec2 uv) {
  float cols = floor(ROWS * ratio + 0.5);
  vec2 cell = vec2(min(floor(uv.x * cols), cols - 1.0), ROWS - 1.0 - min(floor(uv.y * ROWS), ROWS - 1.0));
  vec2 f = fract(uv * vec2(cols, ROWS));
  float lane = 4.0 * floor((cell.x - cell.y + 2.0) / 4.0);
  float m = lane >= 0.0 ? -4.0 : -lane - 4.0;
  vec2 b0 = vec2(lane + m, m);
  float start = 0.17 * hash(lane + 11.0);
  // the longest diagonal, so narrow frames don't finish early and wait
  float gens = 4.0 * min(cols, ROWS) + 22.0;
  // gliders start just off the frame, at generation 3: no cell is born before generation 4
  float gen = 3.0 + (progress - start) / (0.95 - start) * (gens - 3.0);

  float born = 1e4;
  for (int j = 0; j < 4; j++) {
    float k = cell.y - b0.y - 3.0 + float(j);
    for (int p = 0; p < 4; p++) {
      float g = 4.0 * k + float(p);
      if (k >= 0.0 && alive(cell - b0 - k, float(p)) > 0.5) born = min(born, g);
    }
  }

  float gc = floor(gen);
  float kc = floor(gc / 4.0);
  float live = gen >= 0.0 ? alive(cell - b0 - kc, gc - 4.0 * kc) : 0.0;
  float env = smoothstep(0.0, 0.04, progress) * (1.0 - smoothstep(0.94, 1.0, progress));

  vec4 col = born <= gen ? getToColor(uv) : getFromColor(uv);
  float age = clamp((gen - born) / 12.0, 0.0, 1.0);
  col.rgb *= 1.0 + 0.35 * (1.0 - age) * step(born, gen) * env;

  vec2 e = min(f, 1.0 - f) * vec2(ratio / cols, 1.0 / ROWS) * 1080.0;
  float edge = clamp(1.2 - min(e.x, e.y), 0.0, 1.0);
  col.rgb *= 1.0 - 0.25 * env * edge;

  vec2 inner = abs(f - 0.5) * vec2(ratio / cols, 1.0 / ROWS) * 1080.0;
  float sq = clamp(0.5 / ROWS * 1080.0 * 0.86 - max(inner.x, inner.y), 0.0, 1.0);
  col.rgb = mix(col.rgb, mix(cellColor.rgb, col.rgb * 1.8, 0.25), glow * live * sq);
  return col;
}
