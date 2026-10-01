extends CanvasLayer

const CENA_NIVEIS := "res://cenas/menus/niveis.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_continuar_pressed() -> void:
	ControleDeTudo.resetar_estado_local()
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file(CENA_NIVEIS)


func _on_sair_do_jogo_pressed() -> void:
	get_tree().paused = false
	queue_free()
	get_tree().quit()
