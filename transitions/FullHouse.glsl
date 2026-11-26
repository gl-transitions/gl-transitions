// Author: gre
// License: MIT
// Description: A number-puzzle grid of nine by nine cells in heavier three by three boxes appears over the grayed outgoing picture; its cells fill in with the incoming picture one by one, box after box, and each row, column or box that is complete flashes with a sweep of light, until the whole board is the incoming picture
// Tags: grid, puzzle, game, cells, reveal, playful

// @range(0, 1) Brightness of the flash when a row, column or box is complete
uniform float flash; // = 0.9
// @color Lines of the grid
uniform vec4 gridColor; // = vec4(0.05, 0.05, 0.08, 1.0)

const float FILL = 0.05;

float hash(vec2 p) {
  vec3 q = fract(p.xyx * 0.1031);
  q += dot(q, q.yzx + 33.33);
  return fract((q.x + q.y) * q.z);
}

float boxRank(vec2 b) {
  float i = b.x + 3.0 * b.y;
  vec4 lo = vec4(4.0, 0.0, 7.0, 2.0);
  vec4 hi = vec4(8.0, 1.0, 5.0, 3.0);
  if (i > 7.5) return 6.0;
  vec4 v = i < 3.5 ? lo : hi;
  return dot(v, max(vec4(0.0), 1.0 - abs(vec4(0.0, 1.0, 2.0, 3.0) - mod(i, 4.0))));
}

float fillTime(vec2 c) {
  return 0.05 + 0.75 * (boxRank(floor((c + 0.5) / 3.0)) / 8.0 * 0.55 + hash(c + vec2(13.0, 17.0)) * 0.45);
}

float pulse(float t) {
  float x = (progress - t) / 0.13;
  return x > 0.0 && x < 1.0 ? (1.0 - x) * (1.0 - x) * smoothstep(0.0, 0.15, x) : 0.0;
}

vec4 transition(vec2 uv) {
  vec2 g = uv * 9.0;
  vec2 c = min(floor(g), 8.0);
  vec2 f = g - c;
  // + 0.5: an exact c / 3.0 can round below the integer on some targets
  vec2 b0 = floor((c + 0.5) / 3.0) * 3.0;

  float rowDone = 0.0, colDone = 0.0, boxDone = 0.0;
  for (int i = 0; i < 9; i++) {
    float k = float(i);
    rowDone = max(rowDone, fillTime(vec2(k, c.y)));
    colDone = max(colDone, fillTime(vec2(c.x, k)));
    float by = floor((k + 0.5) / 3.0);
    boxDone = max(boxDone, fillTime(b0 + vec2(k - 3.0 * by, by)));
  }

  float t = clamp((progress - fillTime(c)) / FILL, 0.0, 1.0);
  float s = t * (1.0 + 0.25 * sin(3.14159265 * t));
  vec2 d = abs(f - 0.5) * vec2(ratio, 1.0) / 9.0;
  vec2 hs = vec2(ratio, 1.0) / 18.0 * s;
  float r = 0.012 * (1.0 - t);
  vec2 q = d - hs + r;
  float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
  float into = t >= 1.0 ? 1.0 : clamp(0.5 - sd * 900.0, 0.0, 1.0) * step(0.0001, t);
  float env = smoothstep(0.0, 0.05, progress) * (1.0 - smoothstep(0.88, 1.0, progress));
  vec4 from = getFromColor(uv);
  from.rgb = mix(from.rgb, vec3(dot(from.rgb, vec3(0.3, 0.59, 0.11))), 0.6 * env) * (1.0 - 0.3 * env);
  vec4 col = mix(from, getToColor(uv), into);

  float pr = pulse(rowDone + FILL), pc = pulse(colDone + FILL), pb = pulse(boxDone + FILL);
  float sweepR = 1.0 - smoothstep(0.0, 0.25, abs(uv.x - clamp((progress - rowDone - FILL) / 0.13, 0.0, 1.0)));
  float sweepC = 1.0 - smoothstep(0.0, 0.25, abs(uv.y - 1.0 + clamp((progress - colDone - FILL) / 0.13, 0.0, 1.0)));
  float glow = max(max(pr * (0.4 + 0.6 * sweepR), pc * (0.4 + 0.6 * sweepC)), pb * 0.8);
  col.rgb = mix(col.rgb, vec3(1.0, 0.96, 0.82), flash * glow);

  vec2 e = min(f, 1.0 - f) * vec2(ratio, 1.0) / 9.0 * 1080.0;
  vec2 bf = abs(mod(g + 1.5, 3.0) - 1.5) * vec2(ratio, 1.0) / 9.0 * 1080.0;
  float thin = clamp(1.5 - min(e.x, e.y), 0.0, 1.0);
  float thick = clamp(3.5 - min(bf.x, bf.y), 0.0, 1.0);
  col.rgb = mix(col.rgb, gridColor.rgb, env * max(thin * 0.6, thick * 0.9));
  return col;
}
