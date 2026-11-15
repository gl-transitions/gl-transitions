// Author: gre
// License: MIT
// Description: Night crosses the frame like the shadow line of a turning globe: a warm dusk glows along its curved edge and dims the outgoing image into blue moonlight that keeps it legible, then a second curved edge glows rose as dawn and brings up the daylight on the incoming image
// Tags: light, night, day, wipe, directional

// @param Direction the night travels toward
uniform vec2 direction; // = vec2(1.0, 0.2)
// @range(0.2, 1.2) Width of the night between dusk and dawn, in frame heights
uniform float night; // = 0.7
// @range(0, 1) How dark the night gets
uniform float darkness; // = 0.8
// @range(-1, 1) Bow of the dusk and dawn lines, as seen on a globe
uniform float bow; // = 0.5
// @color Light of the setting sun along the dusk line
uniform vec3 dusk; // = vec3(1.0, 0.52, 0.24)
// @color Light of the rising sun along the dawn line
uniform vec3 dawn; // = vec3(1.0, 0.66, 0.62)
// @color Tint of the moonlight in the night
uniform vec3 moon; // = vec3(0.42, 0.56, 1.0)

const float TW = 0.16;

float bent(vec2 q, vec2 dir) {
  float y = dot(q, vec2(-dir.y, dir.x));
  return dot(q, dir) - bow * y * y;
}

vec4 transition(vec2 uv) {
  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(1.0, 0.0);
  vec2 a = vec2(0.5 * ratio, 0.5);
  vec2 b = vec2(a.x, -a.y);
  float x = bent((uv - 0.5) * vec2(ratio, 1.0), dir);
  float e = a.x * abs(dir.x) + a.y * abs(dir.y);
  float n = max(night, 0.05);
  // a bent line's extremes are at the corners or bounded by the straight one;
  // 0.09 covers the twilight rim, which reaches 0.08 ahead of the line
  float lo = min(-e, min(min(bent(a, dir), bent(-a, dir)), min(bent(b, dir), bent(-b, dir)))) - 0.09;
  float hi = max(e, max(max(bent(a, dir), bent(-a, dir)), max(bent(b, dir), bent(-b, dir)))) + 0.09;
  float t = mix(progress, smoothstep(0.0, 1.0, progress), 0.25);
  float d = mix(lo, hi + n, t);
  float mid = d - 0.5 * n;

  float ahead = smoothstep(mid - 0.12 * n, mid + 0.12 * n, x);
  vec4 c = mix(getToColor(uv), getFromColor(uv), ahead);
  float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
  // bright parts keep the light a little longer at dusk and catch it earlier at dawn, like peaks
  float into = min(d - x, x - d + n) - 0.06 * l;
  float dark = smoothstep(-0.25 * TW, TW, into) * mix(0.75, 1.0, smoothstep(0.0, 0.5 * n, into));
  float gi = (into - 0.1 * TW) / (0.6 * TW);
  float rim = max(1.0 - gi * gi, 0.0);
  // the low sun's light spreads far ahead of the line, so it fades in and out with the transition
  float env = smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.8, 1.0, progress));
  float wide = env * exp(-max(-into, 0.0) / 0.3) * (1.0 - dark);
  vec3 sun = mix(dawn, dusk, ahead);

  vec3 lit = mix(c.rgb, vec3(l), 0.7) * moon * 1.2 * (0.12 + 0.6 * l * l);
  vec3 col = mix(c.rgb, lit, dark * darkness);
  col = mix(col, col * sun * 1.25, clamp(0.6 * rim * rim + 0.35 * wide, 0.0, 1.0));
  return vec4(col, c.a);
}
