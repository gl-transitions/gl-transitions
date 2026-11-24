// Author: gre
// License: MIT
// Description: The outgoing picture pinches by its corners into a diamond kite with a taped hem and a ribbon tail of bows; it catches the wind, tugs on its string and swoops from side to side as it climbs away, fluttering and shrinking, into the sky of the incoming picture
// Tags: kite, fly, object, 3d, playful

// @range(0, 1) How hard the wind shakes the sail and the tail
uniform float flutter; // = 0.6
// @range(0, 1) Strength of the shading on the sail
uniform float shading; // = 0.6
// @color Ribbon tail, bows and hem tape
uniform vec4 ribbon; // = vec4(0.85, 0.25, 0.15, 1.0)
// @color Flying line
uniform vec4 lineColor; // = vec4(0.15, 0.15, 0.15, 0.8)

const float PI = 3.14159265;

vec2 rot(vec2 v, float a) {
  float c = cos(a), s = sin(a);
  return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

float cross2(vec2 a, vec2 b) { return a.x * b.y - a.y * b.x; }

float segDist(vec2 q, vec2 a, vec2 b) {
  vec2 ab = b - a;
  float h = clamp(dot(q - a, ab) / dot(ab, ab), 0.0, 1.0);
  return length(q - a - ab * h);
}

vec2 kiteVertex(vec2 k, float tilt, float roll, vec2 c, float s, vec2 wob) {
  k += wob;
  // pitch back around the cross spar: the top recedes, the bottom comes closer
  vec3 k3 = vec3(k.x, k.y * cos(tilt), k.y * sin(tilt));
  return c + rot(s * k3.xy / (1.0 + 0.7 * k3.z), roll);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  vec2 q = (uv - 0.5) * asp;
  float pin = smoothstep(0.0, 0.26, p);
  // ends at speed: the kite must still be leaving the frame on the last frames
  float u = clamp((p - 0.16) / 0.84, 0.0, 1.0);
  float t = u * u * (1.7 - 0.7 * u);
  float env = pin * (1.0 - t * 0.5);

  vec2 c = vec2(0.28 * ratio * sin(2.0 * PI * 1.1 * t) * (1.0 - 0.4 * t), 0.12 * pin + 0.3 * t + 0.42 * t * t * t);
  float s = 0.72 * min(1.0, 1.1 * ratio) * mix(1.0, 0.1, t);
  float roll = 0.5 * sin(2.0 * PI * 1.25 * t + 0.6) * pin * (1.0 - 0.5 * t);
  float tilt = 0.55 * pin + 0.2 * sin(2.0 * PI * 2.5 * t);
  float w = 0.025 * flutter * pin;
  float ph = 34.0 * p;

  vec2 hr = 0.5 * asp;
  vec2 p0 = mix(vec2(-hr.x, -hr.y), kiteVertex(vec2(-0.4, 0.1), tilt, roll, c, s, w * vec2(sin(ph), cos(ph * 1.3))), pin);
  vec2 p1 = mix(vec2(hr.x, -hr.y), kiteVertex(vec2(0.0, -0.62), tilt, roll, c, s, w * vec2(sin(ph * 1.7 + 1.0), 0.0)), pin);
  vec2 p2 = mix(vec2(hr.x, hr.y), kiteVertex(vec2(0.4, 0.1), tilt, roll, c, s, w * vec2(sin(ph + 2.0), cos(ph * 1.1 + 2.0))), pin);
  vec2 p3 = mix(vec2(-hr.x, hr.y), kiteVertex(vec2(0.0, 0.44), tilt, roll, c, s, w * vec2(0.0, sin(ph * 0.9 + 3.0))), pin);

  // square -> quad homography, then its adjugate to go back from the screen
  float dx1 = p1.x - p2.x, dx2 = p3.x - p2.x, dx3 = p0.x - p1.x + p2.x - p3.x;
  float dy1 = p1.y - p2.y, dy2 = p3.y - p2.y, dy3 = p0.y - p1.y + p2.y - p3.y;
  float den = dx1 * dy2 - dx2 * dy1;
  float g = (dx3 * dy2 - dx2 * dy3) / den;
  float h = (dx1 * dy3 - dx3 * dy1) / den;
  float a = p1.x - p0.x + g * p1.x, b = p3.x - p0.x + h * p3.x;
  float d = p1.y - p0.y + g * p1.y, e = p3.y - p0.y + h * p3.y;
  float cx = p0.x, fy = p0.y;
  vec3 r0 = vec3(e - fy * h, cx * h - b, b * fy - cx * e);
  vec3 r1 = vec3(fy * g - d, a - cx * g, cx * d - a * fy);
  vec3 r2 = vec3(d * h - e * g, b * g - a * h, a * e - b * d);
  vec3 Q = vec3(q, 1.0);
  // dot(r2, Q) is positive all over the sail: kept off 0 past the vanishing line
  vec2 k = clamp(vec2(dot(r0, Q), dot(r1, Q)) / max(dot(r2, Q), 1e-4), -1.0, 2.0);

  float sd = min(min(cross2(p1 - p0, q - p0) / length(p1 - p0), cross2(p2 - p1, q - p1) / length(p2 - p1)),
                 min(cross2(p3 - p2, q - p2) / length(p3 - p2), cross2(p0 - p3, q - p3) / length(p0 - p3)));
  float cov = clamp(0.5 + sd / (0.0025 * pin + 1e-5), 0.0, 1.0);

  vec4 bg = getToColor(0.5 + (uv - 0.5) / (1.0 + 0.08 * (1.0 - p)));
  bg.rgb *= bg.a;

  float den2 = cross2(p2 - p0, p3 - p1);
  vec2 hub = p0 + (p2 - p0) * cross2(p1 - p0, p3 - p1) / den2;
  vec2 anchor = vec2(-0.3 * ratio, -0.9);
  float str = (1.0 - smoothstep(0.0025 * s + 0.0006, 0.0025 * s + 0.002, segDist(q, hub, anchor)))
            * smoothstep(0.15, 0.35, p) * (1.0 - smoothstep(0.5, 0.66, c.y));
  bg = mix(bg, vec4(lineColor.rgb, 1.0), str * lineColor.a);

  vec2 dn = normalize(p1 - hub + vec2(0.0, -0.4 * length(p1 - hub)));
  vec2 pr = vec2(-dn.y, dn.x);
  float L = 0.95 * s;
  vec2 tq = q - p1;
  float al = dot(tq, dn) / L;
  float wav = (0.08 * s) * sin(10.0 * al - 22.0 * p - 1.0) * al * (0.12 + 1.2 * flutter);
  float slope = (0.8 * s / L) * cos(10.0 * al - 22.0 * p - 1.0) * al * (0.12 + 1.2 * flutter);
  float ac = (dot(tq, pr) - wav) / sqrt(1.0 + slope * slope);
  float tail = (1.0 - smoothstep(0.004 * s, 0.004 * s + 0.0015, abs(ac))) * step(0.0, al) * (1.0 - smoothstep(0.97, 1.0, al));
  float bw = 0.055 * s;
  float bows = 0.0, fold = 0.0;
  for (int i = 0; i < 5; i++) {
    float bt = 0.2 + 0.18 * float(i);
    float ba = (al - bt) * L;
    float m = (1.0 - smoothstep(bw - 0.0015, bw, abs(ac))) * (1.0 - smoothstep(0.0, 0.0015, abs(ba) - 0.35 * bw * (0.25 + abs(ac) / bw)));
    fold = mix(fold, ac / bw, m);
    bows = max(bows, m);
  }
  tail = max(tail, bows) * pin * ribbon.a;
  bg = mix(bg, vec4(ribbon.rgb * (1.0 + 0.2 * bows * fold), 1.0), tail);

  vec4 col = getFromColor(clamp(k, 0.0, 1.0));
  float d1 = abs(k.x - k.y), d2 = abs(k.x + k.y - 1.0);
  float panel = sign(k.x - k.y) * 0.6 + sign(k.x + k.y - 1.0) * 0.4;
  float sh = 1.0 + shading * env * (0.13 * panel * cos(roll * 3.0 + tilt) - 0.4 * (1.0 - smoothstep(0.004, 0.01 + 0.002 / s, min(d1, d2))));
  float rim = min(min(k.x, 1.0 - k.x), min(k.y, 1.0 - k.y));
  // fabric billows between the spars and the taped hem
  float bulge = smoothstep(0.0, 0.18, min(min(d1, d2), rim));
  sh += shading * env * 0.1 * (bulge - 0.6);
  col.rgb *= sh;
  float hem = (1.0 - smoothstep(0.012, 0.018, rim)) * env;
  col.rgb = mix(col.rgb, ribbon.rgb * (0.85 + 0.15 * panel), 0.85 * hem * ribbon.a);
  vec4 o = mix(bg, vec4(col.rgb * col.a, col.a), cov);
  return o.a > 0.0 ? vec4(o.rgb / o.a, o.a) : vec4(0.0);
}
