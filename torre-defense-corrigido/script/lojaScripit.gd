extends CanvasLayer
var pressed = false

func _on_button_pressed() -> void:
	fechar_abrirLoja()

func fechar_abrirLoja():
	if pressed:
		offset.y += 200
		pressed = false
	else:
		offset.y += -200
		pressed = true

@export var atirador_scene: PackedScene
@export var tipo_torre: String = "basica"
@export var custo: int = 10

func _on_texture_button_pressed() -> void:
	# Cria um PREVIEW local da cena da torre (ela já sabe seguir o mouse até
	# o clique, ver atiradores.gd); o próprio clique confirma a compra e
	# fixa a torre no lugar (sem rede, tudo local).
	var preview = atirador_scene.instantiate()
	preview.tipo_torre = tipo_torre
	preview.custo = custo
	get_tree().current_scene.add_child(preview)
	fechar_abrirLoja()
