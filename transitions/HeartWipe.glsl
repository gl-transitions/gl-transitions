// Author: gre
// License: MIT
// Description: A heart grows from the center with a little heartbeat to reveal the incoming image
// Tags: shape, wipe, heart

// @param Center of the heart
uniform vec2 center; // = vec2(0.5, 0.5)
// @range(0, 0.1) Softness of the heart's edge
uniform float smoothness; // = 0.006
// @range(0, 1) Strength of the heartbeat throb as the heart grows
uniform float pulse; // = 0.5
// @color Color of the soft light glowing along the heart's edge
uniform vec3 glowColor; // = vec3(1.0, 0.85, 0.9)
// @range(0, 1) Strength of the glow (0 for a clean edge)
uniform float glow; // = 0.3

// The heart shape: tip at (0, 0), notch at (0, 1), lobes are circles of radius sqrt(2)/4
// centered at (+-0.25, 0.75), tangent to the lines y = |x|. HEART_O is its center.
#define HEART_O vec2(0.0, 0.55)
#define LOBE vec2(0.25, 0.75)
#define LOBE_R 0.35355339

float dot2(vec2 v) { return dot(v, v); }

// Exact signed distance to the heart
float sdHeart(vec2 p) {
  p.x = abs(p.x);
  if (p.x + p.y > 1.0) return sqrt(dot2(p - LOBE)) - LOBE_R;
  return sqrt(min(dot2(p - vec2(0.0, 1.0)), dot2(p - 0.5 * max(p.x + p.y, 0.0)))) * sign(p.x - p.y);
}

// Scale of the smallest heart (centered on HEART_O) that contains p: the heart is the union of a
// lobe disk and the triangle |x| <= y, |x| + y <= 1, both convex around HEART_O, so the boundary
// along a ray is the farthest of their exits.
float heartScale(vec2 p) {
  float l = length(p);
  if (l < 1e-6) return 0.0;
  vec2 d = vec2(abs(p.x), p.y) / l;
  vec2 m = HEART_O - LOBE;
  float b = dot(m, d);
  float tDisk = -b + sqrt(b * b - dot2(m) + LOBE_R * LOBE_R);
  float tSide = d.x > d.y ? HEART_O.y / (d.x - d.y) : 1e6;
  float tTop = d.x + d.y > 0.0 ? (1.0 - HEART_O.y) / (d.x + d.y) : 1e6;
  return l / max(tDisk, min(tSide, tTop));
}

vec4 transition (vec2 uv) {
  vec4 a = getFromColor(uv);
  vec4 b = getToColor(uv);
  vec2 asp = vec2(ratio, 1.0);
  vec2 c = center * asp;
  // Scale at which the heart covers the whole frame: the corners, plus the point of the top edge
  // in line with the notch (the only concave part of the heart)
  float cx = clamp(center.x, 0.0, 1.0) * ratio;
  float full = max(
    max(max(heartScale(vec2(0.0, 0.0) - c), heartScale(vec2(ratio, 0.0) - c)),
        max(heartScale(vec2(0.0, 1.0) - c), heartScale(vec2(ratio, 1.0) - c))),
    heartScale(vec2(cx, 1.0) - c));
  float sm = max(smoothness, 0.001);
  // Margin so the soft edge is past the frame at progress = 1
  full += 4.0 * sm;

  // Eased growth with two heartbeats riding on it: the heart surges, then almost stops
  float p = progress;
  float e = p * p * (2.0 - p);
  float env = max(sin(3.14159265 * p), 0.0);
  float beat = sin(6.28318531 * 2.0 * p) * env * env;
  float s = full * clamp(e + 0.09 * pulse * beat, 0.0, 1.0);
  if (s <= 0.0) return a;

  vec2 q = uv * asp - c;
  float d = s * sdHeart(q / s + HEART_O);
  float m = smoothstep(0.0, sm, -d);
  vec4 col = mix(a, b, m);
  // Soft light just outside the edge, faded in and out with the transition (adds no alpha)
  float light = exp(-max(d, 0.0) / (0.008 + sm)) * (1.0 - m) * glow * min(1.0, 4.0 * env);
  return col + vec4(glowColor * light, 0.0);
}
