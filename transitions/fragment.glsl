// Author: lbl
// License: MIT
// Description: The outgoing image shatters into fragments that fly away
// Tags: shatter, fragments

#define POINTS 10

float random(vec2 par) {
    return fract(sin(dot(par.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 random2(vec2 par) {
    float rand = random(par);
    return vec2(rand, random(par + rand));
}

vec4 transition (vec2 uv) {
    if (progress <= 0.0) return getFromColor(uv);
    if (progress >= 1.0) return getToColor(uv);

    const float duration = 8.0;
    float time = progress * duration;
    vec2 point[POINTS];
    for (int i = 0; i < POINTS; i++) {
        point[i] = random2(vec2(float(i)));
    }

    vec4 col = getToColor(uv);

    for (int i = 0; i < POINTS; i++) {
        vec2 dir = normalize(random2(vec2(float(i), float(i) + 11.)));
        float v = (1.0 + random(dir) * 0.5) * 0.2;
        vec2 ofst = dir * clamp(time - 0.5, 0.0, duration) * v;
        vec2 U = uv - ofst;

        if (U.x < 0.0 || U.x > 1.0 || U.y < 0.0 || U.y > 1.0) continue;

        float dist_i = distance(U, point[i]);
        bool closest = true;
        for (int j = 0; j < POINTS; j++) {
            if (distance(U, point[j]) < dist_i) {
                closest = false;
                break;
            }
        }

        if (closest) {
            col = getFromColor(U);
            break;
        }
    }
    return col;
}
