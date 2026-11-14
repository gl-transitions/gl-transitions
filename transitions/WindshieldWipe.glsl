// Author: gre
// License: MIT
// Description: Raindrops gather on the glass and a wiper blade pivoting from below the frame sweeps across it, pushing a bead of water ahead of its rubber edge and leaving the incoming image behind it, streaked with a thin film that quickly clears
// Tags: wipe, radial, wiper, rain, water, glass

// @range(0, 1) Where the wiper pivots along the bottom edge: 0 the left corner, 0.5 the middle, 1 the right corner
uniform float pivot; // = 0.5
// @param Sweep from right to left instead of left to right
uniform bool reverse; // = false
// @range(0, 1) Amount of water: the raindrops, the bead pushed ahead of the blade and the film left behind it
uniform float wetness; // = 0.6
// @color Color of the wiper blade and arm
uniform vec4 wiperColor; // = vec4(0.07, 0.07, 0.08, 1.0)

// distance of the pivot outside the frame, in frame heights
const float OUT = 0.06;
// blade cross-section, across the blade (negative ahead of it), in frame heights
const float RUBBER = 0.004;
const float SPINE = 0.016;
const float ARM0 = 0.006;
const float ARM1 = 0.021;
// width of the bead of water ahead of the rubber, and how far behind the film reaches
const float BEAD = 0.014;
const float FILM = 0.22;
// offset of the blade's shadow on the glass (light from the top left)
const vec2 SHADOW = vec2(0.016, -0.022);
const float AA = 0.0012;
// size of the cells holding the raindrops, in frame heights
const float DROP = 0.05;
// how far the wiper clears the frame at rest, shadow included, in frame heights
const float CLEAR = 0.075;
// how long the wiper takes to leave and reach its rests, as a share of the sweep
const float PARK = 0.04;

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

float hash12(vec2 v) {
  vec3 v3 = fract(vec3(v.xyx) * 0.1031);
  v3 += dot(v3, v3.yzx + 33.33);
  return fract((v3.x + v3.y) * v3.z);
}

float hash11(float x) {
  vec2 v = fract(vec2(x) * vec2(0.1031, 0.1030));
  v += dot(v, v.yx + 33.33);
  return fract((v.x + v.y) * v.y);
}

// raindrops on the glass, at most one per cell: the offset each one bends the image by (xy),
// its coverage (z) and its shading inside it (w)
vec4 drops(vec2 v, float grow) {
  vec2 g = v / DROP;
  vec2 id = floor(g);
  if (hash12(id) >= 0.55) return vec4(0.0);
  // placed by its full size, so it grows in place
  float r1 = 0.12 + 0.2 * hash12(id + 3.7);
  vec2 c = id + 0.5 + (0.45 - r1) * (vec2(hash12(id + 1.3), hash12(id + 8.1)) * 2.0 - 1.0);
  float r = r1 * grow;
  float px = AA / DROP;
  // antialiased edge, faded while the drop is smaller than a pixel so it appears from nothing
  float m = (1.0 - smoothstep(r - px, r + px, length(g - c))) * min(r / px, 1.0);
  vec2 d = (g - c) / max(r, px);
  float l = length(d);
  // a drop is a small lens: it shows the image around it, flipped and shrunk
  vec2 off = -d * r * DROP * 1.6 * m;
  // dark along its rim, brighter at the bottom right where it focuses the light, with a glint at the top left
  float shade = -0.35 * smoothstep(0.55, 1.0, l) + 0.25 * dot(d, vec2(0.5, -0.6)) + 0.8 * (1.0 - smoothstep(0.0, 0.22, length(d - vec2(-0.35, 0.4))));
  return vec4(off, m, shade);
}

// angle of the wiper when it clears a corner of the frame by its width, on one side (sgn) of it
float restAngle(vec2 c, float sgn) {
  return atan(c.y, c.x) + sgn * asin(min(CLEAR / length(c), 1.0));
}

