// Author:linjunping
// License: MIT

//蜂窝
#define PI 3.141592654
#define ESP 0.0001

vec2 rotateXAndScaled(vec2 pos, vec2 center, float theta, float scale) {
    pos -= center;
    pos = vec2(dot(vec2(cos(theta), sin(theta)), pos), dot(vec2(-sin(theta), cos(theta)), pos));
    pos *= scale;
    pos += center;
    return pos;
}
float and(float x, float y) {
    if(x > ESP && y > ESP)
        return 1.0;
    else
        return 0.0;
}
float xor(float x, float y) {
    if(abs(x - y) > ESP)
        return 1.0;
    else
        return 0.0;
}
float or(float x, float y) {
    if(x < ESP && y < ESP)
        return 0.;
    else
        return 1.0;
}
float not_(float x) {
    return 1.0 - x;
}
vec2 comb(vec2 texCoord, vec2 grid) {
    vec2 posLocal = fract(texCoord * grid);
    posLocal -= 0.5;
    float lineWidth = 0.1;
    float scaleX = sqrt(3.);
    posLocal.x *= scaleX;
    vec2 posLocal60 = rotateXAndScaled(posLocal, vec2(0), PI / 3., 1.);
    vec2 posLocal120 = rotateXAndScaled(posLocal, vec2(0), 2. * PI / 3., 1.);
    float k = 1. / ((1. - lineWidth) / 2.);
    float v1 = floor(abs(posLocal.y) * k);
    float v2 = floor(abs(posLocal60.y) * k);
    float v3 = floor(abs(posLocal120.y) * k);
    float k1 = 1.0 / (0.5 + lineWidth / 2.0);
    float v4 = floor(abs(posLocal.y) * k1);
    float v5 = floor(abs(posLocal60.y) * k1);
    float v6 = floor(abs(posLocal120.y) * k1);
    float k2 = 1.0 / (lineWidth / 2.0);
    float v7 = floor(abs(posLocal.y) * k2);
    float v8 = xor(or(or(v1, v2), v3), or(or(v4, v5), v6));
    float v9 = or(not_(or(or(v4, v5), v6)), v7);
    float patternColor = and(v9, not_(v8));
    return vec2(patternColor, or(or(v1, v2), v3));
}
float combNum(vec2 pattern, vec2 pos, vec2 grid) {
    vec2 gridNum = floor(pos * grid), gridLoc = floor(fract(pos * grid) - 0.5);
    float num = (gridNum.x) * (grid.y * 2.0 + 1.0);
    num += (1.0 - pattern.y) * (grid.y + 1.0 + gridNum.y + 1.0);
    num += (pattern.y) * ((2.0 * gridLoc.x + 2.0) * grid.y + 1.0 + gridLoc.x + 1.0 + gridLoc.y + gridNum.y);
    return num;
}
float random(float x) {
    return fract(sin(x * 23.371531) * 15812.1231 + cos(x * 65.76) * 89.123);
}
vec4 honeyComb(vec2 texCoord) {
    float ratio=progress;
    float rTime = 0.8;
    float u_ratio = clamp(ratio / rTime, 0.0, 1.0);
    vec2 grid = vec2(10, 10);
    vec2 center = vec2(0.5, 0.5);
    float theta = u_ratio * PI / 2.0;
    vec2 pos1 = rotateXAndScaled(texCoord, center, theta, 1.0 - 0.8 * u_ratio);
    vec2 pos2 = rotateXAndScaled(texCoord, center, -PI / 2.0 + theta, 6.0 - 5.0 * u_ratio);
    vec4 texColor1 = vec4(0.0), texColor2 = vec4(0.0);
    if(pos1.x > 0.0 && pos1.x < 1.0 && pos1.y > 0.0 && pos1.y < 1.0) {
        texColor1 = getFromColor(pos1);
    }
    if(pos2.x > 0.0 && pos2.x < 1.0 && pos2.y > 0.0 && pos2.y < 1.0) {
        texColor2 = getToColor(pos2);
    }
    vec2 pattern1 = comb(pos1, grid);
    vec2 pattern2 = comb(pos2, grid);
    float num1 = combNum(pattern1, pos1, grid);
    float num2 = combNum(pattern2, pos2, grid);
    float r1 = random(num1), r2 = random(num2);
    float alpha1 = floor(u_ratio - r1 + 1.0), alpha2 = floor(u_ratio - r2 + 1.0);
    vec4 colo2 = pattern2.x * alpha2 * texColor2, colo1 = pattern1.x * (1.0 - alpha1) * texColor1;
    vec4 color3 = mix(colo1, colo2, max(alpha1, 1.0 - pattern1.x));
    float k = -4.0, alpha3 = k * (texCoord.x - 1.0) + 1.0 + (ratio - rTime) / (1.0 - rTime) * (-1.0 + k);
    return mix(texColor2, color3, clamp(alpha3, 0.0, 1.0));
}

vec4 transition (vec2 uv) {
  return honeyComb(uv);
}
