extends Control

## Ícone decorativo (uma "faísca" de 8 pontas) usado ao lado do texto
## "Anthropic" na intro. É um desenho genérico e original -- não uma cópia
## do logo oficial da Claude/Anthropic.

@export var cor: Color = Color(0.86, 0.47, 0.26, 1.0)


func _draw() -> void:

	var centro: Vector2 = size / 2.0
	var raio_externo: float = min(size.x, size.y) / 2.0
	var raio_interno: float = raio_externo * 0.34
	var pontas: int = 8

	var pontos: PackedVector2Array = []

	for i in range(pontas * 2):

		var raio: float = raio_externo if i % 2 == 0 else raio_interno
		var angulo: float = (TAU / (pontas * 2)) * i - PI / 2.0

		pontos.append(centro + Vector2(cos(angulo), sin(angulo)) * raio)

	draw_colored_polygon(pontos, cor)
