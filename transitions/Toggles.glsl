// Author: gre
// License: MIT
// Description: The picture becomes a grid of cards; pressing a card turns it over together with its four neighbours in a plus shape, some cards flipping back to the outgoing picture on the way, until eight presses later every card shows the incoming picture
// Tags: cards, flip, grid, puzzle, game, tiles

// @range(0.03, 0.08) Duration of one card flip, in progress units (longer flips would overlap on shared cards)
uniform float flip; // = 0.08
// @color Color behind the cards
uniform vec4 background; // = vec4(0.06, 0.06, 0.07, 1.0)

const vec2 GRID = vec2(6.0, 4.0);

// Pressing a card turns it and its four neighbours over; these eight presses turn every card an odd number of times.
float press(int k) {
  vec4 v = k < 4 ? vec4(8.0, 23.0, 0.0, 15.0) : vec4(9.0, 18.0, 5.0, 14.0);
  int i = k < 4 ? k : k - 4;
  return i == 0 ? v.x : (i == 1 ? v.y : (i == 2 ? v.z : v.w));
}

vec4 transition(vec2 uv) {
  // the grid runs along the long side, so portrait frames use it transposed
  vec2 st = ratio < 1.0 ? uv.yx : uv;
  vec2 frame = vec2(max(ratio, 1.0 / ratio), 1.0);
  vec2 cell = min(floor(st * GRID), GRID - 1.0);
  vec2 q = st * GRID - cell;
  float gap = smoothstep(0.0, 0.04, progress) * (1.0 - smoothstep(0.96, 1.0, progress));
  float spacing = 0.92 - flip;

  float turns = 0.0;
  float f = 0.0;
  float pressed = 0.0;
  for (int k = 0; k < 8; k++) {
    float id = press(k);
    vec2 pc = vec2(mod(id, GRID.x), floor(id / GRID.x));
    vec2 d = abs(pc - cell);
    float dist = d.x + d.y;
    if (dist < 1.5) {
      float t0 = 0.06 + float(k) * spacing / 8.0 + dist * flip * 0.3;
      float x = clamp((progress - t0) / flip, 0.0, 1.0);
      turns += step(1.0, x);
      if (x > 0.0 && x < 1.0) f = x;
      if (dist < 0.5) pressed = max(pressed, sin(3.14159265 * clamp((progress - t0 + flip * 0.4) / (flip * 0.8), 0.0, 1.0)));
    }
  }

  float e = smoothstep(0.0, 1.0, f);
  float c = cos(3.14159265 * e);
  float s = abs(c) * (1.0 - 0.1 * pressed);
  float sy = 1.0 - 0.1 * pressed - 0.06 * sin(3.14159265 * e);
  vec2 lq = (q - 0.5) / vec2(max(s, 1e-4), sy) + 0.5;
  float odd = mod(turns + step(0.5, e), 2.0);

  vec2 m = min(lq, 1.0 - lq) * frame / GRID;
  float inside = clamp(min(m.x, m.y) / 0.002 + 0.5 - gap * 2.0, 0.0, 1.0);
  inside = mix(1.0, inside, max(gap, step(0.001, abs(lq.x - q.x) + abs(lq.y - q.y))));

  vec2 g = clamp((cell + lq) / GRID, 0.0, 1.0);
  vec2 suv = ratio < 1.0 ? g.yx : g;
  vec4 col = odd > 0.5 ? getToColor(suv) : getFromColor(suv);
  col.rgb *= 0.6 + 0.4 * abs(c);
  return mix(background, col, inside);
}
