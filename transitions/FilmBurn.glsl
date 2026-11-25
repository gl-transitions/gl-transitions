// Author: Anastasia Dunbar
// License: MIT
// Description: Glowing film-burn light leaks wash over the image and reveal the incoming one
// Tags: burn, film, light-leak
// Preview: 0.5
// @param Random seed
uniform float Seed; // = 2.31
float sigmoid(float x, float a) {
    float b = pow(x*2.,a)/2.;
    if (x > .5) {
        b = 1.-pow(2.-(x*2.),a)/2.;
    }
	return b;
}
float rand(float co){
    return fract(sin((co*24.9898)+Seed)*43758.5453);
}
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}
float apow(float a,float b) { return pow(abs(a),b)*sign(b); }
vec3 pow3(vec3 a,vec3 b) { return vec3(apow(a.r,b.r),apow(a.g,b.g),apow(a.b,b.b)); }
float ease(float x) {
    return x > .5 ? 1.-2.*(1.-x)*(1.-x) : 2.*x*x;
}
float random(vec2 co, float k) {
    return fract(sin(dot(co+10., vec2(12.9898+(k*.5),78.233+Seed))) * 43758.5453);
}
vec4 corners(vec2 co, float k) {
    vec2 c = floor(co);
    return vec4(random(c,k),random(c+vec2(1.,0.),k),random(c+vec2(0.,1.),k),random(c+vec2(1.,1.),k));
}
float bilinear(vec4 v, vec2 co) {
    float x = ease(fract(co.x));
    return mix(mix(v.x,v.y,x),mix(v.z,v.w,x),ease(fract(co.y)));
}
float smooth_random(vec2 co, float shft) {
    return bilinear(mix(corners(co,floor(shft)),corners(co,floor(shft+1.)),ease(fract(shft))),co);
}
#define pi 3.14159265358979323
#define clamps(x) clamp(x,0.,1.)

vec4 transition(vec2 p) {
  vec3 f = vec3(0.);
  for (float i = 0.; i < 13.; i++) {
    f += sin(((p.x*rand(i)*6.)+(progress*8.))+rand(i+1.43))*sin(((p.y*rand(i+4.4)*6.)+(progress*6.))+rand(i+2.4));
    float x = p.x-bilinear(corners(vec2(progress*1.3),i+1.),vec2(progress*1.3));
    float sharp = mix(20.,70.,rand(i));
    if (abs(x)*sharp < 1.) f += 1.-clamps(length(vec2(x,p.y-smooth_random(vec2(progress*.5),i+6.25)))*sharp);
  }
  f += 4.;
  f /= 11.;
  f = pow3(f*vec3(1.,0.7,0.6),vec3(1.,2.-sin(progress*pi),1.3));
  f *= sin(progress*pi);
  
  p -= .5;
  p *= 1.+(smooth_random(vec2(progress*5.),6.3)*sin(progress*pi)*.05);
  p += .5;
  
  float bluramount = sin(progress*pi)*.03;
  #define repeats  50.
  float turned = sigmoid(progress,10.);
  vec4 blurred_image = vec4(0.);
  vec2 dir = vec2(1.,0.);
  // from one tap to the next, degrees(360./repeats)
  vec2 turn = vec2(cos(412.5296125),sin(412.5296125));
  for (float i = 0.; i < repeats; i++) { 
      vec2 q = dir * (rand(vec2(i,p.x+p.y))+bluramount);
      vec2 uv2 = p+(q*bluramount);
      blurred_image += mix(getFromColor(uv2),getToColor(uv2),turned);
      dir = vec2(dir.x*turn.x-dir.y*turn.y, dir.x*turn.y+dir.y*turn.x);
  }
  blurred_image /= repeats;
  
  return blurred_image+vec4(f,0.);
}
