extends CanvasLayer

@onready var botao_sozinho: Button =  $VBoxContainer/lan
@onready var botao_criar_servidor: Button = $VBoxContainer/criaServ
@onready var botao_voltar: Button = $VBoxContainer/voltar
@onready var campo_ip: LineEdit = $LineEdit
@onready var label_ip_local: Label = $dadosIP
@onready var label_status: Label = $Label2
@onready var caixa_botoes: VBoxContainer = $VBoxContainer

const CENA_DO_JOGO := "res://cenas/primaria.tscn"
const CENA_LOBBY := "res://cenas/menus/lobby.tscn"


func _ready() -> void:
	# FIX: garante que a árvore não esteja pausada ao entrar nesse menu.
	# Se o jogo veio de um Game Over (controleDeTudo.gd pausa a SceneTree
	# em _executar_fim_de_jogo), sem isso NENHUM botão/tecla responde aqui,
	# porque process_mode padrão dos nós é Inherit e a árvore toda para.
	get_tree().paused = false

	botao_sozinho.pressed.connect(_on_sozinho_pressed)
	botao_criar_servidor.pressed.connect(_on_criar_servidor_pressed)
	botao_voltar.pressed.connect(_on_voltar_pressed)
	campo_ip.text_submitted.connect(_on_ip_ou_codigo_submetido)
	NetworkManager.conectado_ao_servidor.connect(_on_conectado)
	NetworkManager.conexao_falhou.connect(_on_falhou)
	NetworkManager.codigo_nao_encontrado.connect(_on_codigo_nao_encontrado)
	label_status.text = ""
	_mostrar_ip_local()
	NetworkManager.servidor_criado.connect(_on_servidor_criado)

	# Nick já vem definido desde a tela de perfil (boot do jogo), então aqui
	# não precisa perguntar de novo -- só aplica a cor favorita nos botões.
	caixa_botoes.modulate = PerfilJogador.cor_favorita


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		print(">>> clique captado em: ", event.position)


func _mostrar_ip_local() -> void:
	var ips := IP.get_local_addresses()
	var ip_lan := ""
	for endereco in ips:
		if endereco.begins_with("192.168.") or endereco.begins_with("10."):
			ip_lan = endereco
			break
	if ip_lan == "":
		label_ip_local.text = "IP não encontrado (verifique o Wi-Fi)"
	else:
		label_ip_local.text = "Seu IP na rede: %s" % ip_lan


func _on_sozinho_pressed() -> void:
	get_tree().change_scene_to_file(CENA_DO_JOGO)


func _on_criar_servidor_pressed() -> void:
	NetworkManager.criar_servidor()
	label_status.text = "Servidor criado. Aguardando jogadores..."


func _on_ip_ou_codigo_submetido(valor: String) -> void:
	var limpo := valor.strip_edges()
	if limpo == "":
		label_status.text = "Digite um IP ou o código da sala."
		return

	if "." in limpo:
		# Tem ponto -> parece um IP de verdade.
		label_status.text = "Conectando a %s..." % limpo
		NetworkManager.entrar_servidor(limpo)
	else:
		# Sem ponto -> trata como código curto de sala (ex: "ABCD").
		label_status.text = "Procurando sala com código %s..." % limpo.to_upper()
		NetworkManager.entrar_por_codigo(limpo)


func _on_conectado() -> void:
	label_status.text = "Conectado!"
	# FIX: ia direto pro jogo (CENA_DO_JOGO) sem passar por lobby nenhum.
	# Agora todo mundo entra na sala de espera primeiro.
	get_tree().change_scene_to_file(CENA_LOBBY)


func _on_falhou() -> void:
	label_status.text = "Falha ao conectar. Verifique o IP ou o código."


func _on_codigo_nao_encontrado() -> void:
	label_status.text = "Servidor não encontrado."


func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file("res://cenas/menus/menu.tscn")


func _on_servidor_criado() -> void:
	label_status.text = "Servidor criado. Aguardando jogadores..."
	# FIX: ia direto pro jogo (CENA_DO_JOGO) e não dava pra escolher modo
	# nem ver quem conectou. Agora o host cai no lobby.
	get_tree().change_scene_to_file(CENA_LOBBY)
