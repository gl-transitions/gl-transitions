// Author: gre
// License: MIT
// Description: Forked lightning bolts crack down from the top of the frame, the screen flashes white in a few stuttering strobes, and the incoming image appears lit by the last flickers as they fade out
// Tags: light, flash, weather, strobe

// @range(1, 3, 1) Number of bolts: the main one strikes the ground, the others fork out higher in the sky
uniform int bolts; // = 2
// @range(0, 1) Where the main bolt strikes, from the left (0) to the right (1) of the frame
uniform float strike; // = 0.55
// @range(0, 100, 1) Changes the shape of the bolts
uniform float seed; // = 0.0
// @color Color of the light, added to the images
uniform vec3 color; // = vec3(0.75, 0.85, 1.0)
// @range(0, 1) Size and brightness of the glow around the bolts
uniform float glow; // = 0.5
// @range(1, 4, 1) Number of strobes; the images switch during the brightest one
uniform int flashes; // = 3

// the bolts crack down until this time, then the strobes start
const float LEADER = 0.3;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

// a value noise that is linear between its cells: a jagged polyline, centered on 0
float jag(float s, float k) {
  float i = floor(s);
  return mix(hash(vec2(i, k)), hash(vec2(i + 1.0, k)), fract(s)) - 0.5;
}

// the zigzag of a bolt around its straight line, at height y (narrower in a portrait frame)
float zigzag(float y, float k) {
  return min(ratio, 1.0) * (0.15 * jag(y * 5.0, k) + 0.06 * jag(y * 13.0, k + 1.0) + 0.03 * jag(y * 31.0, k + 2.0) + 0.012 * jag(y * 67.0, k + 3.0));
}

// the x of a bolt at height y: from x0 at the top (y = 1) to x1 at its end (y = y1),
// given z0 and z1, its zigzag at both ends
float boltX(float y, float x0, float x1, float y1, float z0, float z1, float k) {
  float t = (1.0 - y) / (1.0 - y1);
  return mix(x0 - z0, x1 - z1, t) + zigzag(y, k);
}

// the x of a branch at height y: it leaves its bolt at (xb, yb), where its own zigzag is zb,
// and drifts sideways by dir per unit of height
float branchX(float y, float xb, float yb, float zb, float dir, float k) {
  return xb + dir * (yb - y) + 0.6 * (zigzag(y, k) - zb);
}

// distance to a curve x = f(y), knowing its x and its slope at the pixel's height,
// and how far above or below its ends the pixel is; the slope only corrects the distance
// close to the curve, so the glow farther away does not streak along the zigzags
float curveDist(vec2 q, float x, float slope, float outside) {
  float dx = abs(q.x - x);
  float d = dx * mix(inversesqrt(1.0 + slope * slope), 1.0, smoothstep(0.0, 0.08, dx));
  return length(vec2(d, max(outside, 0.0)));
}