// signed distance to a box in the blade's frame (along, across)
float box(vec2 q, vec2 lo, vec2 hi) {
  vec2 c = 0.5 * (lo + hi);
  vec2 e = 0.5 * (hi - lo);
  vec2 d = abs(q - c) - e;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

vec4 transition(vec2 uv) {
  // the geometry is mirrored for a right to left sweep; the images are not
  float sx = reverse ? -1.0 : 1.0;
  vec2 g = reverse ? vec2(1.0 - uv.x, uv.y) : uv;
  float px = reverse ? 1.0 - pivot : pivot;
  // the pivot sits just outside the frame, below its bottom edge (and beside it at a corner)
  vec2 piv = vec2(px * ratio + OUT * (2.0 * px - 1.0), -OUT);
  vec2 P = g * vec2(ratio, 1.0) - piv;

  // the blade points at a target running along the far edges of the frame (left, top, right);
  // each edge takes a share of the sweep by the area of the triangle it makes with the pivot,
  // so the frame is uncovered at an even pace for any pivot
  float W1 = max(piv.x, 0.0);
  float W2 = ratio * (1.0 - piv.y);
  float W3 = max(ratio - piv.x, 0.0);
  // the wiper accelerates out of its rest and slows into the other one
  float e = mix(progress, progress * progress * (3.0 - 2.0 * progress), 0.35);
  float s = mix(-PARK, 1.0 + PARK, e) * (W1 + W2 + W3);
  vec2 T = s < W1 ? vec2(0.0, s / max(W1, 1e-6)) : s < W1 + W2 ? vec2((s - W1) / W2 * ratio, 1.0) : vec2(ratio, 1.0 - (s - W1 - W2) / max(W3, 1e-6));
  vec2 D = T - piv;
  float th = atan(D.y, D.x);
  // at rest, the wiper is turned past the frame's corners until it clears them by its width
  vec2 c0 = -piv;
  vec2 c1 = vec2(ratio, 0.0) - piv;
  vec2 c2 = vec2(0.0, 1.0) - piv;
  vec2 c3 = vec2(ratio, 1.0) - piv;
  if (s < 0.0) {
    float a0 = max(atan(c0.y, c0.x), atan(c2.y, c2.x));
    float aS = max(restAngle(c0, 1.0), restAngle(c2, 1.0));
    th = mix(a0, aS, -s / (PARK * (W1 + W2 + W3)));
  } else if (s > W1 + W2 + W3) {
    float a1 = min(atan(c1.y, c1.x), atan(c3.y, c3.x));
    float aE = min(restAngle(c1, -1.0), restAngle(c3, -1.0));
    th = mix(a1, aE, (s - W1 - W2 - W3) / (PARK * (W1 + W2 + W3)));
  }
  float reach = max(length(c2), length(c3)) + 0.03;
  vec2 dir = vec2(cos(th), sin(th));
  vec2 nrm = vec2(-sin(th), cos(th));
  // along the blade, and across it: positive behind it (wiped), negative ahead
  vec2 q = vec2(dot(P, dir), dot(P, nrm));
  // the frame lies above the pivot, between 0 and PI around it: wiped where the blade has passed
  // arc distance behind the blade, along the circle around the pivot
  float behind = length(P) * (atan(P.y, P.x) - th);
  float wiped = smoothstep(-AA, AA, behind);

  // water fades in as the blade enters and out as it leaves, so both ends are untouched
  float wet = wetness * smoothstep(0.0, 0.08, progress) * (1.0 - smoothstep(0.85, 1.0, progress));

  // bead of water ahead of the rubber edge: it magnifies the outgoing image toward the blade
  float x = clamp((-q.y - RUBBER) / BEAD, 0.0, 1.0);
  float front = step(0.0, q.x) * step(q.y, -RUBBER);
  float bead = wet * (1.0 - x) * (1.0 - x) * front;
  vec2 offA = nrm * 0.012 * bead;
  // film behind the blade: thin arcs around the pivot that bend the incoming image slightly
  float b = max(behind - SPINE, 0.0);
  float film = wet * exp(-b / (0.35 * FILM)) * (1.0 - smoothstep(0.0, FILM, b));
  float rr = length(P) * 60.0;
  float arc = smoothstep(0.0, 0.5, fract(rr)) * (1.0 - smoothstep(0.5, 1.0, fract(rr)));
  float strength = hash11(floor(rr) + 7.0);
  float streak = film * arc * strength;
  vec2 offB = normalize(P + vec2(0.0, 1e-4)) * 0.004 * film * (strength - 0.5);

  // raindrops gather on the glass as the wiper starts, and merge into the bead as it reaches them;
  // the outgoing image is only needed where the blade has not passed yet
  vec4 A = vec4(0.0);
  if (wiped < 1.0) {
    vec4 rain = drops(uv * vec2(ratio, 1.0), smoothstep(0.0, 0.15, progress));
    float keep = 1.0 - smoothstep(0.0, 1.0, (1.0 - x) * front);
    A = getFromColor(mirror(uv + (vec2(sx, 1.0) * offA + rain.xy * keep * wetness) / vec2(ratio, 1.0)));
    A.rgb = mix(A.rgb, A.rgb * (1.0 + rain.w) + 0.25 * max(rain.w, 0.0), rain.z * keep * wetness);
    // the bead catches a highlight along its crest and darkens toward its edge
    A.rgb *= 1.0 - 0.3 * wet * smoothstep(0.55, 0.95, x) * (1.0 - smoothstep(0.95, 1.0, x)) * front;
    A.rgb += 0.45 * bead * (1.0 - smoothstep(0.0, 0.1, abs(x - 0.3)));
  }
  vec4 B = getToColor(mirror(uv + vec2(sx, 1.0) * offB / vec2(ratio, 1.0)));

  B.rgb += 0.08 * streak;
  B.rgb *= 1.0 - 0.06 * film;

  vec4 c = mix(vec4(A.rgb * A.a, A.a), vec4(B.rgb * B.a, B.a), wiped);

  // light comes from the top left: its direction across the blade, in the blade's frame
  vec3 light = normalize(vec3(-0.6 * sx, 0.8, 0.8));
  float lc = dot(light.xy, nrm);
  float armLen = 0.55 * reach;

  // shadow of the wiper on the glass
  vec2 sP = P - vec2(sx, 1.0) * SHADOW;
  vec2 sq = vec2(dot(sP, dir), dot(sP, nrm));
  float sd = min(box(sq, vec2(0.02, -RUBBER), vec2(reach, SPINE)), box(sq, vec2(0.02, ARM0), vec2(armLen, ARM1)));
  c.rgb *= 1.0 - 0.5 * (1.0 - smoothstep(-0.006, 0.016, sd));

  // the wiper itself: rubber edge, the blade's spine, and the arm on top of it toward the pivot
  float rubber = 1.0 - smoothstep(-AA, AA, box(q, vec2(0.02, -RUBBER), vec2(reach, 0.0)));
  float spine = 1.0 - smoothstep(-AA, AA, box(q, vec2(0.02, 0.0), vec2(reach, SPINE)) + 0.001);
  float arm = 1.0 - smoothstep(-AA, AA, box(q, vec2(0.0, ARM0), vec2(armLen, ARM1)));
  float clip = 1.0 - smoothstep(-AA, AA, box(q, vec2(armLen - 0.04, ARM0 - 0.004), vec2(armLen + 0.01, ARM1 + 0.003)) - 0.003);
  float top = max(arm, clip);
  float body = max(max(rubber, spine), top);
  // each part is shaded as a rounded bar lit from the top left, with a sharp highlight
  float n = clamp(2.0 * q.y / SPINE - 1.0, -1.0, 1.0);
  float ns = n * lc + sqrt(max(1.0 - n * n, 0.0)) * light.z;
  vec3 col = wiperColor.rgb * (0.55 + 0.9 * max(ns, 0.0)) + 0.5 * pow(max(ns, 0.0), 16.0);
  // the rubber is matte and darker, wet along its lip
  vec3 rubberCol = wiperColor.rgb * 0.55 + 0.12 * wet * (1.0 - smoothstep(0.0, 0.0015, q.y + RUBBER));
  col = mix(col, rubberCol, rubber * (1.0 - spine));
  float na = clamp(2.0 * (q.y - ARM0) / (ARM1 - ARM0) - 1.0, -1.0, 1.0);
  float nsa = na * lc + sqrt(max(1.0 - na * na, 0.0)) * light.z;
  vec3 armCol = wiperColor.rgb * (0.65 + 1.0 * max(nsa, 0.0)) + 0.6 * pow(max(nsa, 0.0), 24.0);
  armCol *= 1.0 - 0.25 * clip * (1.0 - arm);
  col = mix(col, armCol, top);
  c = body * vec4(col * wiperColor.a, wiperColor.a) + c * (1.0 - body * wiperColor.a);

  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
