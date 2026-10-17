shader_type canvas_item;

// Bola vista desde arriba: una esfera con luz, la franja de las rayadas y el círculo blanco
// del número. ball.gd lleva la orientación y la hace rodar según lo que avanza la bola.
// Ejes de la bola: el número va en ±z (al empezar, -z mira a la cámara) y la franja rodea el eje x.
// Ejes de la vista: x derecha, y abajo, z hacia dentro de la pantalla.

uniform vec4 color : source_color = vec4(1.0);
uniform bool striped = false;
uniform bool numbered = false;
uniform mat3 orientation = mat3(1.0);  // de los ejes de la bola a los de la vista
uniform float radius = 12.0;

const vec3 LAMP = vec3(-0.40, -0.50, -0.77);  // hacia la lámpara: arriba a la izquierda
const float STRIPE = 0.62;  // la rayada tiene color mientras |x| < STRIPE
const float DISC = 0.82;  // el círculo del número es donde |z| > DISC
const vec3 IVORY = vec3(0.96, 0.94, 0.88);

varying vec2 local;

void vertex() {
	local = VERTEX / radius;
}

void fragment() {
	float r = length(local);
	float edge = 1.0 - smoothstep(1.0 - fwidth(r), 1.0, r);
	vec3 n = vec3(local, -sqrt(max(1.0 - r * r, 0.0)));
	vec3 p = transpose(orientation) * n;  // el mismo punto en los ejes de la bola

	vec3 base = color.rgb;
	if (striped) {
		float w = fwidth(p.x);
		base = mix(base, IVORY, smoothstep(STRIPE - w, STRIPE + w, abs(p.x)));
	}
	if (numbered) {
		float w = fwidth(p.z);
		base = mix(base, IVORY, smoothstep(DISC - w, DISC + w, abs(p.z)));
	}

	vec3 l = normalize(LAMP);
	float diffuse = max(dot(n, l), 0.0);
	float shine = pow(max(dot(n, normalize(l + vec3(0.0, 0.0, -1.0))), 0.0), 60.0);
	COLOR = vec4(base * (0.3 + 0.8 * diffuse) + vec3(0.6) * shine, COLOR.a * edge);
}
