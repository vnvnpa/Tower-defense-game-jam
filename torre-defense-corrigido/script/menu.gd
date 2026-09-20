extends CanvasLayer

@onready var caixa_botoes: VBoxContainer = $Control/MarginContainer/VBoxContainer


func _ready() -> void:
	caixa_botoes.modulate = PerfilJogador.cor_favorita


func _on_jogar_pressed() -> void:
	# FIX: estava vazio (pass) -- o botão JOGAR não levava a lugar nenhum.
	get_tree().change_scene_to_file("res://cenas/menus/menumultiplayer.tscn")


func _on_credito_pressed() -> void:
	pass # Replace with function body.


func _on_sairdojogo_pressed() -> void:
	get_tree().quit()


func _on_editar_perfil_pressed() -> void:
	PerfilJogador.forcar_tela = true
	get_tree().change_scene_to_file("res://cenas/menus/perfil.tscn")
