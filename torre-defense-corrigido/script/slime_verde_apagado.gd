extends Node2D

@onready var vida: Label = $ColorRect/vida
@onready var color_rect: ColorRect = $ColorRect
@onready var slime: AnimatedSprite2D = $slime

@export var velocidade: float = 100.0  # ajuste esse valor no Inspector pra cada inimigo/cena

var posicao_anterior: Vector2 = Vector2.ZERO
var life = 50

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
	life -= dano
	vida.text = str(life)
	if life <= 0:
		# FIX: era ControleDeTudo.coin += 1 direto, rodando em cada peer
		# separadamente (dessincronizava a moeda). ganhar_coin() já é
		# autoritativa: só o host aplica de fato e replica pra todo mundo.
		ControleDeTudo.ganhar_coin(1)
		get_parent().queue_free()
