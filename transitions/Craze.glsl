// Author: gre
// License: MIT
// Description: The outgoing image is a brittle coat on a sheet pulled from both sides: it stretches, a crack runs down its middle and gapes open, then cracks run down the middle of every piece in turn, each strip snapping back to its own width as the gaps widen onto the incoming image, until the strips lose their grip and drop out of the frame
// Tags: physical, stretch, crack, strips, gravity

// @range(1, 4, 1) Rounds of cracking: each round splits every strip in two
uniform int levels; // = 3
// @range(0, 1) Darkness of the shadow cast on the incoming image
uniform float shadow; // = 0.45

const int MAXN = 16;

float hash(float n) {
  n = fract(n * 0.1031);
  n *= n + 33.33;
  n *= n + n;
  return fract(n);
}

// linear interpolation keeps the corners of a zigzag crack
float zigzag(float x) {
  float i = floor(x);
  return mix(hash(i), hash(i + 1.0), x - i);
}

float ease(float x) {
  x = clamp(x, 0.0, 1.0);
  return x * x * (3.0 - 2.0 * x);
}

float crackTime(int j, int L) {
  int lv = L - 1;
  int k = j;
  for (int i = 0; i < 4; i++) {
    if (k > 0 && k - 2 * (k / 2) == 0) { k /= 2; lv--; }
  }
  return 0.12 + 0.36 * float(lv) / float(L) + 0.04 * hash(float(j) * 3.7);
}

float jag(int j, float y) {
  float s = float(j) * 7.13;
  return 0.022 * (zigzag(y * 7.0 + s) - 0.5) + 0.012 * (zigzag(y * 23.0 + s) - 0.5);
}

float crackFront(int j, int L) {
  return 1.0 - clamp((progress - crackTime(j, L) + 0.06) / 0.06, 0.0, 1.0) * 1.02;
}

float gapW(int j, int L, float fN) {
  float t = max(progress - crackTime(j, L), 0.0);
  return 0.09 * ratio / float(L) * (1.0 - exp(-t * 9.0)) + 1.12 * t / fN;
}

vec4 transition(vec2 uv) {
  int L = levels < 1 ? 1 : (levels > 4 ? 4 : levels);
  int N = L == 1 ? 2 : (L == 2 ? 4 : (L == 3 ? 8 : 16));
  float fN = float(N);
  float X = uv.x * ratio;
  float p = progress;
  float first = crackTime(N / 2, L);
  float strain = 0.07 * ease(p / 0.14) * (1.0 - ease((p - first) / 0.1));
  float shadeIn = clamp((p - first) * 8.0, 0.0, 1.0);

  float total = 0.0;
  for (int j = 1; j < MAXN; j++) {
    if (j >= N) break;
    total += gapW(j, L, fN);
  }
  float w = ratio / fN;
  float x = 0.5 * ratio - 0.5 * (ratio * (1.0 + strain) + total);

  vec4 col = vec4(0.0);
  float cov = 0.0, shade = 0.0;
  for (int i = 0; i < MAXN; i++) {
    if (i >= N) break;
    float fi = float(i);
    float t0 = 0.52 + 0.2 * hash(fi * 1.7 + fN);
    float ft = max(p - t0, 0.0) / (1.0 - t0);
    float fall = 1.6 * ft * ft;
    float a = 0.35 * ft * ft * (hash(fi * 5.3 + fN) - 0.5);
    float sw = w * (1.0 + strain);
    vec2 piv = vec2(x + 0.5 * sw, 0.5 - fall);
    for (int s = 0; s < 2; s++) {
      vec2 o = s == 0 ? vec2(0.012, -0.018) * (1.0 + 3.0 * ft) : vec2(0.0);
      vec2 d = vec2(X, uv.y) - piv - o;
      d = vec2(cos(a) * d.x + sin(a) * d.y, -sin(a) * d.x + cos(a) * d.y);
      float u = (d.x + 0.5 * sw) / sw;
      float y = d.y + 0.5;
      float lo = i == 0 ? -1.0 : jag(i, y) / w;
      float hi = i == N - 1 ? 2.0 : 1.0 + jag(i + 1, y) / w;
      float sharp = s == 0 ? 50.0 : 400.0;
      // the y edge is offset by half a pixel more so the resting strips cover the frame's border rows
      float m = clamp(min(min(u - lo, hi - u) * sw * sharp + 0.5, min(y, 1.0 - y) * sharp + 1.0), 0.0, 1.0);
      if (s == 0) {
        shade = max(shade, m * shadeIn);
      } else if (m > 0.0) {
        vec2 q = vec2((fi + u) / fN, y);
        vec4 c = getFromColor(q);
        c.rgb *= 1.0 - 0.9 * abs(a);
        for (int k = 0; k < 2; k++) {
          int j = i + k;
          if (j > 0 && j < N) {
            float cx = fi / fN + jag(j, y) / ratio + float(k) / fN;
            float dl = abs(q.x - cx) * ratio;
            float open = clamp(gapW(j, L, fN) * 200.0, 0.0, 1.0);
            float line = (1.0 - smoothstep(0.0, 0.006, dl)) * step(crackFront(j, L), y);
            c.rgb *= 1.0 - 0.6 * line * (1.0 - open);
            c.rgb = mix(c.rgb, vec3(0.95), 0.6 * (1.0 - smoothstep(0.0, 0.005, dl)) * open);
          }
        }
        // earlier strips stay in front: a strip only takes the coverage left over
        float add = min(m, 1.0 - cov);
        col += c * add;
        cov += add;
      }
    }
    x += sw + (i < N - 1 ? gapW(i + 1, L, fN) : 0.0);
  }
  vec4 to = getToColor(uv);
  to.rgb *= 1.0 - shadow * shade;
  return mix(to, col / max(cov, 1e-4), cov);
}
