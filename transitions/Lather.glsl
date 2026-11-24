// Author: gre
// License: MIT
// Description: A rich lather foams up over the outgoing picture: soap bubbles of every size swell in patches, crowd against each other into a thick froth with glinting, faintly iridescent films, then pop one by one, each with a quick ring, as the froth melts off the incoming picture
// Tags: foam, bubbles, soap, material, dissolve

// @range(0.5, 2) Size of the bubbles
uniform float bubbleSize; // = 1.0
// @range(0, 1) How much the bubbles bend the picture behind them
uniform float refraction; // = 0.5
// @color Color of the froth, its alpha sets how opaque it gets
uniform vec4 foam; // = vec4(0.96, 0.97, 1.0, 0.95)

vec2 hash22(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
  vec2 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash22(i).x, hash22(i + vec2(1.0, 0.0)).x, f.x),
             mix(hash22(i + vec2(0.0, 1.0)).x, hash22(i + 1.0).x, f.x), f.y);
}

vec2 cellOf(int j) {
  float fj = float(j);
  return vec2(mod(fj, 3.0) - 1.0, floor((fj + 0.5) / 3.0) - 1.0);
}

vec4 transition(vec2 uv) {
  float p = progress;
  vec2 asp = vec2(ratio, 1.0);
  // the foam keeps rising, slowly, while it covers the frame
  vec2 q = (uv - 0.5) * asp * (1.06 - 0.12 * p) - vec2(0.0, 0.12 * p);
  float size = max(bubbleSize, 0.1);

  // the bubble seen at q: offset from its center, radius, distance to its nearest film and to its round edge
  vec2 off = vec2(0.0);
  float rad = 0.0, inside = 0.0, outer = 0.0, seed = 0.0, ring = 0.0;
  float S = 0.15 * size;
  for (int l = 0; l < 3; l++) {
    float fl = float(l);
    // each layer turned its own way, so that no grid shows
    float an = 0.5 + 0.7 * fl;
    mat2 tr = mat2(cos(an), sin(an), -sin(an), cos(an));
    vec2 g = tr * q / S + 7.3 * fl;
    vec2 gi = floor(g);
    float pow1 = 1.0, pow2 = 1.0, r1 = 0.0, s1 = 0.0, pops = 0.0;
    vec2 c1 = vec2(0.0), c2 = vec2(9.0);
    for (int j = 0; j < 9; j++) {
      vec2 cell = gi + cellOf(j);
      vec2 h = hash22(cell + 31.0 * fl);
      vec2 h2 = hash22(cell + 91.7 + 31.0 * fl);
      vec2 c = cell + 0.5 + 0.82 * (h - 0.5);
      vec2 h3 = hash22(cell + 47.3 + 31.0 * fl);
      // every bubble is full grown by 0.6
      float born = p > 0.6 ? 0.0 : 0.02 + 0.25 * vnoise((((c - 7.3 * fl) * S) * tr + 3.1) * 2.6) + 0.07 * h2.x + 0.04 * fl;
      float k = clamp((p - 0.48 - 0.44 * h2.y) / 0.035, 0.0, 1.0);
      // the big ones fill the frame, the small ones are scattered over them
      float full = l == 0 ? 0.72 + 0.24 * h3.x : (0.25 + 0.3 * h3.x) * step(0.4, h3.y);
      float r = full * smoothstep(born, born + 0.16, p) * (1.0 + 0.03 * k);
      vec2 d = g - c;
      float dl = length(d);
      // a popped film flies off as a fading ring
      pops = max(pops, (1.0 - smoothstep(0.0, 0.003, abs(dl - r * (1.0 + 0.08 * k)) * S)) * k * (1.0 - k) * 4.0 * step(0.02, r));
      // power distance: crowded bubbles meet along flat films
      float pw = k > 0.0 || r < 0.02 ? 1.0 : dl * dl - r * r;
      if (pw < pow1) {
        pow2 = pow1; c2 = c1;
        pow1 = pw; c1 = d; r1 = r; s1 = h3.y + h.x;
      } else if (pw < pow2) {
        pow2 = pw; c2 = d;
      }
    }
    // live bubbles stand in front of the rings
    ring = pow1 < 0.0 ? 0.35 * pops : max(ring, pops);
    if (pow1 < 0.0) {
      float wall = pow2 < 1.0 ? 0.5 * (pow2 - pow1) / max(length(c1 - c2), 1e-3) : 9.0;
      off = (c1 / r1) * tr;
      rad = r1 * S;
      outer = (r1 - length(c1)) * S;
      inside = min(outer, wall * S);
      seed = s1;
    }
    S *= 0.55;
  }

  float pn = vnoise((q + 3.1) * 2.6);
  float thick = smoothstep(0.0, 0.2, p - 0.1 - 0.12 * pn) * (1.0 - smoothstep(0.0, 0.2, p - 0.49 - 0.2 * vnoise(q * 4.3 + 11.0)));
  vec2 fg = q / (0.011 * size);
  vec2 fi = floor(fg);
  float micro = 9.0;
  for (int j = 0; j < 9; j++) {
    vec2 cell = fi + cellOf(j);
    micro = min(micro, length(fg - cell - hash22(cell + 5.0)));
  }

  float has = rad > 0.0 ? 1.0 : 0.0;
  float cov = has * smoothstep(0.0, 0.002, outer);
  float dl = min(length(off), 1.0);
  float m = smoothstep(0.42, 0.51, p);
  // a thin shell hardly bends what is behind its middle and a lot near its edge
  vec2 tuv = uv - cov * off * rad * refraction * (0.15 + dl * dl) / asp;
  tuv = 1.0 - abs(1.0 - mod(tuv, 2.0));
  vec4 a = getFromColor(tuv), b = getToColor(tuv);
  vec4 c = mix(vec4(a.rgb * a.a, a.a), vec4(b.rgb * b.a, b.a), m);

  // clear bubble windows in the froth, shut while the pictures are swapped
  float shut = smoothstep(0.36, 0.43, p) * (1.0 - smoothstep(0.5, 0.64, p));
  float froth = thick * foam.a * (1.0 - 0.6 * cov * (1.0 - dl * dl) * (1.0 - shut));
  vec3 frothCol = foam.rgb * (0.9 + 0.1 * (1.0 - smoothstep(0.15, 0.8, micro)) + 0.16 * (vnoise(q * 9.0 / size) - 0.6));
  c = mix(c, vec4(frothCol, 1.0), froth);

  float edge = 1.0 - smoothstep(0.0, 0.16, inside / max(rad, 1e-3));
  float film = smoothstep(0.5, 1.0, dl);
  vec3 irid = 0.5 + 0.5 * cos(6.2832 * (1.6 * dl + seed + 0.25 * off.x + vec3(0.0, 0.33, 0.67)));
  float light = dot(off, vec2(-0.6, 0.8));
  c.rgb *= 1.0 + cov * (0.16 * light * dl - 0.22 * edge * (1.0 - light));
  c.rgb = mix(c.rgb, irid * c.a, cov * 0.22 * film);
  // rims and glints are froth-colored light on the film
  float glint = 1.0 - smoothstep(0.07, 0.16, length((off - vec2(-0.4, 0.48)) * vec2(1.0, 1.4)));
  float bounce = 0.5 * (1.0 - smoothstep(0.03, 0.1, abs(dl - 0.78))) * smoothstep(0.55, 0.95, -light / max(dl, 0.1));
  float shell = 0.75 * (1.0 - smoothstep(0.0006, 0.0035, inside));
  float lum = cov * clamp(0.85 * glint + bounce + shell * (0.6 + 0.4 * light) + 0.12 * film, 0.0, 1.0);
  c = mix(c, vec4(foam.rgb, 1.0), min(1.0, max(lum, 0.55 * ring)) * foam.a);
  return c.a > 0.0 ? vec4(c.rgb / c.a, c.a) : vec4(0.0);
}
