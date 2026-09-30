extends CanvasLayer

## Menu de pause. Criado por cima da partida (ver controle_velocidade.gd,
## que tem o botão no canto superior direito). Tem 3 botões:
##
## - Resume: despausa e se autodestrói.
## - Opções: abre a tela de opções por cima, com o jogo continuando
##   pausado (essa tela é fechada sozinha, o pause continua por trás).
## - Voltar: despausa, se autodestrói e volta pra tela de seleção de
##   nível (sai da partida em andamento).

const CENA_OPCOES := preload("res://cenas/menus/opcoes.tscn")
const CENA_NIVEIS := "res://cenas/menus/niveis.tscn"

@onready var botao_resume: Button = $Painel/VBoxContainer/Resume
@onready var botao_opcoes: Button = $Painel/VBoxContainer/Opcoes
@onready var botao_voltar: Button = $Painel/VBoxContainer/Voltar

var _opcoes_abertas: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	botao_resume.pressed.connect(_on_resume_pressed)
	botao_opcoes.pressed.connect(_on_opcoes_pressed)
	botao_voltar.pressed.connect(_on_voltar_pressed)


func _on_resume_pressed() -> void:
	get_tree().paused = false
	queue_free()


func _on_opcoes_pressed() -> void:
	if is_instance_valid(_opcoes_abertas):
		return

	_opcoes_abertas = CENA_OPCOES.instantiate()
	add_child(_opcoes_abertas)
	_opcoes_abertas.fechar.connect(_on_opcoes_fechadas)


func _on_opcoes_fechadas() -> void:
	_opcoes_abertas = null


func _on_voltar_pressed() -> void:
	get_tree().paused = false
	queue_free()
	get_tree().change_scene_to_file(CENA_NIVEIS)
