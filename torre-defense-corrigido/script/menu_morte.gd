extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_re_zero_pressed() -> void:
	get_tree().paused = false
	ControleDeTudo.resetar_estado()
	queue_free()
	get_tree().change_scene_to_file(ControleDeTudo.cenaAtual)

func _on_menu_pressed() -> void:
	get_tree().paused = false
	ControleDeTudo.resetar_estado()
	queue_free()
	get_tree().change_scene_to_file("res://cenas/menu.tscn")

func _on_sair_do_jogo_pressed() -> void:
	get_tree().paused = false
	queue_free()
	get_tree().quit()
