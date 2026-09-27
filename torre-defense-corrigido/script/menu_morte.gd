extends CanvasLayer

@onready var botao_re_zero: Button = $MarginContainer/VBoxContainer/re_zero

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("menu_morte")
	botao_re_zero.visible = true

func _on_re_zero_pressed() -> void:
	ControleDeTudo.resetar_estado()

func _on_menu_pressed() -> void:
	ControleDeTudo.resetar_estado_local()
	NetworkManager.desconectar()
	queue_free()
	get_tree().change_scene_to_file("res://cenas/menus/menu.tscn")

func _on_sair_do_jogo_pressed() -> void:
	get_tree().paused = false
	queue_free()
	get_tree().quit()
