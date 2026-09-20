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
const PORTA_DESCOBERTA := 7778 # usada só pra "traduzir" o código da sala num IP
const TEMPO_LIMITE_CONEXAO := 6.0 # segundos até desistir e avisar "não encontrado"

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

var meu_nick := "Jogador"
var saindo_de_proposito := false # true enquanto EU mesmo estou me desconectando

signal perdeu_conexao # servidor caiu/sumiu sem eu ter pedido pra sair

# ------------------------------------------------------------
# CÓDIGO DA SALA (host) e busca por código (cliente)
# ------------------------------------------------------------
# Como não existe servidor de matchmaking, o "código" só funciona pra quem
# está na mesma rede local: o host anuncia periodicamente um pacote UDP por
# broadcast dizendo "minha sala é essa aqui, código tal", e quem está
# procurando aquele código escuta esse broadcast e descobre o IP do host
# sozinho, sem precisar digitar IP nenhum.
var codigo_sala := ""
var _udp_anuncio: PacketPeerUDP
var _acumulador_anuncio := 0.0

var _udp_busca: PacketPeerUDP
var _codigo_procurado := ""
var _tempo_busca_restante := 0.0

signal codigo_nao_encontrado


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _process(delta: float) -> void:
	# HOST: anuncia a sala por broadcast pra quem estiver procurando o código
	if peer and multiplayer.is_server() and codigo_sala != "" and not sala_travada:
		_acumulador_anuncio += delta
		if _acumulador_anuncio >= 1.0:
			_acumulador_anuncio = 0.0
			if _udp_anuncio:
				_udp_anuncio.set_dest_address("255.255.255.255", PORTA_DESCOBERTA)
				_udp_anuncio.put_packet(("TD;%s" % codigo_sala).to_utf8_buffer())

	# CLIENTE: procurando um código específico
	if _codigo_procurado != "" and _udp_busca:
		while _udp_busca.get_available_packet_count() > 0:
			var pacote := _udp_busca.get_packet()
			var ip_remetente := _udp_busca.get_packet_ip()
			var texto := pacote.get_string_from_utf8()
			var partes := texto.split(";")
			if partes.size() == 2 and partes[0] == "TD" and partes[1] == _codigo_procurado:
				_parar_busca()
				entrar_servidor(ip_remetente)
				return
		_tempo_busca_restante -= delta
		if _tempo_busca_restante <= 0.0:
			_parar_busca()
			codigo_nao_encontrado.emit()


# ------------------------------------------------------------
# NICKNAME
# ------------------------------------------------------------
func definir_nick(nick: String) -> void:
	var limpo := nick.strip_edges()
	if limpo.length() > 16:
		limpo = limpo.substr(0, 16)
	if limpo == "":
		limpo = "Jogador"
	meu_nick = limpo


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
	jogadores = {1: meu_nick} # id 1 é sempre o servidor, já com o nick escolhido

	codigo_sala = _gerar_codigo_sala()
	_udp_anuncio = PacketPeerUDP.new()
	_udp_anuncio.set_broadcast_enabled(true)
	_acumulador_anuncio = 0.0

	servidor_criado.emit()
	print("Servidor criado na porta %d, código da sala: %s" % [PORTA, codigo_sala])


func _gerar_codigo_sala() -> String:
	# Sem O/0/I/1 pra não confundir na hora de digitar.
	const CARACTERES := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
	var codigo := ""
	for i in range(4):
		codigo += CARACTERES[randi() % CARACTERES.length()]
	return codigo


# ------------------------------------------------------------
# ENTRAR COMO CLIENTE (por IP direto)
# ------------------------------------------------------------
func entrar_servidor(ip: String) -> void:
	peer = ENetMultiplayerPeer.new()
	var erro := peer.create_client(ip, PORTA)
	if erro != OK:
		push_error("Falha ao conectar: %s" % erro)
		conexao_falhou.emit()
		return

	multiplayer.multiplayer_peer = peer
	print("Tentando conectar a %s..." % ip)
	_vigiar_tempo_limite_de_conexao(peer)


func _vigiar_tempo_limite_de_conexao(peer_da_tentativa: ENetMultiplayerPeer) -> void:
	# Watchdog manual: se depois de alguns segundos a gente não conectou nem
	# recebeu um "falhou" oficial do ENet, desiste sozinho em vez de deixar
	# a tela travada pra sempre em "Conectando..." (o timeout nativo do ENet
	# pode demorar bem mais que isso, ou nem disparar em alguns casos de IP
	# inexistente na rede).
	await get_tree().create_timer(TEMPO_LIMITE_CONEXAO).timeout
	if peer != peer_da_tentativa:
		return # já trocou de peer nesse meio tempo, essa tentativa não conta mais
	if multiplayer.multiplayer_peer != peer_da_tentativa:
		return # já foi resolvido (conectou ou já falhou oficialmente)
	if peer_da_tentativa.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return # conectou a tempo, tudo certo

	push_error("Tempo esgotado tentando conectar.")
	desconectar()
	conexao_falhou.emit()


