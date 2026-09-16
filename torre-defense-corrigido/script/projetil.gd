extends Area2D

var direcao: Vector2 = Vector2.RIGHT
var velocidade: float = 400.0
var dano: int = 10

func setup(dir: Vector2, vel: float):
	direcao = dir
	velocidade = vel

func _ready():
	area_entered.connect(_on_atingiu)

func _process(delta):
	global_position += direcao * velocidade * delta

func _on_atingiu(area):
	var alvo = area.get_parent()  # sobe pro nó raiz (slime ou torre), que tem tomar_dano

	if area.is_in_group("inimigos"):
		# FIX: antes cada peer chamava alvo.tomar_dano(dano) direto, então
		# cada cópia do jogo decidia sozinha quando o inimigo morria e dava
		# moeda -- resultado: vida/moeda diferentes em cada tela. Agora só o
		# HOST manda o dano de verdade pra rede (pedir_dano_inimigo ->
		# aplicar_dano_inimigo), que roda igual em todo mundo. Nos clientes
		# o projétil só ilustra visualmente o tiro, sem afetar o jogo real.
		if multiplayer.is_server():
			NetworkManager.pedir_dano_inimigo.rpc_id(1, alvo.get_path(), dano)
		queue_free()
	elif area.is_in_group("torres"):
		if alvo.has_method("tomar_dano"):
			alvo.tomar_dano(dano)
		queue_free()
