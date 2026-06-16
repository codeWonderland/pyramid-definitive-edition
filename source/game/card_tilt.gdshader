shader_type canvas_item;

// Fakes a 3D pitch/roll lean on a flat 2D card by rotating its quad's corners
// in 3D and applying a perspective divide. Driven from challenge_card.gd while
// the card is being dragged to give a "wind resistance" feel.
//
// pitch: lean about the horizontal (X) axis  — top/bottom tips toward/away
// roll:  lean about the vertical (Y) axis     — left/right tips toward/away

uniform vec2 card_size = vec2(105.0, 150.0);
uniform float pitch = 0.0;
uniform float roll = 0.0;
uniform float perspective = 0.0020;

void vertex() {
	vec2 center = card_size * 0.5;
	vec3 p = vec3(VERTEX - center, 0.0);

	// Roll about the Y axis.
	float cr = cos(roll);
	float sr = sin(roll);
	p = vec3(p.x * cr + p.z * sr, p.y, -p.x * sr + p.z * cr);

	// Pitch about the X axis.
	float cp = cos(pitch);
	float sp = sin(pitch);
	p = vec3(p.x, p.y * cp - p.z * sp, p.y * sp + p.z * cp);

	// Perspective: corners pushed away (negative z) shrink, nearer ones grow.
	float w = 1.0 / (1.0 - p.z * perspective);
	VERTEX = p.xy * w + center;
}
