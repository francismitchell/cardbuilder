shader_type canvas_item;

uniform bool enabled = false;
uniform float brightness = 1.0;
uniform int effect_idx;
// start
uniform float Strength : hint_range(0,20) = 5;
uniform float RandomOffset = 1.0;
uniform float shift = 0.0;

float random( float seed )
{
	return fract( 543.2543 * sin( dot( vec2( seed, seed ), vec2( 3525.46 + RandomOffset, -54.3415 ) ) ) );
}
// end


vec3 palette(float t) {
	vec3 a = vec3(0.5, 0.5, 0.5);
	vec3 b = vec3(0.5, 0.5, 0.5);
	vec3 c = vec3(1.0, 1.0, 1.0);
	vec3 d = vec3(0.263, 0.416, 0.557);

	return a + b * cos(6.28318*(c*t+d));
}

vec3 holographic_effect(vec2 uv0) {
	vec2 uv = uv0;
	vec3 finalColor = vec3(0.0);

	for (float i = 0.0; i < 4.0; i++) {
		uv = fract(uv * 2.0) - 0.5;
		float d = length(uv);
		vec3 col = palette(length(uv0 - 0.5) + shift/8.);

		d = sin(8.*d + shift)/8.;
		d = abs(d);
		d = 0.02/d;
		finalColor += col * d;
	}
	return finalColor;
}

void vertex() {
	// Called for every vertex the material is visible on.
	switch (effect_idx) {
		case 1:
			vec2 VERTEX_OFFSET = VERTEX;
			VERTEX_OFFSET.x += (
				random(
				( trunc( VERTEX_OFFSET.y))
			+	TIME
			) - 0.5
		) * Strength ;
	VERTEX_OFFSET.y += (
		random(
			( trunc( VERTEX_OFFSET.x))
		+	TIME
		) - 0.5
	) * Strength;
	VERTEX = VERTEX_OFFSET;
	break;
	}
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	switch (effect_idx) {
		case 1:
			COLOR = vec4(brightness * (1.0 - color.rgb), color.a);
			break;
		case 2:
			color.xyz = clamp(color.xyz + 0.05 * holographic_effect(UV), 0.0, 1.0);
			COLOR = color;
			break;
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
