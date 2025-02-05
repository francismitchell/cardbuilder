shader_type canvas_item;

uniform bool enabled = false;
uniform float brightness = 1.0;
uniform int effect_idx;
// start
uniform float Strength : hint_range(0,20) = 5;
uniform float RandomOffset = 1.0;

float random( float seed )
{
	return fract( 543.2543 * sin( dot( vec2( seed, seed ), vec2( 3525.46 + RandomOffset, -54.3415 ) ) ) );
}
// end

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
	}
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
