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

# ------------------------------------------------------------
# Torre 1 -- Mangueira
# ------------------------------------------------------------
@export var atirador_scene: PackedScene
@export var tipo_torre: String = "basica"
@export var custo: int = 10

# ------------------------------------------------------------
# Torre 2 -- Irrigador Giratório
# ------------------------------------------------------------
@export var atirador_scene_2: PackedScene
@export var tipo_torre_2: String = "irrigador"
@export var custo_2: int = 20


func _on_texture_button_pressed() -> void:
	_comprar(atirador_scene, tipo_torre, custo)


func _on_texture_button_2_pressed() -> void:
	_comprar(atirador_scene_2, tipo_torre_2, custo_2)


# Cria um PREVIEW local da cena da torre (ela já sabe seguir o mouse até o
# clique, ver atiradores.gd). O clique só mostra o painel de confirmação
# com as informações da torre -- quem realmente gasta a moeda e fixa a
# torre é o próprio painel (ver colocar()/_on_confirmar_colocacao() em
# atiradores.gd).
func _comprar(cena: PackedScene, tipo: String, valor: int) -> void:
	if cena == null:
		return

	var preview = cena.instantiate()
	preview.tipo_torre = tipo
	preview.custo = valor
	get_tree().current_scene.add_child(preview)
	fechar_abrirLoja()
