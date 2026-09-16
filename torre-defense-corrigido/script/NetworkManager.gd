extends Node

# ============================================================
# NetworkManager - Autoload para multiplayer (Godot 4)
# ============================================================
# Ele cuida SÓ da camada de rede. O ControleDeTudo continua
# cuidando do estado do jogo (vida, coin, etc), mas agora só o HOST
# (peer com autoridade) pode alterar valores compartilhados,
# através das funções gastar_coin() / ganhar_coin() / perder_vida()
# que já deixamos autoritativas nele.
# ============================================================

const PORTA := 7777
const MAX_JOGADORES := 4

var peer: ENetMultiplayerPeer

signal jogador_conectou(id: int)
signal jogador_desconectou(id: int)
signal conexao_falhou
signal conectado_ao_servidor
signal servidor_criado
signal lista_jogadores_atualizada
signal modo_de_jogo_atualizado(modo: String)
signal partida_iniciada

var jogadores := {} # id -> nome
var modo_de_jogo := "classico"
var sala_travada := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ------------------------------------------------------------
# CRIAR SERVIDOR (host)
# ------------------------------------------------------------
func criar_servidor() -> void:
	peer = ENetMultiplayerPeer.new()
	var erro := peer.create_server(PORTA, MAX_JOGADORES)
	if erro != OK:
		push_error("Falha ao criar servidor: %s" % erro)
		return

	multiplayer.multiplayer_peer = peer
	sala_travada = false
	modo_de_jogo = "classico"
	jogadores = {1: "Host"} # id 1 é sempre o servidor
	servidor_criado.emit()
	print("Servidor criado na porta %d" % PORTA)


# ------------------------------------------------------------
# ENTRAR COMO CLIENTE
# ------------------------------------------------------------
func entrar_servidor(ip: String) -> void:
	peer = ENetMultiplayerPeer.new()
	var erro := peer.create_client(ip, PORTA)
	if erro != OK:
		push_error("Falha ao conectar: %s" % erro)
		return

	multiplayer.multiplayer_peer = peer
	print("Tentando conectar a %s..." % ip)


func desconectar() -> void:
	if peer:
		peer.close()
	peer = null
	jogadores.clear()
	sala_travada = false


# ------------------------------------------------------------
# CALLBACKS DE CONEXÃO
# ------------------------------------------------------------
func _on_peer_connected(id: int) -> void:
	print("Jogador conectou: %d" % id)
	jogador_conectou.emit(id)
	# Se eu sou o host, registro o novo jogador e mando pra ele o estado
	# atual do jogo + a lista de jogadores + o modo escolhido.
	if multiplayer.is_server():
		jogadores[id] = "Jogador %d" % id
		_sincronizar_estado_para.rpc_id(id, ControleDeTudo.vida, ControleDeTudo.coin)
		_sincronizar_lista_jogadores.rpc(jogadores)
		_sincronizar_modo.rpc(modo_de_jogo)


func _on_peer_disconnected(id: int) -> void:
	print("Jogador saiu: %d" % id)
	jogador_desconectou.emit(id)
	if multiplayer.is_server():
		jogadores.erase(id)
		_sincronizar_lista_jogadores.rpc(jogadores)


func _on_connected_ok() -> void:
	print("Conectado ao servidor!")
	conectado_ao_servidor.emit()


func _on_connection_failed() -> void:
	push_error("Não foi possível conectar ao servidor.")
	conexao_falhou.emit()
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	push_error("Servidor desconectou.")
	multiplayer.multiplayer_peer = null


# ------------------------------------------------------------
# SINCRONIZAÇÃO DE ESTADO (host -> cliente que acabou de entrar)
# ------------------------------------------------------------
@rpc("authority", "call_remote", "reliable")
func _sincronizar_estado_para(vida: int, coin: int) -> void:
	ControleDeTudo.vida = vida
	ControleDeTudo.coin = coin


# ------------------------------------------------------------
# LOBBY: lista de jogadores, modo de jogo e travar a sala
# ------------------------------------------------------------
@rpc("authority", "call_local", "reliable")
func _sincronizar_lista_jogadores(nova_lista: Dictionary) -> void:
	jogadores = nova_lista
	lista_jogadores_atualizada.emit()


