extends Sprite2D

var posicao_x_anterior: float = 0.0

func _ready():
	posicao_x_anterior = global_position.x

func _process(delta):
	var posicao_x_atual = global_position.x
	
	#if posicao_x_atual < posicao_x_anterior:
		#$AnimatedSprite2D.flip_h = true
	#elif posicao_x_atual > posicao_x_anterior:
		#$AnimatedSprite2D.flip_h = false
		#
	#posicao_x_anterior = posicao_x_atual
