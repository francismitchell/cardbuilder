shader_type canvas_item;

uniform float Strength : hint_range(0,20) = 5;
uniform float RandomOffset = 1.0;

const float speed = 0.00001;

float random( float seed )
{
	return fract( 543.2543 * sin( dot( vec2( seed, seed ), vec2( 3525.46 + RandomOffset, -54.3415 ) ) ) );
}

void vertex() {
	// Called for every vertex the material is visible on.
	vec2 VERTEX_OFFSET = VERTEX;
	VERTEX_OFFSET.x += (random(( trunc( VERTEX_OFFSET.y)) + speed * TIME) - 0.5) * Strength;
	VERTEX_OFFSET.y += (random(( trunc( VERTEX_OFFSET.x)) + speed * TIME) - 0.5) * Strength;
	VERTEX = VERTEX_OFFSET;
}

void fragment() {
	// Called for every pixel the material is visible on.
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
