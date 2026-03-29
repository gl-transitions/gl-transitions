// Name: Lissajous Tiles
// Author: Boundless <info@boundless-beta.com>
// License: MIT
// <3

uniform float speed; // = 0.5;
uniform vec2 freq; // = vec2(2.,3.);
uniform float offset; // = 2.;
uniform float zoom; // = 0.8;
uniform float fade; // = 3.;

vec4 transition (vec2 uv) {
  const vec2 grid = vec2(10.,10.); // grid size
  vec4 col = vec4(0.);
  float p = 1.-pow(abs(1.-2.*progress),3.); // transition curve
  for (float h = 0.; h < grid.x*grid.y; h+=1.) {
    float iBig = mod(h,grid.x);
    float jBig = floor(h / grid.x);
    float i = iBig/grid.x;
    float j = jBig/grid.y;
    vec2 uv0 = (uv + vec2(i,j) - 0.5 + 0.5/grid + vec2(cos((i/grid.y+j)*6.28*freq.x+progress*6.*speed)*zoom/2.,sin((i/grid.y+j)*6.28*freq.y+progress*6.*(1.+offset)*speed)*zoom/2.));
    uv0 = uv0*p + uv*(1.-p);
    bool m = uv0.x > i && uv0.x < (i+1./grid.x) && uv0.y > j && uv0.y < (j+1./grid.x); // mask for each (i,j) tile
    col *= 1.-float(m);
    col += mix(
      getFromColor(uv0),
      getToColor(uv0),
      min(max((progress)*(((1.+fade)*2.)*progress)-(fade)+(i/grid.y+j)*(fade),0.),1.)
    )*float(m);
  }
  return col;
}
