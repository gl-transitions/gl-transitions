// Author: martiniti
// License: MIT

uniform vec4 bgcolor; // = vec4(0.0, 0.0, 0.0, 1.0)

float s = pow(2.0 * abs(progress - 0.5), 3.0);

vec4 transition(vec2 p) {
  
   vec2 sq = p.xy / vec2(1.0).xy - .0;
   
    // bottom-left
    vec2 bl = step(vec2(abs(1. - 2.*progress)), sq + .25);
    float pct = bl.x * bl.y;

    // top-right
    vec2 tr = step(vec2(abs(1. - 2.*progress)), 1.25-sq);
    pct *= 1. * tr.x * tr.y;
    
    vec4 square = vec4(vec3(pct), progress);
  
  return mix(
    progress < 0.5 ? getFromColor(p) : getToColor(p), // branching is ok here as we statically depend on progress uniform (branching won't change over pixels)
    bgcolor,
    step(s, square)
  );
  
}