func definir_modo_de_jogo(modo: String) -> void:
	if not multiplayer.is_server():
		return
	modo_de_jogo = modo
	_sincronizar_modo.rpc(modo)


@rpc("authority", "call_local", "reliable")
func _sincronizar_modo(modo: String) -> void:
	modo_de_jogo = modo
	modo_de_jogo_atualizado.emit(modo)


func travar_sala() -> void:
	if not multiplayer.is_server():
		return
	if peer:
		peer.refuse_new_connections = true
	sala_travada = true


func iniciar_partida() -> void:
	if not multiplayer.is_server():
		return
	travar_sala() # a partir daqui, ninguém mais entra na sala
	ControleDeTudo.resetar_estado()
	_iniciar_partida.rpc()


@rpc("authority", "call_local", "reliable")
func _iniciar_partida() -> void:
	partida_iniciada.emit()


# ------------------------------------------------------------
# SPAWN DE TORRE AUTORITATIVO
# ------------------------------------------------------------
# Fluxo:
# 1. Cliente arrasta a torre (preview instanciado pela loja) e solta
# 2. O clique roda LOCAL primeiro (atiradores.gd -> colocar()) e manda
#    o pedido pro servidor via RPC "any_peer" (rpc_id(1, ...))
# 3. Só quem tem is_server() == true realmente valida e decide
# 4. Se validado, o servidor chama spawnar_torre.rpc() pra
#    instanciar a torre "oficial" em TODOS os peers (incluindo ele mesmo)
# ------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func pedir_spawn_torre(tipo_torre: String, cena_torre: String, posicao: Vector2) -> void:
	# Só o servidor processa a validação
	if not multiplayer.is_server():
		return

	var custo := _custo_da_torre(tipo_torre)

	if not ControleDeTudo.gastar_coin(custo):
		# sem grana: avisa só quem pediu
		var id_solicitante := multiplayer.get_remote_sender_id()
		if id_solicitante != 0:
			_spawn_negado.rpc_id(id_solicitante)
		return

	# Validado (coin já foi descontado e sincronizado por gastar_coin): replica o spawn
	spawnar_torre.rpc(cena_torre, posicao)


@rpc("authority", "call_local", "reliable")
func spawnar_torre(cena_torre: String, posicao: Vector2) -> void:
	# Roda em TODOS os peers (inclusive o host): instancia a torre de verdade.
	var cena: PackedScene = load(cena_torre)
	if cena == null:
		push_error("Cena de torre inválida: %s" % cena_torre)
		return

	var torre = cena.instantiate()
	# FIX (race condition): setar isso ANTES do add_child, pois o _ready()
	# de atiradores.gd só decide o "monitorable" da torre quando resume do
	# seu próprio await, e nessa hora ele já vai ler arrastando = false.
	torre.arrastando = false # já chega fixada, não segue mais o mouse
	get_tree().current_scene.add_child(torre)
	torre.global_position = posicao


@rpc("authority", "call_remote", "reliable")
func _spawn_negado() -> void:
	# Roda só no cliente que pediu e foi negado
	ControleDeTudo.invalido.emit()


func _custo_da_torre(tipo: String) -> int:
	# Ajuste conforme sua tabela de custos real
	match tipo:
		"basica":
			return 10
		"canhao":
			return 25
		_:
			return 999999


# ------------------------------------------------------------
# DANO AUTORITATIVO EM INIMIGO
# ------------------------------------------------------------
@rpc("any_peer", "call_local", "reliable")
func pedir_dano_inimigo(caminho_inimigo: NodePath, dano: int) -> void:
	if not multiplayer.is_server():
		return

	var inimigo := get_node_or_null(caminho_inimigo)
	if inimigo == null:
		return

	aplicar_dano_inimigo.rpc(caminho_inimigo, dano)


@rpc("authority", "call_local", "reliable")
func aplicar_dano_inimigo(caminho_inimigo: NodePath, dano: int) -> void:
	var inimigo := get_node_or_null(caminho_inimigo)
	if inimigo and inimigo.has_method("tomar_dano"):
		inimigo.tomar_dano(dano)
