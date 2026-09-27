extends Control

## Tela de abertura do jogo: "vnvnpa" surge do escuro no centro; assim que
## fica 100% visível, "Production" (canto superior, meio pra esquerda) e o
## crédito "Anthropic" (rodapé, pequeno) aparecem juntos. Dura menos de
## 8 segundos no total e daí troca pra tela de perfil. Pode ser pulada com
## qualquer clique/tecla/toque.

const PROXIMA_CENA := "res://cenas/menus/perfil.tscn"

@onready var label_vnvnpa: Label = $LabelVnvnpa
@onready var label_production: Label = $LabelProduction
@onready var rodape_anthropic: HBoxContainer = $RodapeAnthropic

var _ja_trocou_de_cena: bool = false


func _ready() -> void:

	label_vnvnpa.modulate.a = 0.0
	label_production.modulate.a = 0.0
	rodape_anthropic.modulate.a = 0.0

	_tocar_intro()


func _tocar_intro() -> void:

	var tween: Tween = create_tween()

	# "vnvnpa" surge do escuro, no centro da tela.
	tween.tween_property(label_vnvnpa, "modulate:a", 1.0, 2.0)

	# Só depois que "vnvnpa" está 100% visível é que "Production" e o
	# crédito "Anthropic" começam a aparecer, os dois ao mesmo tempo.
	tween.tween_property(label_production, "modulate:a", 1.0, 1.2)
	tween.parallel().tween_property(rodape_anthropic, "modulate:a", 1.0, 1.2)

	# Segura tudo visível por um instante antes de sumir.
	tween.tween_interval(2.3)

	# Fade out geral (~6.3s no total) e troca de cena.
	tween.tween_property(self, "modulate:a", 0.0, 0.8)

	tween.tween_callback(_ir_para_proxima_cena)


func _ir_para_proxima_cena() -> void:

	if _ja_trocou_de_cena:
		return

	_ja_trocou_de_cena = true

	get_tree().change_scene_to_file(PROXIMA_CENA)


func _unhandled_input(event: InputEvent) -> void:

	# Deixa pular a intro com qualquer clique, tecla ou toque.
	var pediu_pular: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventKey and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)

	if pediu_pular:
		_ir_para_proxima_cena()
