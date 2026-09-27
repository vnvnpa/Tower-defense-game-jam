extends CanvasLayer

## Tela de evolução permanente. Só pode evoluir com moeda lunar (dropada
## por bosses e pelo Rimuru -- ver slime.gd / Progresso.gd). Cada evolução
## some com o dinheiro gasto e o nível fica salvo pra sempre (Progresso
## já cuida de salvar em disco a cada compra).

const CENA_NIVEIS := "res://cenas/menus/niveis.tscn"

@onready var label_moeda_lunar: Label = $MarginContainer/VBoxContainer/LabelMoedaLunar

@onready var label_moeda_inicial: Label = $MarginContainer/VBoxContainer/LinhaMoeda/LabelMoedaInicial
@onready var botao_evoluir_moeda: Button = $MarginContainer/VBoxContainer/LinhaMoeda/BotaoEvoluirMoeda

@onready var label_agua: Label = $MarginContainer/VBoxContainer/LinhaAgua/LabelAgua
@onready var botao_evoluir_agua: Button = $MarginContainer/VBoxContainer/LinhaAgua/BotaoEvoluirAgua

@onready var botao_voltar: Button = $MarginContainer/VBoxContainer/Voltar


func _ready() -> void:
	get_tree().paused = false

	botao_evoluir_moeda.pressed.connect(_on_evoluir_moeda_pressed)
	botao_evoluir_agua.pressed.connect(_on_evoluir_agua_pressed)
	botao_voltar.pressed.connect(_on_voltar_pressed)

	Progresso.moeda_lunar_atualizada.connect(_on_moeda_lunar_atualizada)

	_atualizar_tudo()


func _on_moeda_lunar_atualizada(_quantidade: int) -> void:
	_atualizar_tudo()


func _atualizar_tudo() -> void:
	label_moeda_lunar.text = "Moeda lunar: %d" % Progresso.moeda_lunar
	_atualizar_linha_moeda()
	_atualizar_linha_agua()


func _atualizar_linha_moeda() -> void:
	var nivel := Progresso.nivel_evolucao_moeda_inicial
	var maximo := Progresso.MAX_NIVEL_EVOLUCAO

	if nivel >= maximo:
		label_moeda_inicial.text = (
			"Moeda inicial: +%d por partida (nível máximo %d/%d)"
			% [Progresso.moeda_inicial_bonus(), nivel, maximo]
		)
		botao_evoluir_moeda.text = "Máximo"
		botao_evoluir_moeda.disabled = true
		return

	var custo := Progresso.custo_evolucao_moeda_inicial()

	label_moeda_inicial.text = (
		"Moeda inicial: +%d por partida (nível %d/%d)"
		% [Progresso.moeda_inicial_bonus(), nivel, maximo]
	)
	botao_evoluir_moeda.text = "Evoluir (%d moeda lunar)" % custo
	botao_evoluir_moeda.disabled = Progresso.moeda_lunar < custo


func _atualizar_linha_agua() -> void:
	var nivel := Progresso.nivel_evolucao_agua_maxima
	var maximo := Progresso.MAX_NIVEL_EVOLUCAO

	if nivel >= maximo:
		label_agua.text = (
			"Limite de água: %d (nível máximo %d/%d)"
			% [Progresso.agua_maxima_total(), nivel, maximo]
		)
		botao_evoluir_agua.text = "Máximo"
		botao_evoluir_agua.disabled = true
		return

	var custo := Progresso.custo_evolucao_agua_maxima()

	label_agua.text = (
		"Limite de água: %d (nível %d/%d)"
		% [Progresso.agua_maxima_total(), nivel, maximo]
	)
	botao_evoluir_agua.text = "Evoluir (%d moeda lunar)" % custo
	botao_evoluir_agua.disabled = Progresso.moeda_lunar < custo


func _on_evoluir_moeda_pressed() -> void:
	Progresso.evoluir_moeda_inicial()
	_atualizar_tudo()


func _on_evoluir_agua_pressed() -> void:
	Progresso.evoluir_agua_maxima()
	_atualizar_tudo()


func _on_voltar_pressed() -> void:
	get_tree().change_scene_to_file(CENA_NIVEIS)
