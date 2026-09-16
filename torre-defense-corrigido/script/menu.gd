extends CanvasLayer


func _on_jogar_pressed() -> void:
	# FIX: estava vazio (pass) -- o botão JOGAR não levava a lugar nenhum.
	get_tree().change_scene_to_file("res://cenas/canvas_layer.tscn")


func _on_credito_pressed() -> void:
	pass # Replace with function body.


func _on_sairdojogo_pressed() -> void:
	get_tree().quit()
