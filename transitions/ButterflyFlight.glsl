// Author: gre
// License: MIT
// Description: The outgoing picture becomes a butterfly: its two halves round off into wings that start beating, folding toward the viewer on the center line, and the butterfly flutters away up and to the right, growing smaller as it bobs along, until it leaves the frame and its shadow fades off the incoming picture
// Tags: 3d, fold, fly, nature, shadow

// @range(2, 8) Wing beats during the flight
uniform float beats; // = 5.0

const float PI = 3.1415927;

float ellipse(vec2 p, vec2 c, vec2 r, float a) {
  p -= c;
  p = mat2(cos(a), -sin(a), sin(a), cos(a)) * p;
  return (length(p / r) - 1.0) * min(r.x, r.y);
}

// signed distance of the wing, from the picture's half (hw wide) to a wing shape hw wide and h tall
float wing(vec2 v, float hw, float h, float m) {
  // the box reaches past the hinge so the two halves meet without a seam
  vec2 b = abs(v) - vec2(hw, 0.5);
  float rect = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0);
  vec2 w = v / vec2(hw, h);
  float fore = ellipse(w, vec2(0.5, 0.15), vec2(0.56, 0.33), 0.45);
  float hind = ellipse(w, vec2(0.36, -0.2), vec2(0.4, 0.28), -0.6);
  float body = ellipse(w, vec2(0.0, -0.04), vec2(0.06, 0.4), 0.0);
  return mix(rect, min(min(fore, hind), body) * min(hw, h), m);
}

// returns the picture uv in xy, coverage in z, wing tilt in w
vec4 butterfly(vec2 p, float t, float blur) {
  // no ease-out: the butterfly keeps speeding up until it leaves the frame, just before the end
  float fly = clamp((t - 0.08) / 0.92, 0.0, 1.0);
  float S = mix(1.0, 0.15, smoothstep(0.0, 0.8, fly));
  vec2 c = vec2(0.5 * ratio + 0.2, 0.66) * fly * fly + vec2(0.0, 0.24 * sin(PI * beats * t) * fly * (1.0 - fly));
  float tilt = -0.35 * fly;
  vec2 q = mat2(cos(tilt), sin(tilt), -sin(tilt), cos(tilt)) * (p - c) / S;
  float amp = 1.15 * smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.9, 1.0, t));
  float th = amp * (0.5 - 0.5 * cos(2.0 * PI * beats * t));
  float sn = sin(th), cs = cos(th);
  float hw = 0.5 * ratio;
  // narrow frames get a shorter butterfly, so its wings keep their shape
  float h = min(1.0, 1.15 * hw);
  // the camera distance follows the wing size, so a folded tip never reaches the camera on wide frames
  float f = 2.5 * max(hw, h);
  float X = abs(q.x);
  float d = X * f / (cs * f + X * sn);
  float y = q.y * (f - d * sn) / f;
  float m = smoothstep(0.0, 0.12, t);
  float sd = wing(vec2(d, y), hw, h, m);
  float px = (0.003 + blur) / S * smoothstep(0.0, 0.04, t) + 1e-4;
  float cov = clamp(-sd / px + 1.0 - smoothstep(0.0, 0.04, t) * 0.5, 0.0, 1.0);
  // the body is drawn flat, in front of the beating wings
  float bd = ellipse(q, vec2(0.0, -0.02), vec2(0.025 * hw, 0.38 * h), 0.0);
  float body = m * (1.0 - smoothstep(-px, px, bd));
  return vec4(vec2(sign(q.x) * d / ratio + 0.5, y + 0.5), cov, max(0.45 * sn, body));
}

vec4 transition(vec2 uv) {
  float t = progress;
  vec2 p = (uv - 0.5) * vec2(ratio, 1.0);
  vec4 bf = butterfly(p, t, 0.0);
  vec4 shadowBf = butterfly(p - vec2(0.03, -0.05) * smoothstep(0.0, 0.3, t), t, 0.02 * smoothstep(0.0, 0.3, t));
  vec4 b = getToColor(uv);
  b.rgb *= 1.0 - 0.45 * shadowBf.z * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.85, 1.0, t));
  vec4 a = getFromColor(clamp(bf.xy, 0.0, 1.0));
  a.rgb *= 1.0 - 0.8 * bf.w;
  return mix(b, a, bf.z);
}
