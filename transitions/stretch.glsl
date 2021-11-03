// Author: DanMan
// License: MIT
float left = -2.0;
float top = 0.0;
float intensity = 20.0;
float pi = 3.141592653;
uniform int dir; // = 0;

vec2 mirror(vec2 v) {
  vec2 m = mod(v, 2.0);
  return mix(m, 2.0 - m, step(1.0, m));
}

float map(float a, float b, float c, float d, float v) {
  return clamp((v - a) * (d - c) / (b - a) + c, 0., 1.);
}

vec4 transition(vec2 uv) {
  vec2 nUv;
  vec2 uvc = uv;
  vec2 vw = uv;
  vec2 vwo = vw;
  float m = progress;
  float steps = 1.0 / (abs(left + top) + 2.);
  float ms = map(steps, 1.0 - steps, 0., 1., m);
  float flip = (m - 0.5) * 2.;
  float signFlip = -sign(left + top);
  float mult = sin(m * pi);

  if (dir == 1) {
  	vw.x = uv.x * 1. / intensity;
  	vw = mix(vwo, vw, mult);
  	uv.x = vw.x + (-flip * signFlip > 0. ? .0 * mult : 1. * mult);
  	nUv = vec2(uv.x + ms * left, uv.y + ms * top);
  } else {
  	vw.x = uv.x * 1. / intensity;
  	vw = mix(vwo, vw, mult);
  	uv.x = vw.x + (flip * signFlip > 0. ? .0 * mult : 1. * mult);
  	nUv = vec2(uv.x - ms * left, uv.y - ms * top);
  }

  nUv = mirror(nUv);
  vec2 nUvO = nUv;
  if(mod(left, 2.0) != 0.) {
	  nUv.x *= -1.;
  }

  if(mod(top, 2.0) != 0.) {
	  nUv.y *= -1.;
  }

  return mix(getFromColor(nUv), getToColor(nUvO), ms);
}
