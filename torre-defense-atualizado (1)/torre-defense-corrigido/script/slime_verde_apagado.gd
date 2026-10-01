extends Node2D

@onready var vida: Label = $ColorRect/vida
@onready var color_rect: ColorRect = $ColorRect
@onready var slime: AnimatedSprite2D = $slime

@export var velocidade: float = 100.0  # ajuste esse valor no Inspector pra cada inimigo/cena

var posicao_anterior: Vector2 = Vector2.ZERO
var life = 50
var _morrendo: bool = false

func esta_morrendo() -> bool:
	return _morrendo

func _ready():
	posicao_anterior = global_position
	color_rect.position.y = -50
	vida.text = str(life)

func _process(_delta):
	var delta_pos = global_position - posicao_anterior
	posicao_anterior = global_position

	# só atualiza animação se realmente moveu (evita "tremer" a animação parado)
	if delta_pos.length() > 0.01:
		if abs(delta_pos.x) > abs(delta_pos.y):
			# movimento predominante no eixo X -> lateral
			if slime.animation != "andarLado":
				slime.play("andarLado")
			slime.flip_h = delta_pos.x < 0  # olhando pra esquerda quando X negativo
		else:
			# movimento predominante no eixo Y -> frente/costas
			if slime.animation != "andarFrente":
				slime.play("andarFrente")
			slime.flip_v = delta_pos.y < 0  # indo pra cima -> inverte verticalmente

func tomar_dano(dano: int):
	# Já morreu? Ignora qualquer dano extra (evita moeda duplicada enquanto
	# o nó ainda não foi removido de verdade).
	if _morrendo:
		return

	life -= dano
	vida.text = str(life)
	if life <= 0:
		_morrendo = true
		ControleDeTudo.ganhar_coin(1)
		get_parent().queue_free()
