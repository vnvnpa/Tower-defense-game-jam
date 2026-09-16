extends PathFollow2D



@export var velocidade: float = 70.0

func _process(delta):
	progress += velocidade * delta
	if progress_ratio >= 1.0:
		ControleDeTudo.perder_vida(1)
		queue_free()
	if progress_ratio >= 1.0:
		queue_free()
