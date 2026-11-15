// Author: gre
// License: MIT
// Description: Folded paper strips of the incoming image slide in one after another around a shrinking polygonal hole, each turned a little from the last so their creased edges spiral inward, until the hole closes on the center
// Tags: paper, iris, wipe, shape, shadow

// @range(3, 6, 1) Number of sides of the hole
uniform int sides; // = 5
// @range(2, 5, 1) Number of rounds of strips around the hole
uniform int rounds; // = 3
// @range(-0.3, 0.3) How much each strip turns from the one before, in radians
uniform float twist; // = 0.16
// @range(0, 1) Strength of the creases' highlights and of the strips' shadows
uniform float shading; // = 0.6

const float PI = 3.141592653589793;
const float AA = 0.004;
// strip-steps each strip takes to slide in, so a few slide at once
const float D = 1.8;

vec4 transition(vec2 uv) {
  vec2 aspect = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * aspect;
  float R = 0.5 * length(aspect);
  float ns = clamp(float(sides), 3.0, 6.0);
  float N = ns * clamp(float(rounds), 2.0, 5.0);
  float L = N - ns;
  // the last round closes the hole in a quicker burst
  float tt = pow(clamp(progress / 0.9, 0.0, 1.0), 0.85) * (L + 0.4 * (ns - 1.0) + D);
  float deco = shading * (1.0 - smoothstep(0.88, 1.0, progress));
  float w0 = 0.6 * R;
  float turn = 2.0 * PI / ns + twist;
  vec2 rot = vec2(cos(turn), sin(turn));
  vec2 n = vec2(cos(0.3), sin(0.3));

  vec4 col = getFromColor(uv);
  vec4 to = getToColor(uv);
  for (int i = 0; i < 30; i++) {
    float k = float(i);
    if (k >= N) break;
    float s = clamp((tt - min(k, L + 0.4 * (k - L))) / D, 0.0, 1.0);
    if (s <= 0.0) break;
    float lift = 1.0 - s;
    float e = 1.0 - lift * lift * lift;
    // the whole last round crosses the center so the strips surely cover the frame
    float target = mix(0.68 * R, -0.03, min((k + 1.0) / (L + 1.0), 1.0));
    float d = dot(q, n) - target - (R + 0.06 - target) * (1.0 - e);
    // the first round reaches past the frame; the others fade their outer edge out as they land
    float landed = k < ns ? 1.0 : smoothstep(0.7, 1.0, s);
    float m = smoothstep(-AA, AA, d) * mix(1.0 - smoothstep(w0 - AA, w0 + AA, d), 1.0, landed);
    float reach = 0.025 + 0.03 * lift;
    float sh = (1.0 - smoothstep(0.0, reach, -d)) * step(d, 0.0) + (1.0 - landed) * (1.0 - smoothstep(0.0, 0.6 * reach, d - w0)) * step(w0, d);
    col.rgb *= 1.0 - (0.4 + 0.2 * lift) * deco * sh * sh;
    vec4 b = to;
    b.rgb = mix(b.rgb, vec3(1.0), 0.35 * deco * b.a * exp(-max(d, 0.0) / 0.005));
    b.rgb *= 1.0 - deco * (0.12 * smoothstep(0.0, w0, d) * (mod(k, 2.0) < 0.5 ? 1.0 : 0.5) + 0.1 * lift);
    col = mix(col, b, m);
    n = vec2(n.x * rot.x - n.y * rot.y, n.x * rot.y + n.y * rot.x);
  }
  return col;
}
