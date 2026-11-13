// Author: gre
// License: MIT
// Description: The incoming image is dealt onto the frame like a hand of cards: tile after tile is flicked from below the frame, spinning through the air with a lifting shadow, and slides to a stop in its place until the picture is complete
// Tags: tiles, card, rotate, shadow, 3d

// @param Number of cards (columns, rows), at most 6 by 6
uniform ivec2 grid; // = ivec2(4, 3)
// @param Point the cards are dealt from, can be outside the frame
uniform vec2 deck; // = vec2(0.5, -0.4)
// @range(0, 2) Turns a card makes on its way, before it settles straight
uniform float spin; // = 0.6
// @range(0, 1) Darkness of the shadows the cards cast
uniform float shadow; // = 0.5

const float PI = 3.141592653589793;
const int MAX_CARDS = 36;
// time between two cards, relative to the time a card takes from the deck to its place
const float DEAL = 0.16;
// part of its way after which a card touches down and starts sliding
const float TOUCH = 0.55;
// speed of the throw, relative to an even pace
const float THROW = 2.2;
// length of the slide, in card heights
const float SLIDE = 0.35;
// highest point of a card's flight, and distance of the eye to the table, in frame heights
const float LIFT = 0.45;
const float EYE = 2.4;
// width of the anti-aliased edges, in frame heights
const float EDGE = 0.0015;

float hash(float n) {
  vec2 p = fract(vec2(n) * vec2(0.1031, 0.1030));
  p += dot(p, p.yx + 33.33);
  return fract((p.x + p.y) * p.x);
}

vec2 gridSize() {
  return clamp(vec2(grid), 1.0, 6.0);
}

// local time of card j: 0 on the deck, 1 once it lies still in its place
float cardTime(float j, float n) {
  // the last card lands at the end
  float flight = 1.0 / (1.0 + (n - 1.0) * DEAL);
  return clamp((progress - j * DEAL * flight) / flight, 0.0, 1.0);
}

// center of the place of card j, dealt in reading order from the top left
vec2 cardCell(float j, vec2 g) {
  float row = floor(j / g.x);
  return vec2(j - row * g.x, g.y - 1.0 - row);
}

// signed distance to the edge of a card (positive inside), from its local coordinates q (0..1) and its size
float cardDist(vec2 q, vec2 size) {
  vec2 e = min(q, 1.0 - q) * size;
  return min(e.x, e.y);
}

vec4 transition(vec2 uv) {
  if (progress <= 0.0) return getFromColor(uv);
  if (progress >= 1.0) return getToColor(uv);

  vec2 g = gridSize();
  float n = g.x * g.y;
  vec2 asp = vec2(ratio, 1.0);
  vec2 size = asp / g;
  vec2 p = uv * asp;
  vec2 origin = deck * asp;
  float darkness = clamp(shadow, 0.0, 1.0);

  // the table: the cards already in their place, the outgoing image elsewhere
  vec2 own = min(floor(uv * g), g - 1.0);
  float ownIndex = (g.y - 1.0 - own.y) * g.x + own.x;
  vec4 col = cardTime(ownIndex, n) >= 1.0 ? getToColor(uv) : getFromColor(uv);

  // the cards on their way, from the first dealt to the last: later cards lie on top
  for (int i = 0; i < MAX_CARDS; i++) {
    float j = float(i);
    if (j >= n) break;
    float u = cardTime(j, n);
    if (u <= 0.0) break;
    if (u >= 1.0) continue;

    vec2 cell = cardCell(j, g);
    vec2 target = (cell + 0.5) * size;
    vec2 way = target - origin;
    float len = max(length(way), 1e-3);
    vec2 side = vec2(-way.y, way.x);
    float r1 = hash(j + 1.0);
    float r2 = hash(j + 60.0);
    float turn = r2 < 0.5 ? -1.0 : 1.0;
    // share of its way the card slides on the table once it has touched down
    float slide = min(SLIDE * size.y / len, 0.5);
    // thrown fast, it flies (a), touches down and slides to a stop (s), braked by the table
    float a = min(u / TOUCH, 1.0);
    float s = clamp((u - TOUCH) / (1.0 - TOUCH), 0.0, 1.0);
    // the flight ends at the speed the slide starts with
    float v1 = 2.0 * slide * TOUCH / ((1.0 - TOUCH) * (1.0 - slide));
    float f = (3.0 - 2.0 * a) * a * a + THROW * (a * a * a - 2.0 * a * a + a) + v1 * (a * a * a - a * a);
    float e = u < TOUCH ? (1.0 - slide) * f : 1.0 - slide * (1.0 - s) * (1.0 - s);
    // a slight curve, bending the way the card spins
    vec2 c = origin + way * e + side * turn * (0.05 + 0.05 * r1) * sin(PI * e);
    // height above the table, zero from the touch down on
    float h = LIFT * (0.7 + 0.3 * r1) * sin(PI * a) * (1.0 - 0.35 * a);
    float angle = turn * spin * (0.8 + 0.4 * r2) * 2.0 * PI * (1.0 - e);
    // tilt of the card in the air, which wobbles as it spins
    float tilt = 0.45 * sin(PI * a) * cos(angle * 0.5 + 6.0 * r1);
    // 1 in the air, 0 once on the table
    float air = 1.0 - a * a;
    float fade = smoothstep(0.0, 0.05, u);

    // shadow on the table, pushed away from the light and softened with height
    vec2 sp = p - c - vec2(0.18, -0.3) * h - vec2(0.002, -0.003);
    float ca = cos(angle), sa = sin(angle);
    mat2 rot = mat2(ca, -sa, sa, ca);
    vec2 sq = rot * sp / size + 0.5;
    float soft = 0.006 + 0.08 * h;
    float sh = smoothstep(-soft, soft, cardDist(sq, size));
    // dark under a card in the air, a thin contact shadow fading as it comes to rest
    float dark = mix(0.8 * (1.0 - s), 0.65 - 0.3 * h / LIFT, air);
    col.rgb *= 1.0 - fade * darkness * dark * sh;

    // the card, closer to the eye as it rises, seen in perspective as it tilts
    vec2 d = rot * (p - c) * (EYE - h) / EYE;
    float ct = cos(tilt), st = sin(tilt);
    // past the horizon of the tilted card, the point is off the card
    float den = EYE * ct + d.y * st;
    float k = den > 1e-3 ? EYE * ct / den : 1e3;
    vec2 q = vec2(k * d.x, k * d.y * ct + EYE * (1.0 - k) * st) / size + 0.5;
    // its edges sharpen as it comes to rest, to meet its neighbors without a seam
    float edge = EDGE * (1.0 + 2.0 * air) * min(10.0 * (1.0 - s), 1.0);
    float m = fade * clamp(cardDist(q, size) / max(edge, 1e-6) + 0.5, 0.0, 1.0);
    if (m > 0.0) {
      vec4 face = getToColor((cell + clamp(q, 0.0, 1.0)) / g);
      // light from the upper left: a tilted card catches it or turns away from it
      float light = 1.0 + 0.6 * st * (0.6 - 0.4 * turn * sin(angle));
      // a thin bright rim while it travels
      float rim = 1.0 - smoothstep(0.0, 0.008, cardDist(q, size));
      face.rgb = mix(min(face.rgb * light, vec3(face.a)), vec3(face.a), 0.45 * air * rim);
      col = mix(col, face, m);
    }
  }
  return col;
}
