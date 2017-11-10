// Author: Adrian Purser
// License: MIT

vec4 transition (vec2 uv) {
  float   time = progress;
  float 	stime = sin(time * (3.14159265358/2.0));
	float 	phase = time * 3.14159265358 * 3.0;
	float 	shadow = 0.075;
	vec4 	shadow_colour = vec4(0.0,0.0,0.0,0.6);
	float y = (abs(cos(phase))) * (1.0-stime);
	vec4 colour;
	
	if(progress == 1.0)
	  colour = getToColor(uv);
	else if(uv.y > y)
	{
		float d = uv.y - y;
		if(d>shadow)
			colour = getToColor(uv);
		else
		{
			float a = ((d/shadow)*shadow_colour.a) + (1.0-shadow_colour.a);
			colour = mix(shadow_colour,getToColor(uv),a);
		}
	}
	else
	{
		colour = getFromColor(vec2(uv.x,uv.y+(1.0-y)));
	}	
  return colour;
}
