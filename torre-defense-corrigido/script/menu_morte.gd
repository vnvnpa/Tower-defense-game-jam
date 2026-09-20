extends CanvasLayer

@onready var botao_re_zero: Button = $MarginContainer/VBoxContainer/re_zero

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Só o host pode reiniciar a partida -- resetar_estado() só tem efeito de
	# verdade quando quem chama é o servidor, então nem faz sentido o cliente
	# ver esse botão (ele apareceria funcionando, mas não reseta nada de fato).
	botao_re_zero.visible = multiplayer.is_server()

func _on_re_zero_pressed() -> void:
	if not multiplayer.is_server():
		return
	get_tree().paused = false
	ControleDeTudo.resetar_estado()
	queue_free()
	get_tree().change_scene_to_file(ControleDeTudo.cenaAtual)

func _on_menu_pressed() -> void:
	get_tree().paused = false
	ControleDeTudo.resetar_estado()
	# FIX: o caminho estava desatualizado (res://cenas/menu.tscn) de quando o
	# menu.tscn foi movido pra dentro de cenas/menus/. Corrigido pro caminho real.
	NetworkManager.desconectar()
	queue_free()
	get_tree().change_scene_to_file("res://cenas/menus/menu.tscn")

func _on_sair_do_jogo_pressed() -> void:
	get_tree().paused = false
	queue_free()
	get_tree().quit()
