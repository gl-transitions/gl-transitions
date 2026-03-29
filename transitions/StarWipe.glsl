// Author:Ben Lucas
// License: MIT
#define PI 3.141592653589793
#define STAR_ANGLE 1.2566370614359172

uniform float boder_thickness;// = 0.01;
uniform float star_rotation;// = 0.75;
uniform vec4 border_color; // = vec4(1.0);
uniform vec2 star_center;// = vec2(0.5);

vec2 rotate(vec2 v, float theta) {
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    
    return vec2(
        cosTheta * v.x - sinTheta * v.y,
        sinTheta * v.x + cosTheta * v.y
    );
}

bool inStar(vec2 uv, vec2 center, float radius){
  vec2 uv_centered = uv - center;
  uv_centered = rotate(uv_centered, star_rotation * STAR_ANGLE);
  float theta = atan(uv_centered.y, uv_centered.x) + PI;
  
  vec2 uv_rotated = rotate(uv_centered, -STAR_ANGLE * (floor(theta / STAR_ANGLE) + 0.5));
  
  float slope = 0.3;
  if(uv_rotated.y > 0.0){
      return (radius + uv_rotated.x * slope > uv_rotated.y);
  } else{
     return (-radius - uv_rotated.x * slope < uv_rotated.y);
  }
}


vec4 transition (vec2 uv) {
  float progressScaled = (2.0 * boder_thickness + 1.0) * progress - boder_thickness;
  if(inStar(uv, star_center, progressScaled)){
    return getToColor(uv);
  } else if(inStar(uv, star_center, progressScaled+boder_thickness)){
    return border_color;
  }
  else{
    return getFromColor(uv);

  }
}
