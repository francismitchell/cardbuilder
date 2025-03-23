shader_type canvas_item;
uniform vec4 shape_colour : source_color = vec4(1.0);
uniform vec4 base_colour : source_color = vec4(0.0);

void vertex() {
	// Called for every vertex the material is visible on.
}

float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

float sdUnevenCapsule( vec2 p, float r1, float r2, float h )
{
    p.x = abs(p.x);
    float b = (r1-r2)/h;
    float a = sqrt(1.0-b*b);
    float k = dot(p,vec2(-b,a));
    if( k < 0.0 ) return length(p) - r1;
    if( k > a*h ) return length(p-vec2(0.0,h)) - r2;
    return dot(p, vec2(a,b) ) - r1;
}


void fragment() {
	// Called for every pixel the material is visible on.
	vec2 uv = UV / 64.;
	uv -= 0.5;
	// rotate uv
	float theta = 0.1;
	vec2 uv0 =  uv;
	uv.x = cos(theta)*uv0.x - sin(theta)*uv0.y;
	uv.y = sin(theta)*uv0.x + cos(theta)*uv0.y;
	
	
	//uv.x = uv.x - round(uv.x);
	uv.y = uv.y - round(uv.y);
	if (mod(uv.x,1.)==2.) {
		
		
		uv.x = uv.x-0.5 - round(uv.x-0.5);
	}
	
	vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
	//uv = fract(uv);
	float d = sdUnevenCapsule(uv, 0.05, 0.2, 0.3);
	//d = 1./d;

	float distanceChange = fwidth(d) * 0.5;
	float antialiasedCutoff = smoothstep(distanceChange, -distanceChange, d);
	//for (float i=0.0; i<2.0; i++) {
		//uv = fract(uv*1.5) - 0.5;
		//
		//d = sin(20.0*d + 0.2*TIME);
		//d = smoothstep(0.8, 0.9, d);
		//color = base_colour;
		//color = shape_colour * d;
		//
	//}
	COLOR = base_colour+(1.-d)*shape_colour*antialiasedCutoff;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
