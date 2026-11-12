// Author: gre
// License: MIT
// Description: A thin sheet of water runs up over the outgoing image like the last of a wave on a beach, its lobed front edged with bubbly foam; it slows, stops just past the far edge and drains back, leaving the incoming image wet and glossy, with a lace of foam that thins out as it dries
// Tags: water, foam, beach, liquid, directional, reveal

// @param Direction the water runs up toward
uniform vec2 direction; // = vec2(0.0, 1.0)
// @range(0, 1) Amount of foam on the front and left behind
uniform float foam; // = 0.7
// @range(0, 0.05) How much the sheet of water bends the image under it
uniform float refraction; // = 0.02
// @color Color of the water (its alpha is its strength)
uniform vec4 water; // = vec4(0.1, 0.6, 0.62, 0.4)

// half width of the antialiased edges, in frame heights
const float AA = 0.002;
// how far the lobes of the front lead or trail, in frame heights
const float LOBE = 0.06;
// width of the band of foam lace behind the front, in frame heights
const float LACE = 0.3;
// size of the foam bubbles, in frame heights
const float CELL = 0.045;
// part of the transition the water runs up during; it drains back during the rest
const float RUNUP = 0.4;
// width of the dense band of foam right behind the front, in frame heights
const float FOAMW = 0.1;

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
    mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x),
    f.y
  );
}

// foam: bubbles packed side by side, white where they touch and open at their centers.
// Sparse foam is a faint lace; the denser it is, the brighter it is and the smaller the
// holes, until they close (density 1)
float bubbles(vec2 p, float density) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float d1 = 8.0;
  float d2 = 8.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 o = vec2(float(x), float(y));
      vec2 c = o + 0.15 + 0.7 * hash22(i + o) - f;
      float d = dot(c, c);
      if (d < d1) {
        d2 = d1;
        d1 = d;
      } else if (d < d2) {
        d2 = d;
      }
    }
  }
  float e = sqrt(d2) - sqrt(d1);
  float w = 0.12 + 0.6 * density;
  return (1.0 - smoothstep(w - 0.12, w + 0.12, e)) * smoothstep(0.0, 0.35, density);
}

vec2 mirror(vec2 v) {
  return 1.0 - abs(1.0 - mod(v, 2.0));
}

