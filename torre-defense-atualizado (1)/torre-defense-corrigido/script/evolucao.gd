extends CanvasLayer

## Tela de evolução permanente. Só pode evoluir com moeda lunar (dropada
## por bosses e pelo Rimuru -- ver slime.gd / Progresso.gd). Cada evolução
## some com o dinheiro gasto e o nível fica salvo pra sempre (Progresso
## já cuida de salvar em disco a cada compra).

const CENA_NIVEIS := "res://cenas/menus/niveis.tscn"

@onready var label_moeda_lunar: Label = $MarginContainer/VBoxContainer/LabelMoedaLunar

const CAMINHO_CARDS := "MarginContainer/VBoxContainer/Scroll/Cards/"

@onready var status_moeda: Label = get_node(CAMINHO_CARDS + "CardMoeda/Corpo/Status")
@onready var botao_moeda: Button = get_node(CAMINHO_CARDS + "CardMoeda/Corpo/LinhaAcao/Botao")

@onready var status_agua: Label = get_node(CAMINHO_CARDS + "CardAgua/Corpo/Status")
@onready var botao_agua: Button = get_node(CAMINHO_CARDS + "CardAgua/Corpo/LinhaAcao/Botao")

@onready var status_agua_auto: Label = get_node(CAMINHO_CARDS + "CardAguaAuto/Corpo/Status")
@onready var botao_agua_auto: Button = get_node(CAMINHO_CARDS + "CardAguaAuto/Corpo/LinhaAcao/Botao")

@onready var status_vida: Label = get_node(CAMINHO_CARDS + "CardVida/Corpo/Status")
@onready var botao_vida: Button = get_node(CAMINHO_CARDS + "CardVida/Corpo/LinhaAcao/Botao")

@onready var botao_voltar: Button = $MarginContainer/VBoxContainer/Voltar
@onready var scroll: ScrollContainer = $MarginContainer/VBoxContainer/Scroll


func _ready() -> void:
	get_tree().paused = false

	botao_moeda.pressed.connect(_on_evoluir_moeda_pressed)
	botao_agua.pressed.connect(_on_evoluir_agua_pressed)
	botao_agua_auto.pressed.connect(_on_desbloquear_agua_auto_pressed)
	botao_vida.pressed.connect(_on_evoluir_vida_pressed)
	botao_voltar.pressed.connect(_on_voltar_pressed)

	Progresso.moeda_lunar_atualizada.connect(_on_moeda_lunar_atualizada)

	# Deixa clicar/arrastar em QUALQUER lugar da área de evolução (não só
	# na barrinha de scroll) pra rolar os cards -- os cards/labels/painéis
	# ignoram o mouse (ver mouse_filter=2 em evolucao.tscn) e deixam o
	# evento passar até aqui; só os botões continuam clicáveis normal.
	scroll.gui_input.connect(_on_scroll_gui_input)

	_atualizar_tudo()


func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):

		scroll.scroll_vertical -= int(event.relative.y)

	elif event is InputEventScreenDrag:

		scroll.scroll_vertical -= int(event.relative.y)


func _on_moeda_lunar_atualizada(_quantidade: int) -> void:
	_atualizar_tudo()


func _atualizar_tudo() -> void:
	label_moeda_lunar.text = "Moeda lunar: %d" % Progresso.moeda_lunar
	_atualizar_card_moeda()
	_atualizar_card_agua()
	_atualizar_card_agua_auto()
	_atualizar_card_vida()


func _atualizar_card_moeda() -> void:
	var nivel := Progresso.nivel_evolucao_moeda_inicial
	var maximo := Progresso.MAX_NIVEL_EVOLUCAO

	if nivel >= maximo:
		status_moeda.text = "+%d por partida (nível máximo %d/%d)" % [
			Progresso.moeda_inicial_bonus(), nivel, maximo
		]
		botao_moeda.text = "Máximo"
		botao_moeda.disabled = true
		return

	var custo := Progresso.custo_evolucao_moeda_inicial()

	status_moeda.text = "+%d por partida (nível %d/%d)" % [
		Progresso.moeda_inicial_bonus(), nivel, maximo
	]
	botao_moeda.text = "Evoluir (%d lunar)" % custo
	botao_moeda.disabled = Progresso.moeda_lunar < custo


func _atualizar_card_agua() -> void:
	var nivel := Progresso.nivel_evolucao_agua_maxima
	var maximo := Progresso.MAX_NIVEL_EVOLUCAO

	if nivel >= maximo:
		status_agua.text = "%d (nível máximo %d/%d)" % [
			Progresso.agua_maxima_total(), nivel, maximo
		]
		botao_agua.text = "Máximo"
		botao_agua.disabled = true
		return

	var custo := Progresso.custo_evolucao_agua_maxima()

	status_agua.text = "%d (nível %d/%d)" % [
		Progresso.agua_maxima_total(), nivel, maximo
	]
	botao_agua.text = "Evoluir (%d lunar)" % custo
	botao_agua.disabled = Progresso.moeda_lunar < custo


func _atualizar_card_agua_auto() -> void:
	if Progresso.agua_automatica_desbloqueada:
		status_agua_auto.text = "Desbloqueada"
		botao_agua_auto.text = "Desbloqueada"
		botao_agua_auto.disabled = true
		return

	status_agua_auto.text = "Bloqueado"
	botao_agua_auto.text = "Desbloquear (%d lunar)" % Progresso.CUSTO_AGUA_AUTOMATICA
	botao_agua_auto.disabled = Progresso.moeda_lunar < Progresso.CUSTO_AGUA_AUTOMATICA


func _atualizar_card_vida() -> void:
	var nivel := Progresso.nivel_evolucao_vida
	var maximo := Progresso.MAX_NIVEL_EVOLUCAO

	if nivel >= maximo:
		status_vida.text = "+%d vida (nível máximo %d/%d)" % [
			Progresso.vida_bonus(), nivel, maximo
		]
		botao_vida.text = "Máximo"
		botao_vida.disabled = true
		return

	var custo := Progresso.custo_evolucao_vida()

	status_vida.text = "+%d vida (nível %d/%d)" % [
		Progresso.vida_bonus(), nivel, maximo
	]
	botao_vida.text = "Evoluir (%d lunar)" % custo
	botao_vida.disabled = Progresso.moeda_lunar < custo


func _on_evoluir_moeda_pressed() -> void:
	Progresso.evoluir_moeda_inicial()
	_atualizar_tudo()


func _on_evoluir_agua_pressed() -> void:
	Progresso.evoluir_agua_maxima()
	_atualizar_tudo()


func _on_desbloquear_agua_auto_pressed() -> void:
	Progresso.desbloquear_agua_automatica()
	_atualizar_tudo()


func _on_evoluir_vida_pressed() -> void:
	Progresso.evoluir_vida()
	_atualizar_tudo()


func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file(CENA_NIVEIS)