# ------------------------------------------------------------
# ENTRAR COMO CLIENTE (por código da sala, via LAN)
# ------------------------------------------------------------
func entrar_por_codigo(codigo: String) -> void:
	var limpo := codigo.strip_edges().to_upper()
	if limpo == "":
		return

	_parar_busca() # cancela uma busca anterior, se tinha alguma rolando

	_codigo_procurado = limpo
	_tempo_busca_restante = TEMPO_LIMITE_CONEXAO

	_udp_busca = PacketPeerUDP.new()
	var erro := _udp_busca.bind(PORTA_DESCOBERTA)
	if erro != OK:
		push_error("Não consegui abrir a porta de busca: %s" % erro)
		_codigo_procurado = ""
		codigo_nao_encontrado.emit()


func _parar_busca() -> void:
	_codigo_procurado = ""
	if _udp_busca:
		_udp_busca.close()
		_udp_busca = null


func desconectar() -> void:
	# FIX: marcamos que a saída é intencional e soltamos a referência do peer
	# em multiplayer.multiplayer_peer ANTES de fechar. Se a gente chama
	# peer.close() enquanto ele ainda está atribuído, o Godot detecta a queda
	# da conexão e dispara server_disconnected mesmo sem ninguém ter caído de
	# verdade -- por isso o "erro" aparecia todo santo dia que se apertava
	# "voltar". Soltando a referência primeiro, o polling da API não chega
	# a rodar de novo em cima desse peer e o sinal não dispara à toa.
	saindo_de_proposito = true
	multiplayer.multiplayer_peer = null
	if peer:
		peer.close()
	peer = null
	jogadores.clear()
	sala_travada = false

	codigo_sala = ""
	if _udp_anuncio:
		_udp_anuncio.close()
		_udp_anuncio = null
	_parar_busca()

	saindo_de_proposito = false


# ------------------------------------------------------------
# CALLBACKS DE CONEXÃO
# ------------------------------------------------------------
func _on_peer_connected(id: int) -> void:
	print("Jogador conectou: %d" % id)
	jogador_conectou.emit(id)
	# Se eu sou o host, registro o novo jogador e mando pra ele o estado
	# atual do jogo + a lista de jogadores + o modo escolhido + o código da sala.
	if multiplayer.is_server():
		jogadores[id] = "Jogador %d" % id
		_sincronizar_estado_para.rpc_id(id, ControleDeTudo.vida, ControleDeTudo.coin)
		_sincronizar_lista_jogadores.rpc(jogadores)
		_sincronizar_modo.rpc(modo_de_jogo)
		_sincronizar_codigo.rpc_id(id, codigo_sala)


func _on_peer_disconnected(id: int) -> void:
	print("Jogador saiu: %d" % id)
	jogador_desconectou.emit(id)
	if multiplayer.is_server():
		jogadores.erase(id)
		_sincronizar_lista_jogadores.rpc(jogadores)


func _on_connected_ok() -> void:
	print("Conectado ao servidor!")
	# Assim que a conexão é confirmada, mando meu nick pro host se registrar
	# na lista de jogadores (só o host sabe meu id nesse ponto).
	registrar_nick.rpc_id(1, meu_nick)
	conectado_ao_servidor.emit()


func _on_connection_failed() -> void:
	push_error("Não foi possível conectar ao servidor.")
	conexao_falhou.emit()
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	if saindo_de_proposito:
		# Fui eu que saí (botão "voltar"). Normal, não é erro.
		print("Desconectado do servidor (saída intencional).")
	else:
		# O servidor caiu/sumiu sem eu ter pedido. Aí sim é um problema de verdade.
		push_error("Servidor desconectou.")
		jogadores.clear()
		sala_travada = false
		perdeu_conexao.emit()


# ------------------------------------------------------------
# SINCRONIZAÇÃO DE ESTADO (host -> cliente que acabou de entrar)
# ------------------------------------------------------------
@rpc("authority", "call_remote", "reliable")
func _sincronizar_estado_para(vida: int, coin: int) -> void:
	ControleDeTudo.vida = vida
	ControleDeTudo.coin = coin


@rpc("authority", "call_remote", "reliable")
func _sincronizar_codigo(codigo: String) -> void:
	# O cliente não precisa do código pra nada funcional (já está conectado),
	# mas assim o lobby consegue mostrar/compartilhar o mesmo código pra todo mundo.
	codigo_sala = codigo


# ------------------------------------------------------------
# LOBBY: nickname, lista de jogadores, modo de jogo e travar a sala
# ------------------------------------------------------------
@rpc("any_peer", "call_remote", "reliable")
func registrar_nick(nick: String) -> void:
	# Só o servidor decide os nomes de verdade (evita cliente mentir o id de outro).
	if not multiplayer.is_server():
		return

	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		return

	var limpo := nick.strip_edges()
	if limpo.length() > 16:
		limpo = limpo.substr(0, 16)
	if limpo == "":
		limpo = "Jogador %d" % id

	jogadores[id] = limpo
	_sincronizar_lista_jogadores.rpc(jogadores)


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
