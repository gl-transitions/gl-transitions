// Author: gre
// License: MIT
// Description: The incoming image settles onto the outgoing one like a spun coin coming to rest: it starts standing on its edge, then leans over while its lifted side whirls around faster and faster with a sweeping shadow, rocking on its corners in a quickening rattle, until it drops flat and still over the frame
// Tags: 3d, spin, wobble, shadow

// @range(1, 6) Number of whirls of the lifted side
uniform float whirls; // = 4.5
// @range(0, 1.5) In-plane turn of the image when it stands up, undone as it settles
uniform float twist; // = 0.6
// @range(0, 1) Shading of the coin and darkness of its shadow
uniform float shading; // = 0.7

const float PI = 3.141592653589793;
// far camera and a smaller standing card keep the raised edge from looming over the frame
const float D = 6.0;
const float START_SCALE = 0.72;
const float AA = 0.0015;

vec3 rotAxis(vec3 v, vec3 a, float t) {
  return v * cos(t) + cross(a, v) * sin(t) + a * dot(a, v) * (1.0 - cos(t));
}

float nonZero(float x) {
  return x < 0.0 ? min(x, -1e-5) : max(x, 1e-5);
}

vec4 transition(vec2 uv) {
  float s = 1.0 - progress;
  float tilt = 0.5 * PI * pow(s, 1.2);
  // whirl rate grows like 1/sqrt(s + K), capped so the last frames do not strobe
  const float K = 0.04;
  float phi = 2.0 * PI * whirls * (sqrt(1.0 + K) - sqrt(s + K)) / (sqrt(1.0 + K) - sqrt(K)) - 0.4;
  float psi = twist * s * s;

  vec3 axis = vec3(-sin(phi), cos(phi), 0.0);
  vec3 e1 = rotAxis(vec3(cos(psi), sin(psi), 0.0), axis, tilt);
  vec3 e2 = rotAxis(vec3(-sin(psi), cos(psi), 0.0), axis, tilt);
  vec3 n = cross(e1, e2);
  float sc = mix(1.0, START_SCALE, 1.0 - cos(tilt));
  vec2 hs = vec2(0.5 * ratio, 0.5) * sc;
  // the lowest corner touches the table, so the center rides up and down as it rocks over the corners
  float h = abs(hs.x * e1.z) + abs(hs.y * e2.z);
  vec3 C = vec3(0.0, 0.0, -h);

  vec2 p = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  vec3 d = vec3(p, D);
  float dn = nonZero(dot(d, n));
  float t = (D - h) * n.z / dn;
  vec3 g = vec3(0.0, 0.0, -D) + d * t - C;
  vec2 q = vec2(dot(g, e1), dot(g, e2));
  vec2 eq = abs(q) - hs;
  // edge distance in screen units through the projection's analytic Jacobian, crisp even edge-on
  vec2 g1 = t * (e1.xy - dot(d, e1) / dn * n.xy);
  vec2 g2 = t * (e2.xy - dot(d, e2) / dn * n.xy);
  vec2 ex = eq / clamp(vec2(length(g1), length(g2)), 1e-3, 40.0);
  float m = 1.0 - smoothstep(0.0, AA, max(ex.x, ex.y));
  m *= smoothstep(0.001, 0.02, abs(n.z));

  vec3 L = normalize(vec3(-0.4, 0.5, -1.0));
  vec3 P = vec3(p, 0.0);
  float ln = dot(L, n);
  float ts = dot(C - P, n) / nonZero(ln);
  vec3 gs = P + L * ts - C;
  vec2 es = abs(vec2(dot(gs, e1), dot(gs, e2))) - hs;
  float soft = 0.01 + 0.15 * clamp(ts, 0.0, 2.0);
  float shadow = (1.0 - smoothstep(-soft, soft, max(es.x, es.y))) * smoothstep(0.0, 0.15, h) * smoothstep(0.0, 0.06, progress) * smoothstep(0.0, 0.02, ts);
  // a card edge-on to the light casts a hairline that would alias
  shadow *= smoothstep(0.03, 0.15, abs(ln));

  vec4 bg = getFromColor(uv);
  bg.rgb *= 1.0 - 0.6 * shading * shadow;

  vec4 img = getToColor(clamp(vec2(q.x / ratio, q.y) / sc + 0.5, 0.0, 1.0));
  float lit = L.z - dot(n, L);
  float spec = pow(max(-dot(n, normalize(L + vec3(0.0, 0.0, -1.0))), 0.0), 30.0) * sin(tilt);
  vec2 rim = 1.0 - smoothstep(0.0, 0.025 * hs.y, -eq);
  img.rgb = img.rgb * (1.0 + shading * max(1.2 * lit, -0.45)) + shading * (0.3 * spec + 0.25 * sin(tilt) * max(rim.x, rim.y));
  return mix(bg, img, m);
}
