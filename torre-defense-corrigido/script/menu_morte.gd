extends CanvasLayer

@onready var botao_re_zero: Button = $MarginContainer/VBoxContainer/re_zero

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("menu_morte")
	# Só o host pode reiniciar a partida -- resetar_estado() só tem efeito de
	# verdade quando quem chama é o servidor.
	botao_re_zero.visible = multiplayer.is_server()

func _on_re_zero_pressed() -> void:
	if not multiplayer.is_server():
		return
	# FIX: antes essa função também fazia queue_free()/change_scene_to_file()
	# só localmente, então apenas o host (único que via o botão) saía da tela
	# de derrota -- os clientes ficavam presos nela pra sempre. Agora
	# ControleDeTudo.resetar_estado() cuida de tudo isso via RPC, rodando
	# igual em todo mundo.
	ControleDeTudo.resetar_estado()

func _on_menu_pressed() -> void:
	# Reset local (não precisa avisar a rede -- já estou saindo da sala).
	ControleDeTudo.resetar_estado_local()
	NetworkManager.desconectar()
	queue_free()
	get_tree().change_scene_to_file("res://cenas/menus/menu.tscn")

func _on_sair_do_jogo_pressed() -> void:
	get_tree().paused = false
	queue_free()
	get_tree().quit()
