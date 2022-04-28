// Author:Adam Liu
// License: MIT

uniform float opacity;// =0.5 
uniform float dividerWidth;// =0.2


const vec2 boundMin = vec2(0, 0);
const vec2 boundMax = vec2(1.0, 1.0);
const vec4 black = vec4(0, 0, 0, 1.0);
const float pi = 3.1415926;

bool inBounds (vec2 p) {
  return all(lessThan(boundMin, p)) && all(lessThan(p, boundMax));
}

mat2 transitionMatrix(float p)
{
    float degree = pi*p;
    return 1./cos(degree) * mat2(vec2(1., 0),
                                vec2(0, cos(degree)));
}

vec2 transitionCoord(vec2 coordinate, mat2 matrix, float offset, float p)
{
    vec2 center = vec2(coordinate.x - 0.5, coordinate.y - 0.5);
    
    vec2 coor = matrix * vec2(center.x + sin(pi*progress)*offset, center.y);
    coor = vec2(coor.x + 0.5 - sin(pi*p)*offset, coor.y+0.5);
    
    return coor;
}


vec4 transition (vec2 uv) {
  
    vec4 redPlane, greenPlane, bluePlane;
     
    mat2 matrix = transitionMatrix(progress);
     
    vec2 redCoord = transitionCoord(uv, matrix, dividerWidth, progress);
    
    vec2 greenCoord = transitionCoord(uv, matrix, 0., progress);
    vec2 blueCoord = transitionCoord(uv, matrix, -dividerWidth, progress);
    
    if (progress>0.5) {
        matrix = transitionMatrix(1.0-progress);
    }
    
   
    if (!inBounds(redCoord)) {
        redPlane = black;
    } else if (progress <= 0.5) {
        vec4 src = getFromColor(redCoord);
    } else {
        vec4 des = getToColor(vec2(1.-redCoord.x, redCoord.y));
        redPlane = vec4(des.r, 0.0, 0.0, des.a);
    }
     
   
    if (!inBounds(greenCoord)) {
        greenPlane = black;
    } else if (progress <= 0.5) {
        vec4 src = getFromColor(greenCoord);
        greenPlane = vec4(0, src.g, 0, src.a);
    } else {
        vec4 des = getToColor(vec2(1.-greenCoord.x, greenCoord.y));
        greenPlane = vec4(0, des.g, 0, des.a);
    }
   
    if (!inBounds(blueCoord)) {
        bluePlane = black;
    } else if (progress <= 0.5) {
        vec4 src = getFromColor(blueCoord);
        bluePlane = vec4(0, 0, src.b, src.a);
    } else {
        vec4 des = getToColor(vec2(1.-blueCoord.x, blueCoord.y));;
        bluePlane = vec4(0, 0, des.b, des.a);
    }
   
    if (progress == 1.) {
        return getToColor(uv);
    } else if (progress == 0.0) {
        return getFromColor(uv);
    } else {
        return mix(mix(redPlane, greenPlane, opacity), bluePlane, opacity);
    }
}