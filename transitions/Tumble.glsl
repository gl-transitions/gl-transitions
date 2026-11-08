// Author: gre
// License: MIT
// Description: The outgoing image is thrown away like a rigid card, tumbling end over end with a slight spin as it flies off into the distance in perspective, its darker back showing on every flip and its soft shadow shrinking on the incoming image behind it
// Tags: 3d, rotate, flip, card, perspective

// @range(-4, 4) Number of turns end over end, negative to tumble the other way
uniform float flips; // = 2.0
// @range(-1, 1) Turns of the secondary spin around the line of sight
uniform float spin; // = 0.15
// @param Where the card flies toward on screen, in frame heights from the center
uniform vec2 direction; // = vec2(0.0, 0.3)
// @range(0.1, 1) Strength of the perspective
uniform float perspective; // = 0.6
// @range(0, 1) Shading of the card as it turns, darkness of its back and of its shadow
uniform float shading; // = 0.7

const float PI = 3.141592653589793;
// width of the anti-aliased card edges, in frame heights
const float EDGE = 0.0015;
// direction toward the light: above, to the right, in front
const vec3 LIGHT = vec3(0.348, 0.696, -0.628);

// rotates v around the line of sight
vec3 roll(vec3 v, float c, float s) {
  return vec3(c * v.x - s * v.y, s * v.x + c * v.y, v.z);
}

// signed distance to the card's rectangle, in its plane
float cardDistance(vec2 q) {
  vec2 e = abs(q) - vec2(0.5 * ratio, 0.5);
  return max(e.x, e.y);
}

// casts the ray d from the eye onto the card's plane, rel being the card's center from the eye:
// (the point hit in the card's axes, the distance along d), or a negative distance when it misses
vec3 castOnCard(vec3 d, vec3 rel, vec3 U, vec3 V, vec3 N) {
  float dn = dot(d, N);
  if (abs(dn) < 1e-6) return vec3(0.0, 0.0, -1.0);
  float k = dot(rel, N) / dn;
  vec3 h = k * d - rel;
  return vec3(dot(h, U), dot(h, V), k);
}

vec2 cardUv(vec2 q) {
  return clamp(vec2(q.x / ratio, q.y) + 0.5, 0.0, 1.0);
}

vec4 transition(vec2 uv) {
  // the card is gone a little before the end
  float t = clamp(progress / 0.95, 0.0, 1.0);
  // its size on screen shrinks faster and faster, down to a few percent
  float size = exp(-2.8 * t * t * (0.4 + 0.6 * t));
  float away = 1.0 - size;
  // it spins at its own pace, starting smoothly
  float turn = t * t * (3.0 - 2.0 * t);
  float a = 2.0 * PI * flips * turn;
  float r = 2.0 * PI * spin * turn;
  float cr = cos(r), sr = sin(r);
  // end over end around its horizontal axis, then around the line of sight
  vec3 U = roll(vec3(1.0, 0.0, 0.0), cr, sr);
  vec3 V = roll(vec3(0.0, cos(a), sin(a)), cr, sr);
  vec3 N = roll(vec3(0.0, -sin(a), cos(a)), cr, sr);

  // the camera, at dist in front of the plane z = 0, sees the frame at rest on it
  float dist = 1.0 / clamp(perspective, 0.1, 1.0);
  // the card's center, seen at direction * away on screen while it goes away, with a slight rise
  vec2 seen = direction * away + vec2(0.0, 0.12 * t * (1.0 - t));
  vec3 rel = vec3(seen / size, dist / size);
  float fade = 1.0 - smoothstep(0.8, 1.0, t);
  float shadowAmount = 0.6 * shading * sqrt(size) * fade;

  vec2 p = vec2((uv.x - 0.5) * ratio, uv.y - 0.5);
  vec4 color = getToColor(uv);

  // the soft shadow on the incoming image, cast down and to the left, shrinking with the card
  if (shadowAmount > 0.0) {
    vec3 ds = vec3(p - vec2(-0.05, -0.08) * min(4.0 * t, 1.0) * size, dist);
    vec3 hs = castOnCard(ds, rel, U, V, N);
    if (hs.z > 0.0) {
      float blur = 0.005 + 0.06 * min(3.0 * t, 1.0) * size;
      float sd = cardDistance(hs.xy) * max(abs(dot(ds, N)) / length(ds), 0.05) / hs.z;
      float sh = (1.0 - smoothstep(-blur, blur, sd)) * getFromColor(cardUv(hs.xy)).a;
      color.rgb *= 1.0 - shadowAmount * sh;
    }
  }

  // cast the ray onto the card
  vec3 d = vec3(p, dist);
  vec3 hit = castOnCard(d, rel, U, V, N);
  if (hit.z <= 0.0) return color;
  float dn = dot(d, N);
  // anti-aliased edges: a screen pixel covers more of the card when it is far or seen at a grazing angle
  float grazing = max(abs(dn) / length(d), 0.05);
  float e = EDGE * min(20.0 * t, 1.0) * hit.z / grazing;
  float m = clamp(0.5 - cardDistance(hit.xy) / max(e, 1e-6), 0.0, 1.0) * fade;
  if (m <= 0.0) return color;

  vec4 card = getFromColor(cardUv(hit.xy));
  // the side facing the camera: the front, or the back which shows the image through, darker and duller
  bool front = dn > 0.0;
  vec3 facing = front ? -N : N;
  float lit = min((0.35 + 0.65 * max(dot(facing, LIGHT), 0.0)) / (0.35 + 0.65 * -LIGHT.z), 1.0);
  float shade = mix(1.0, lit * (front ? 1.0 : 0.55), shading);
  if (!front) card.rgb = mix(card.rgb, vec3(dot(card.rgb, vec3(0.299, 0.587, 0.114))), 0.4 * shading);
  // a glint as the card turns through the light, a light added to the image
  float glint = pow(max(dot(facing, normalize(LIGHT - normalize(d))), 0.0), 60.0);
  card.rgb = card.rgb * shade + 0.35 * shading * glint * smoothstep(0.0, 0.2, t);
  if (m >= 1.0) return card;
  // blend premultiplied, so that a transparent layer gives no color to the other one
  vec4 mixed = mix(vec4(color.rgb * color.a, color.a), vec4(card.rgb * card.a, card.a), m);
  return mixed.a > 0.0 ? vec4(mixed.rgb / mixed.a, mixed.a) : vec4(0.0);
}