vec4 transition(vec2 uv) {
  vec2 dir = length(direction) > 0.0 ? normalize(direction) : vec2(0.0, 1.0);
  vec2 q = (uv - 0.5) * vec2(ratio, 1.0);
  // distance along the run-up, 0 at the middle of the frame, and across it
  float a = dot(q, dir);
  float b = dot(q, vec2(-dir.y, dir.x));
  // half the extent of the frame along the run-up
  float extent = 0.5 * (abs(dir.x) * ratio + abs(dir.y));
  float start = -extent - LOBE - 0.1;
  float stop = extent + LOBE + 0.01;

  // the front races in, slows down and stops (run-up), then drains back faster and faster
  float up = clamp(progress / RUNUP, 0.0, 1.0);
  float back = clamp((progress - RUNUP) / (1.0 - RUNUP), 0.0, 1.0);
  float front = mix(start, stop, 1.0 - pow(1.0 - up, 1.6)) - (stop - start) * pow(back, 1.5);

  // lobed front: tongues of water run ahead in some places, and drift sideways a little
  float lobes = vnoise(vec2(b * 7.0 + 3.1, progress * 2.0)) * 0.7 + vnoise(vec2(b * 17.0, 5.0 + progress * 3.0)) * 0.3;
  float behind = front + LOBE * (lobes - 0.5) * 2.0 - a; // > 0 under the water
  float sheet = smoothstep(-AA, AA, behind);

  // the image swaps under the dense foam right behind the running front, and finishes
  // swapping under the water as it stops by the far edge
  float swapped = max(smoothstep(0.01, 0.8 * FOAMW, behind), (progress < RUNUP ? sheet : 1.0) * smoothstep(RUNUP - 0.08, RUNUP, progress));

  // the sheet of water ripples (stretched across the flow) and bends what is under it
  vec2 rp = vec2(a * 20.0, b * 5.0 + 3.0 * vnoise(q * 4.0)) - vec2(7.0 * min(progress, RUNUP) - 5.0 * back, 0.0);
  float n0 = vnoise(rp);
  vec2 g = (vnoise(rp + vec2(0.15, 0.0)) - n0) / 0.15 * dir + (vnoise(rp + vec2(0.0, 0.15)) - n0) / 0.15 * vec2(-dir.y, dir.x);
  // the water is thin at its edge and deeper behind it
  float thick = sheet * smoothstep(0.0, 0.12, behind);
  vec2 off = g * refraction * thick * vec2(1.0 / ratio, 1.0);

  vec4 c = mix(getFromColor(mirror(uv + off)), getToColor(mirror(uv + off)), swapped);
  c.rgb = mix(c.rgb, water.rgb, water.a * sheet * (0.3 + 0.7 * smoothstep(0.0, 0.35, behind)));
  // soft glints on the ripples
  float glint = pow(max(dot(normalize(vec3(-g, 3.0)), normalize(vec3(-0.3, 0.6, 1.0))), 0.0), 14.0);
  c.rgb += glint * 0.4 * thick;

  // wet: what the water has drained off is darker and glossier, and dries out
  float wet = (1.0 - sheet) * exp(min(behind, 0.0) * 2.5) * smoothstep(RUNUP, RUNUP + 0.05, progress) * (1.0 - smoothstep(0.7, 1.0, progress));
  c.rgb *= mix(vec3(1.0), c.rgb, 0.55 * wet);
  c.rgb += 0.1 * wet * smoothstep(0.4, 0.9, vnoise(vec2(a * 30.0, b * 6.0)));

  // foam: thick and bubbly right behind the running front, a lace trailing behind it,
  // a thin line on the draining front, and lace stranded on the wet image that thins out
  // the foam drifts with the water as it runs up, then stays where it is
  vec2 lp = vec2(a - 0.4 * (progress < RUNUP ? front : stop), b) / CELL;
  // the lace gathers in streaks along the front, broken into patches
  float patches = smoothstep(0.45, 0.8, 0.6 * vnoise(lp * vec2(0.4, 0.1) + 4.0) + 0.4 * vnoise(lp * 0.3 + 9.0));
  float bandW = FOAMW * (0.5 + vnoise(vec2(b * 25.0, 2.0)));
  float density = (1.0 - smoothstep(0.0, bandW, behind)) * (1.0 - smoothstep(RUNUP - 0.05, RUNUP + 0.12, progress));
  density = max(density, 0.55 * patches * (1.0 - smoothstep(0.0, LACE, behind)) * (1.0 - 0.5 * back));
  density = max(density, 0.9 * (1.0 - smoothstep(0.0, 0.012 + 0.02 * vnoise(vec2(b * 40.0, 1.0)), behind)));
  density = mix(0.5 * patches * wet, density, sheet);
  // bubbles of two sizes, over a milky haze where the foam is dense
  float f = 0.0;
  if (density > 0.0) {
    f = max(bubbles(lp, density), 0.85 * bubbles(lp * 1.7 + 7.0, density * 0.9));
    f = max(f, 0.45 * smoothstep(0.15, 0.7, density)) * foam;
  }
  // the foam shades the water around it a little
  c.rgb *= 1.0 - 0.25 * sheet * foam * (1.0 - f) * smoothstep(0.0, 0.6, density);
  c.rgb = mix(c.rgb, vec3(0.97, 0.98, 0.97), clamp(f, 0.0, 1.0));
  // a thin shadow just ahead of the running front
  float sh = smoothstep(-0.03, 0.0, behind);
  c.rgb *= 1.0 - 0.35 * (1.0 - sheet) * sh * sh * (1.0 - smoothstep(RUNUP - 0.05, RUNUP, progress));
  return c;
}