// a strobe at time t0: a quick rise, a plateau of length hold, then a decay
float pulse(float p, float t0, float hold, float decay) {
  float x = p - t0;
  if (x < 0.0) return smoothstep(-0.012, 0.0, x);
  return exp(-max(x - hold, 0.0) / decay);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 q = vec2(uv.x * ratio, uv.y);
  // (seeds far apart, so that neighboring seeds share no hash keys)
  float k0 = floor(seed) * 61.0;
  int nb = bolts < 1 ? 1 : (bolts > 3 ? 3 : bolts);
  int nf = flashes < 1 ? 1 : (flashes > 4 ? 4 : flashes);
  // the images switch during the brightest strobe, the second one (or the only one)
  int cut = nf > 1 ? 1 : 0;

  // the strobes, a bit irregular; the bolts are lit by all of them, the screen mostly by the brightest
  float flash = 0.0;
  float lit = 0.0;
  float tCut = LEADER;
  float tLast = LEADER;
  float t = LEADER;
  for (int i = 0; i < 4; i++) {
    if (i < nf) {
      bool isCut = i == cut;
      float amp = isCut ? 1.0 : (i < cut ? 0.55 : 0.7 * pow(0.75, float(i - cut - 1)));
      float s = amp * pulse(p, t, isCut ? 0.025 : 0.004, isCut ? 0.03 : 0.022);
      flash = max(flash, s);
      lit = max(lit, pulse(p, t, 0.01, 0.045));
      if (isCut) tCut = t;
      tLast = t;
      t += (isCut ? 0.12 : 0.08) + 0.04 * hash(vec2(float(i), k0 + 5.0));
    }
  }
  // the stutter: the light jumps from one level to another a few times per strobe
  float stutter = mix(0.7, 1.0, hash(vec2(floor(p * 70.0), k0 + 9.0)));
  flash *= stutter;
  // the brightest strobe whites the screen out while the images switch
  float whiteout = pulse(p, tCut, 0.025, 0.02);
  // then a few last flickers, fading out
  float tail = p > tLast ? exp(-(p - tLast) / 0.1) * smoothstep(0.03, 0.06, p - tLast) : 0.0;
  flash = max(flash, 0.35 * tail * step(0.45, hash(vec2(floor(p * 40.0), k0 + 13.0))));

  // the bolts crack down in a few jumps while faintly lit, then light up with the strobes and go out
  float grow = clamp(p / LEADER, 0.0, 1.0);
  grow = (floor(grow * 7.0) + smoothstep(0.0, 1.0, fract(grow * 7.0))) / 7.0;
  float faint = 0.5 * mix(0.6, 1.0, hash(vec2(floor(p * 50.0), k0 + 11.0)));
  float boltLight = p < LEADER ? faint * smoothstep(0.0, 0.06, p) : max(lit * stutter, faint * exp(-(p - LEADER) / 0.12));
  boltLight = max(boltLight, 0.6 * flash * tail);
  boltLight *= 1.0 - smoothstep(tLast + 0.1, tLast + 0.3, p);

  // the bolts: the main one strikes the ground at strike, the others stop in the sky
  float core = 0.0;
  float halo = 0.0;
  float near = 10.0;
  bool lightsOn = boltLight > 0.0 || flash > 0.0;
  for (int b = 0; b < 3; b++) {
    if (b < nb && lightsOn) {
      float fb = float(b);
      float kb = k0 + fb * 17.0;
      float x1 = strike * ratio;
      float y1 = -0.05;
      float bright = 1.0;
      if (b > 0) {
        // the second bolt goes to the roomier side, the third to the other side if there is room there
        float roomy = strike < 0.5 ? 1.0 : -1.0;
        bool cramped = min(strike, 1.0 - strike) < 0.25;
        float side = b == 1 || cramped ? roomy : -roomy;
        float dist = b == 2 && cramped ? 0.5 : 0.22;
        x1 = clamp(x1 + side * ratio * (dist + 0.12 * hash(vec2(fb, kb))), 0.08 * ratio, 0.92 * ratio);
        y1 = 0.25 + 0.25 * hash(vec2(fb, kb + 1.0));
        bright = 0.7;
      }
      float x0 = clamp(x1 + (hash(vec2(fb, kb + 2.0)) - 0.5) * 0.5 * min(ratio, 1.0), 0.1 * ratio, 0.9 * ratio);
      // the tip of the bolt while it cracks down
      float tip = mix(1.02, y1, grow);
      // (the slope is measured over a few pixels, so it changes smoothly at the corners)
      float e = 0.01;
      float z0 = zigzag(1.0, kb);
      float z1 = zigzag(y1, kb);
      float x = boltX(q.y, x0, x1, y1, z0, z1, kb);
      float slope = (boltX(q.y + e, x0, x1, y1, z0, z1, kb) - boltX(q.y - e, x0, x1, y1, z0, z1, kb)) / (2.0 * e);
      float d = curveDist(q, x, slope, max(max(y1, tip) - q.y, q.y - 1.05));
      near = min(near, d);
      float w = 0.003 * mix(1.0, 0.7, fb / 2.0);
      core += bright * exp(-d * d / (w * w));
      halo += bright * (0.7 * exp(-d * 24.0) + 0.25 * exp(-d * 6.0));
      // three branches, leaving the bolt on either side and fading toward their ends
      for (int j = 0; j < 3; j++) {
        float fj = float(j);
        float kj = kb + 3.0 + fj * 5.0;
        float tb = 0.12 + 0.2 * fj + 0.15 * hash(vec2(fj, kj));
        float yb = mix(1.0, y1, tb);
        float len = (0.3 + 0.25 * hash(vec2(fj, kj + 1.0))) * (1.0 - tb) * (1.0 - y1);
        float dir = (j == 1 ? -1.0 : 1.0) * (0.2 + 0.45 * hash(vec2(fj, kj + 2.0))) * min(ratio, 1.0);
        float xb = boltX(yb, x0, x1, y1, z0, z1, kb);
        float zb = zigzag(yb, kj);
        float bx = branchX(q.y, xb, yb, zb, dir, kj);
        float bs = (branchX(q.y + e, xb, yb, zb, dir, kj) - branchX(q.y - e, xb, yb, zb, dir, kj)) / (2.0 * e);
        float bd = curveDist(q, bx, bs, max(max(yb - len, tip) - q.y, q.y - yb));
        near = min(near, bd);
        float along = clamp((yb - q.y) / len, 0.0, 1.0);
        float fade = bright * (1.0 - 0.8 * along);
        float bw = w * mix(0.8, 0.4, along);
        core += fade * exp(-bd * bd / (bw * bw));
        halo += fade * 0.6 * (0.7 * exp(-bd * 24.0) + 0.25 * exp(-bd * 6.0));
      }
    }
  }

  // the outgoing image gives way to the incoming one at the brightest strobe, hidden by it
  float m = smoothstep(tCut, tCut + 0.025, p);
  vec4 c = vec4(0.0);
  if (m < 1.0) {
    vec4 a = getFromColor(uv);
    c += (1.0 - m) * vec4(a.rgb * a.a, a.a);
  }
  if (m > 0.0) {
    vec4 a = getToColor(uv);
    c += m * vec4(a.rgb * a.a, a.a);
  }
  if (c.a <= 0.0) return vec4(0.0);
  vec3 col = c.rgb / c.a;

  // the effect fades in at the start and is gone at the end
  float live = smoothstep(0.0, 0.03, p) * (1.0 - smoothstep(0.85, 1.0, p));
  // the sky darkens a little as the storm builds, then the strobes overexpose the image,
  // more around the bolts, and the bolts glow over it
  float dim = 0.4 * smoothstep(0.0, LEADER, p) * (1.0 - smoothstep(tCut, tLast + 0.15, p));
  float f = flash * mix(0.6 + 0.4 * exp(-near * 4.0), 1.0, smoothstep(0.6, 1.0, flash));
  col *= 1.0 - dim * live;
  col = col * (1.0 + 2.5 * f * live) + color * (1.1 * f * live);
  float g = 0.4 + 1.2 * glow;
  vec3 light = mix(color, vec3(1.0), 0.75) * min(core, 1.5) * 1.6 + color * g * halo;
  col += light * boltLight * live;
  col = mix(col, vec3(1.0), 0.92 * whiteout * live);
  return vec4(clamp(col, 0.0, 1.0), c.a);
}
