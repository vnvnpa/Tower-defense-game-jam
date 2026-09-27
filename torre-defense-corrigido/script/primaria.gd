extends Node2D

const MENU_VITORIA := preload("res://cenas/menus/menuVitoria.tscn")

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
	var largura = get_viewport().get_visible_rect().size.x
	Rodada.position.x = (largura - Rodada.size.x) / 2
	Rodada.position.y = 20
	path_follow_original.set_process(false)
	spawner.spawn_function = _spawn_inimigo

	# só o host roda as ondas; se não tiver multiplayer ativo, is_server() é sempre true
	if multiplayer.is_server():
		# No modo "campanha" (níveis), NÃO sobrescreve os valores que você
		# configurou no Inspector dessa cena específica (total_rodadas,
		# min/max inimigos, pesos etc.). Só os modos antigos (classico,
		# rapido, infinito...) usam esse preset automático.
		if NetworkManager.modo_de_jogo != "campanha":
			_aplicar_modo_de_jogo()
		await iniciar_rodadas()


func _aplicar_modo_de_jogo() -> void:
	# Cada modo altera sua própria configuração sem espalhar regras pelo mapa.
	# A moeda inicial é definida pelo NetworkManager antes da cena abrir.
	match NetworkManager.modo_de_jogo:
		"classico":
			total_rodadas = 10
			min_inimigos_por_rodada = 5
			max_inimigos_por_rodada = 15
			tempo_min_entre_rodadas = 5.0
			tempo_max_entre_rodadas = 8.0
		"rapido":
			total_rodadas = 20
			min_inimigos_por_rodada = 6
			max_inimigos_por_rodada = 12
			intervalo = 0.45
			tempo_min_entre_rodadas = 1.5
			tempo_max_entre_rodadas = 2.5
		"so_rimuru":
			total_rodadas = 15
			min_inimigos_por_rodada = 2
			max_inimigos_por_rodada = 5
			intervalo = 1.2
			tempo_min_entre_rodadas = 3.0
			tempo_max_entre_rodadas = 5.0
		"infinito":
			total_rodadas = 999999
			min_inimigos_por_rodada = 5
			max_inimigos_por_rodada = 12
			intervalo = 0.8
			tempo_min_entre_rodadas = 3.0
			tempo_max_entre_rodadas = 5.0
		"sobrevivencia":
			total_rodadas = 9999
			min_inimigos_por_rodada = 8
			max_inimigos_por_rodada = 20
			intervalo = 0.55
			tempo_min_entre_rodadas = 2.0
			tempo_max_entre_rodadas = 4.0
		"corrida":
			total_rodadas = 10
			min_inimigos_por_rodada = 8
			max_inimigos_por_rodada = 18
			intervalo = 0.6
			tempo_min_entre_rodadas = 1.5
			tempo_max_entre_rodadas = 2.5
		_:
			pass


func iniciar_rodadas():
	if NetworkManager.modo_de_jogo == "infinito":
		var numero_da_rodada := 1
		while true:
			Rodada.text = "Rodada " + str(numero_da_rodada)
			var quantidade := randi_range(
				min_inimigos_por_rodada + mini(numero_da_rodada / 10, 10),
				max_inimigos_por_rodada + mini(numero_da_rodada / 8, 15)
			)
			await spawnar_rodada(quantidade, numero_da_rodada)
			var tempo_espera := randf_range(tempo_min_entre_rodadas, tempo_max_entre_rodadas)
			await get_tree().create_timer(tempo_espera).timeout
			numero_da_rodada += 1
		return

	for i in range(total_rodadas):
		var numero_da_rodada = i + 1
		Rodada.text = "Rodada " + str(numero_da_rodada)
		var quantidade = randi_range(min_inimigos_por_rodada, max_inimigos_por_rodada)
		await spawnar_rodada(quantidade, numero_da_rodada)
		var tempo_espera = randf_range(tempo_min_entre_rodadas, tempo_max_entre_rodadas)
		await get_tree().create_timer(tempo_espera).timeout

	Rodada.text = "Última leva! Derrote todos os inimigos..."

	# FIX: antes a vitória disparava assim que o ÚLTIMO INIMIGO ERA SPAWNADO
	# (ex: o boss aparecendo na tela), mesmo que ele ainda estivesse vivo e
	# andando pelo caminho. Agora espera não sobrar ninguém do grupo
	# "inimigos" (esvazia quando morre OU quando chega ao fim do caminho)
	# antes de considerar o nível concluído.
	while not get_tree().get_nodes_in_group("inimigos").is_empty():
		if ControleDeTudo.jogo_acabou:
			return  # jogador morreu esperando -- quem cuida da tela é o Game Over
		await get_tree().create_timer(0.5).timeout

	Rodada.text = "Fim das rodadas"

	# Só conta como vitória (e avança o nível da campanha) se o jogador
	# ainda estiver vivo -- se morreu no meio da última rodada, quem trata
	# isso é o Game Over do ControleDeTudo, não aqui.
	if not ControleDeTudo.jogo_acabou:
		_vencer_nivel()


func _vencer_nivel() -> void:
	Progresso.completar_nivel(Progresso.nivel_atual)
	get_tree().paused = true
	add_child(MENU_VITORIA.instantiate())

func spawnar_rodada(quantidade: int, numero_da_rodada: int):
	var eh_rodada_final = numero_da_rodada == total_rodadas
	var eh_rodada_de_miniboss = (not eh_rodada_final) and \
		miniboss_a_cada_x_rodadas > 0 and \
		numero_da_rodada % miniboss_a_cada_x_rodadas == 0

	for j in range(quantidade):
		var cena_escolhida: PackedScene

		if NetworkManager.modo_de_jogo == "so_rimuru" and boss_final_scene != null:
			# Este modo usa exclusivamente o Rimuru como inimigo.
			cena_escolhida = boss_final_scene
		elif eh_rodada_final and j == quantidade - 1 and boss_final_scene != null:
			cena_escolhida = boss_final_scene
		elif eh_rodada_de_miniboss and j == quantidade - 1 and miniboss_scene != null:
			cena_escolhida = miniboss_scene
		else:
			cena_escolhida = sortear_inimigo(inimigos_normais)

		spawner.spawn(cena_escolhida.resource_path)
		await get_tree().create_timer(intervalo).timeout

# Função usada pelo MultiplayerSpawner para criar o inimigo no mesmo PathFollow2D
# no host e nos clientes. O host passa o caminho da cena em spawner.spawn().
func _spawn_inimigo(caminho_da_cena: String) -> Node:
	var cena_escolhida: PackedScene = load(caminho_da_cena)
	if cena_escolhida == null:
		push_error("Não foi possível carregar a cena do inimigo: %s" % caminho_da_cena)
		return null

	var novo_path_follow := path_follow_original.duplicate() as PathFollow2D
	novo_path_follow.progress = 0.0
	novo_path_follow.set_process(true)

	var inimigo := cena_escolhida.instantiate()

	# Cada inimigo pode ter sua própria velocidade.
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
