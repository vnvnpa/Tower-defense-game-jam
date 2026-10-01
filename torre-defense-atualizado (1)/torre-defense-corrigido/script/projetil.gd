extends Area2D

var direcao: Vector2 = Vector2.RIGHT
var velocidade: float = 400.0
var dano: int = 10

# Preenchidos pela torre que disparou (ver atiradores.gd -> _criar_projetil).
var causa_lentidao: bool = false
var percentual_lentidao: float = 0.18
var duracao_lentidao: float = 3.0

# Dano contínuo (irrigadores): "dano_continuo_por_tick" a cada 1s, durante
# "duracao_dano_continuo" segundos.
var causa_dano_continuo: bool = false
var dano_continuo_por_tick: int = 0
var duracao_dano_continuo: float = 5.0

# Irrigador: o tiro atravessa os slimes em vez de sumir no primeiro.
var atravessa: bool = false

# Se > 0, o tiro some depois de percorrer essa distância (evita bala
# voando pra sempre quando erra).
var distancia_max: float = 0.0
var _percorrido: float = 0.0

# Slimes que já foram atingidos por ESTE tiro (pra atravessar sem bater
# duas vezes no mesmo).
var _ja_atingidos: Array = []


func setup(dir: Vector2, vel: float):
	direcao = dir
	velocidade = vel


func _ready():
	add_to_group("projetil_agua")
	area_entered.connect(_on_atingiu)


func _process(delta):
	var passo: Vector2 = direcao * velocidade * delta
	global_position += passo

	if distancia_max > 0.0:
		_percorrido += passo.length()

		if _percorrido >= distancia_max:
			queue_free()


func _on_atingiu(area):
	# Só reage a inimigos. As torres não tomam mais dano, então a bala
	# não deve mais sumir ao passar por cima de uma torre aliada.
	if not area.is_in_group("inimigos"):
		return

	var alvo = area.get_parent()  # sobe pro nó raiz (slime), que tem tomar_dano

	if not is_instance_valid(alvo) or alvo in _ja_atingidos:
		return

	# Slime que já está morrendo não conta como acerto (a bala passa).
	if alvo.has_method("esta_morrendo") and alvo.esta_morrendo():
		return

	_ja_atingidos.append(alvo)

	if alvo.has_method("tomar_dano"):
		alvo.tomar_dano(dano)

	if causa_lentidao and alvo.has_method("aplicar_lentidao"):
		alvo.aplicar_lentidao(percentual_lentidao, duracao_lentidao)

	if causa_dano_continuo and alvo.has_method("aplicar_dano_continuo"):
		alvo.aplicar_dano_continuo(dano_continuo_por_tick, duracao_dano_continuo)

	if not atravessa:
		queue_free()
