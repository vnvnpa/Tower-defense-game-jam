extends Area2D

var direcao: Vector2 = Vector2.RIGHT
var velocidade: float = 400.0
var dano: int = 10

# Preenchidos pela torre que disparou (ver atiradores.gd -> _spawnar_projetil).
# Só a Mangueira usa isso por enquanto -- o Irrigador não deixa lento.
var causa_lentidao: bool = false
var percentual_lentidao: float = 0.18
var duracao_lentidao: float = 3.0

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

			if causa_lentidao and alvo.has_method("aplicar_lentidao"):
				alvo.aplicar_lentidao(percentual_lentidao, duracao_lentidao)
		queue_free()
