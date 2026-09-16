extends CanvasLayer

@onready var botao_sozinho: Button =  $VBoxContainer/lan
@onready var botao_criar_servidor: Button = $VBoxContainer/criaServ
@onready var botao_voltar: Button = $VBoxContainer/voltar
@onready var campo_ip: LineEdit = $LineEdit
@onready var label_ip_local: Label = $dadosIP
@onready var label_status: Label = $Label2

const CENA_DO_JOGO := "res://cenas/primaria.tscn"
const CENA_LOBBY := "res://cenas/lobby.tscn"


func _ready() -> void:
	# FIX: garante que a árvore não esteja pausada ao entrar nesse menu.
	# Se o jogo veio de um Game Over (controleDeTudo.gd pausa a SceneTree
	# em _executar_fim_de_jogo), sem isso NENHUM botão/tecla responde aqui,
	# porque process_mode padrão dos nós é Inherit e a árvore toda para.
	get_tree().paused = false

	print(">>> _ready rodou de novo")
	botao_sozinho.pressed.connect(_on_sozinho_pressed)

	botao_criar_servidor.pressed.connect(_on_criar_servidor_pressed)
	botao_voltar.pressed.connect(_on_voltar_pressed)
	campo_ip.text_submitted.connect(_on_ip_submetido)
	NetworkManager.conectado_ao_servidor.connect(_on_conectado)
	NetworkManager.conexao_falhou.connect(_on_falhou)
	label_status.text = ""
	_mostrar_ip_local()
	NetworkManager.servidor_criado.connect(_on_servidor_criado)



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
	print(">>> cliquei em sozinho")
	get_tree().change_scene_to_file(CENA_DO_JOGO)


func _on_criar_servidor_pressed() -> void:
	
	NetworkManager.criar_servidor()
	label_status.text = "Servidor criado. Aguardando jogadores..."



func _on_ip_submetido(ip: String) -> void:
	if ip.strip_edges() == "":
		label_status.text = "Digite um IP válido."
		return
	label_status.text = "Conectando a %s..." % ip
	NetworkManager.entrar_servidor(ip)


func _on_conectado() -> void:
	label_status.text = "Conectado!"
	# FIX: ia direto pro jogo (CENA_DO_JOGO) sem passar por lobby nenhum.
	# Agora todo mundo entra na sala de espera primeiro.
	get_tree().change_scene_to_file(CENA_LOBBY)


func _on_falhou() -> void:
	label_status.text = "Falha ao conectar. Verifique o IP."


func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file("res://cenas/menu.tscn")



func _on_servidor_criado() -> void:
	label_status.text = "Servidor criado. Aguardando jogadores..."
	# FIX: ia direto pro jogo (CENA_DO_JOGO) e não dava pra escolher modo
	# nem ver quem conectou. Agora o host cai no lobby.
	get_tree().change_scene_to_file(CENA_LOBBY)
