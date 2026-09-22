extends Node2D
@onready var Rodada: Label = $Rodada
@onready var path_follow_original: PathFollow2D = $Path2D/PathFollow2D
@onready var spawner: MultiplayerSpawner = $Path2D/MultiplayerSpawner

@export var inimigos_normais: Array[InimigoConfig] = []
@export var miniboss_scene: PackedScene
@export var miniboss_a_cada_x_rodadas: int = 5
@export var boss_final_scene: PackedScene
@export var intervalo: float = 0.9
@export var total_rodadas: int = 10
@export var min_inimigos_por_rodada: int = 5
@export var max_inimigos_por_rodada: int = 15
@export var tempo_min_entre_rodadas: float = 5.0
@export var tempo_max_entre_rodadas: float = 8.0

func _ready():
	print(">>> DEBUG meu ID: ", multiplayer.get_unique_id(), " | is_server(): ", multiplayer.is_server(), " | peer válido: ", multiplayer.multiplayer_peer != null)
	var largura = get_viewport().get_visible_rect().size.x
	Rodada.position.x = (largura - Rodada.size.x) / 2
	Rodada.position.y = 20
	path_follow_original.set_process(false)
	spawner.spawn_function = _spawn_inimigo

	# só o host roda as ondas; se não tiver multiplayer ativo, is_server() é sempre true
	if multiplayer.is_server():
		_aplicar_modo_de_jogo()
		await iniciar_rodadas()


func _aplicar_modo_de_jogo() -> void:
	# Modo escolhido pelo host no lobby (ver NetworkManager.modo_de_jogo).
	match NetworkManager.modo_de_jogo:
		"sobrevivencia":
			total_rodadas = 9999
		"corrida":
			tempo_min_entre_rodadas = 2.0
			tempo_max_entre_rodadas = 3.0
		_: # "classico" (ou vazio, se caiu direto aqui fora do lobby)
			pass


func iniciar_rodadas():
	for i in range(total_rodadas):
		var numero_da_rodada = i + 1
		Rodada.text = "Rodada " + str(numero_da_rodada)
		var quantidade = randi_range(min_inimigos_por_rodada, max_inimigos_por_rodada)
		await spawnar_rodada(quantidade, numero_da_rodada)
		var tempo_espera = randf_range(tempo_min_entre_rodadas, tempo_max_entre_rodadas)
		await get_tree().create_timer(tempo_espera).timeout
	Rodada.text = "Fim das rodadas"

func spawnar_rodada(quantidade: int, numero_da_rodada: int):
	var eh_rodada_final = numero_da_rodada == total_rodadas
	var eh_rodada_de_miniboss = (not eh_rodada_final) and \
		miniboss_a_cada_x_rodadas > 0 and \
		numero_da_rodada % miniboss_a_cada_x_rodadas == 0

	for j in range(quantidade):
		var cena_escolhida: PackedScene

		if eh_rodada_final and j == quantidade - 1 and boss_final_scene != null:
			cena_escolhida = boss_final_scene
		elif eh_rodada_de_miniboss and j == quantidade - 1 and miniboss_scene != null:
			cena_escolhida = miniboss_scene
		else:
			cena_escolhida = sortear_inimigo(inimigos_normais)

		# em vez de instanciar direto, pedimos pro spawner replicar a criação
		spawner.spawn(cena_escolhida.resource_path)

		await get_tree().create_timer(intervalo).timeout

# Roda no host E é replicada automaticamente pro cliente pelo MultiplayerSpawner.
# Recebe o "data" que passamos em spawner.spawn(...) — aqui, o caminho da cena.
func _spawn_inimigo(caminho_da_cena: String) -> Node:
	var cena_escolhida: PackedScene = load(caminho_da_cena)
	var novo_path_follow = path_follow_original.duplicate()
	novo_path_follow.progress = 0.0
	novo_path_follow.set_process(true)

	var inimigo = cena_escolhida.instantiate()

	# FIX: a "velocidade" configurada em cada inimigo (slime.gd) nunca era
	# usada de verdade -- quem manda na velocidade real é o PathFollow2D que
	# carrega o inimigo pelo caminho, e ele tinha sua própria velocidade fixa,
	# igual pra todo mundo. Resultado: BOSS_VERMELHO e RIMURU tinham "vida"
	# maior mas se moviam exatamente igual a um slime comum. Chamamos
	# configurar_inimigo() aqui (antes de entrar na árvore, por isso ainda
	# não mexe em nenhum nó) só pra já saber a velocidade certa e repassar
	# pro PathFollow2D.
	if inimigo.has_method("configurar_inimigo"):
		inimigo.configurar_inimigo()
	if "velocidade" in inimigo:
		novo_path_follow.velocidade = inimigo.velocidade

	novo_path_follow.add_child(inimigo)

	return novo_path_follow

func sortear_inimigo(lista: Array[InimigoConfig]) -> PackedScene:
	var peso_total = 0
	for item in lista:
		peso_total += item.peso
	var sorteio = randi_range(1, peso_total)
	var acumulado = 0
	for item in lista:
		acumulado += item.peso
		if sorteio <= acumulado:
			return item.cena
	return lista[0].cena
