extends CanvasLayer


var CENA_DO_JOGO = "res://cenas/primaria.tscn"

func _on_re_zero_pressed() -> void:
	
	NetworkManager.criar_servidor()
##	label_status.text = "Servidor criado. Aguardando jogadores..."
	get_tree().change_scene_to_file(CENA_DO_JOGO)
