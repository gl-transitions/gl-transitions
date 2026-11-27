// Author: gre
// License: MIT
// Description: Thin grooves divide the outgoing picture into a wall of bricks; a glowing ball bounces around the frame and every brick it touches flashes and shrinks away onto the incoming picture, midway the ball splits in two to clear the wall faster, and the last bricks pop out together
// Tags: game, bricks, grid, bounce, graphic

// @range(2, 12, 1) Number of brick rows
uniform float rows; // = 6.0
// @range(0.5, 2) How fast the balls fly
uniform float speed; // = 1.0
// @color Color of the balls
uniform vec4 ballColor; // = vec4(1.0, 0.98, 0.9, 1.0)

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float tri(float x) { return 1.0 - abs(1.0 - mod(x, 2.0)); }

vec2 ball(float t, float rx, float ry, float n) {
  float T = (2.6 * t + 2.6 * t * t) * speed;
  // the second ball splits off the first at t = 0.3 and flies off the other way
  float T0 = 1.014 * speed;
  float D = n * (T - T0);
  vec2 u = vec2(0.5 + (T - D - 1.25 * D) * 1.6 / ratio, 0.02 + (T - D + 0.85 * D) * 1.31);
  vec2 b = vec2(tri(u.x), tri(u.y));
  return vec2(rx, ry) + b * vec2(1.0 - 2.0 * rx, 1.0 - 2.0 * ry);
}

vec4 transition(vec2 uv) {
  float cols = max(3.0, floor(rows * ratio + 0.5));
  vec2 grid = vec2(cols, rows);
  vec2 cell = floor(uv * grid);
  vec2 lo = cell / grid;
  vec2 hi = (cell + 1.0) / grid;
  float rad = 0.03;
  float rx = rad / ratio;

  float hit = 0.84 + 0.06 * hash(cell + 3.1);
  for (int k = 0; k < 52; k++) {
    float n = mod(float(k), 2.0);
    float pk = 0.04 + n * 0.26 + (0.8 - n * 0.26) * floor(float(k) / 2.0) / 25.0;
    vec2 b = ball(pk, rx, rad, n);
    vec2 inb = step(lo - vec2(rx, rad), b) * step(b, hi + vec2(rx, rad));
    if (inb.x * inb.y > 0.5) { hit = min(hit, pk); }
  }
  float age = progress - hit;
  float gone = smoothstep(0.0, 0.07, age);
  vec2 c = (lo + hi) * 0.5;
  vec2 hs = (hi - lo) * 0.5 * (1.0 - gone);
  vec2 d = abs(uv - c);
  float gut = 0.003 * smoothstep(0.0, 0.06, progress);
  vec2 edgeD = (hs - d) * vec2(ratio, 1.0);
  float inside = smoothstep(gut, gut + 0.002, min(edgeD.x, edgeD.y)) * (1.0 - step(0.999, gone));
  float flat0 = 1.0 - smoothstep(0.0, 0.02, progress);
  inside = max(inside, flat0 * (1.0 - gone));

  vec2 fuv = c + (uv - c) / max(1.0 - gone, 0.001);
  vec4 A = getFromColor(clamp(fuv, 0.0, 1.0));
  float flash = exp(-max(age, 0.0) * 45.0) * step(0.0, age);
  A.rgb = mix(A.rgb, vec3(1.0), 0.7 * flash);
  float bevel = clamp(min(edgeD.x, edgeD.y) / 0.02, 0.0, 1.0);
  A.rgb *= mix(0.82, 1.0, mix(1.0, bevel, smoothstep(0.0, 0.06, progress)));
  vec4 B = getToColor(uv);
  vec4 col = mix(B, A, inside);

  float show = smoothstep(0.02, 0.05, progress) * (1.0 - smoothstep(0.84, 0.88, progress));
  vec2 q = uv * vec2(ratio, 1.0);
  float glow = 0.0;
  for (int j = 0; j < 8; j++) {
    float n = mod(float(j), 2.0);
    float lag = floor(float(j) / 2.0) * 0.0035;
    vec2 b = ball(max(progress - lag, 0.0), rx, rad, n) * vec2(ratio, 1.0);
    float r = rad * (1.0 - floor(float(j) / 2.0) * 0.12);
    float on = n < 0.5 ? show : show * smoothstep(0.28, 0.31, progress);
    float dd = length(q - b);
    glow = max(glow, on * (1.0 - smoothstep(r - 0.003, r + 0.001, dd)) * (1.0 - floor(float(j) / 2.0) * 0.22));
    col.rgb += on * 0.25 * exp(-dd * dd / (rad * rad * 4.0)) * step(float(j), 1.5);
  }
  col = mix(col, ballColor, glow);
  return col;
}
