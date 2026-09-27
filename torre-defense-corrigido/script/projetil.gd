extends Area2D

var direcao: Vector2 = Vector2.RIGHT
var velocidade: float = 400.0
var dano: int = 10

func setup(dir: Vector2, vel: float):
	direcao = dir
	velocidade = vel


func _ready():
	add_to_group("projetil_agua")
	area_entered.connect(_on_atingiu)


func _process(delta):
	global_position += direcao * velocidade * delta

func _on_atingiu(area):
	var alvo = area.get_parent()  # sobe pro nó raiz (slime ou torre), que tem tomar_dano

	if area.is_in_group("inimigos") or area.is_in_group("torres"):
		if is_instance_valid(alvo) and alvo.has_method("tomar_dano"):
			alvo.tomar_dano(dano)
		queue_free()
