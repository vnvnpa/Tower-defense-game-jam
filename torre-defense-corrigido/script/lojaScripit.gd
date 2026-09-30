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
@export var tipo_torre: String = "mangueira"
@export var custo: int = 10

# ------------------------------------------------------------
# Torre 2 -- Irrigador Giratório
# ------------------------------------------------------------
@export var atirador_scene_2: PackedScene
@export var tipo_torre_2: String = "irrigador"
@export var custo_2: int = 20

# ------------------------------------------------------------
# Torre 3 -- Mangueira Prime (1 moeda lunar, sem opção de ouro)
# ------------------------------------------------------------
@export var atirador_scene_3: PackedScene
@export var tipo_torre_3: String = "mangueira_prime"
# Prime só é comprada com moeda lunar -- ver custo_lunar na própria cena
# da torre (mangueira-prime.tscn). Esse "custo" fica só de referência.
@export var custo_3: int = 0
@export var custo_lunar_3: int = 1

# ------------------------------------------------------------
# Torre 4 -- Irrigador Giratório Prime (2 moedas lunares, sem opção de ouro)
# ------------------------------------------------------------
@export var atirador_scene_4: PackedScene
@export var tipo_torre_4: String = "irrigador_prime"
@export var custo_4: int = 0
@export var custo_lunar_4: int = 2

@onready var botao_1: TextureButton = $Control/TextureButton
@onready var botao_2: TextureButton = $Control/TextureButton2
@onready var botao_3: TextureButton = $Control/TextureButton3
@onready var botao_4: TextureButton = $Control/TextureButton4
@onready var botao_agua: TextureButton = $Control/TextureButton5


func _ready() -> void:
	# Cada botão ganha um rótulo (nome + preço) e, se a torre ainda não foi
	# liberada pelo nível atual (regra do GDD), fica travado.
	_configurar_botao(botao_1, tipo_torre, "Mangueira\n%d" % custo)
	_configurar_botao(botao_2, tipo_torre_2, "Irrigador\n%d" % custo_2)
	_configurar_botao(botao_3, tipo_torre_3, "Mang. Prime\n%d lunar" % custo_lunar_3)
	_configurar_botao(botao_4, tipo_torre_4, "Irrig. Prime\n%d lunar" % custo_lunar_4)

	var texto_agua := "Água +%d L\n%d" % [
		ControleDeTudo.AGUA_LITROS_POR_COMPRA,
		ControleDeTudo.AGUA_CUSTO_COMPRA
	]
	_criar_rotulo(botao_agua, texto_agua)

	# Nível 1 não tem gasto de água, então também não tem compra de água.
	if not ControleDeTudo.agua_ativa():
		_travar(botao_agua, "Água a partir do nível %d" % ControleDeTudo.NIVEL_INICIO_AGUA)


func _configurar_botao(botao: TextureButton, tipo: String, texto: String) -> void:
	if ControleDeTudo.torre_liberada(tipo):
		_criar_rotulo(botao, texto)
	else:
		var nivel := ControleDeTudo.nivel_que_libera(tipo)
		_criar_rotulo(botao, "Nível %d" % nivel)
		_travar(botao, "Liberada no nível %d" % nivel)


func _criar_rotulo(botao: TextureButton, texto: String) -> void:
	var rotulo := Label.new()
	rotulo.text = texto
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	rotulo.add_theme_font_size_override("font_size", 15)
	rotulo.add_theme_color_override("font_color", Color.WHITE)
	rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	rotulo.add_theme_constant_override("outline_size", 6)
	rotulo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	botao.add_child(rotulo)


func _travar(botao: TextureButton, dica: String) -> void:
	botao.disabled = true
	botao.modulate = botao.modulate * Color(0.35, 0.35, 0.35, 1.0)
	botao.tooltip_text = dica


func _on_texture_button_pressed() -> void:
	_comprar(atirador_scene, tipo_torre, custo)


func _on_texture_button_2_pressed() -> void:
	_comprar(atirador_scene_2, tipo_torre_2, custo_2)


func _on_texture_button_3_pressed() -> void:
	_comprar(atirador_scene_3, tipo_torre_3, custo_3)


func _on_texture_button_4_pressed() -> void:
	_comprar(atirador_scene_4, tipo_torre_4, custo_4)


func _on_texture_button_5_pressed() -> void:
	if not ControleDeTudo.comprar_agua():
		ControleDeTudo.invalido.emit()


# Cria um PREVIEW local da cena da torre (ela já sabe seguir o mouse até o
# clique, ver atiradores.gd). O clique só mostra o painel de confirmação
# com as informações da torre -- quem realmente gasta a moeda e fixa a
# torre é o próprio painel (ver colocar()/_on_confirmar_colocacao() em
# atiradores.gd).
func _comprar(cena: PackedScene, tipo: String, valor: int) -> void:
	if cena == null or not ControleDeTudo.torre_liberada(tipo):
		return

	var preview = cena.instantiate()
	preview.tipo_torre = tipo
	preview.custo = valor
	get_tree().current_scene.add_child(preview)
	fechar_abrirLoja()
