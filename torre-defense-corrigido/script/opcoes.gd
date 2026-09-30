extends CanvasLayer

## Menu de opções. Funciona em dois contextos:
## 1) Aberto pelo menu principal (troca de cena normal) -- é o
##    `current_scene` da árvore.
## 2) Aberto por CIMA do menu de pause, com o jogo ainda pausado -- nesse
##    caso ele é filho de outra cena (o pause), então "voltar" não pode
##    trocar de cena (perderia a partida em andamento): só fecha essa
##    camada e volta a mostrar o pause por trás.
##
## `_eh_cena_principal()` decide sozinho qual dos dois é o caso, olhando
## se este nó é o `current_scene` da SceneTree.

signal fechar

const CENA_CREDITOS := "res://cenas/menus/creditos.tscn"
const CENA_MENU := "res://cenas/menus/menu.tscn"
const CENA_PERFIL_DADOS := "res://cenas/menus/perfilDados.tscn"

@onready var botao_creditos: Button = $Painel/VBoxContainer/Creditos
@onready var botao_perfil: Button = $Painel/VBoxContainer/AlterarPerfil
@onready var botao_som_jogo: Button = $Painel/VBoxContainer/SomDoJogo
@onready var botao_som_tiro: Button = $Painel/VBoxContainer/SomDeTiro
@onready var botao_voltar: Button = $Painel/VBoxContainer/Voltar

var _creditos_aberto: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	botao_creditos.pressed.connect(_on_creditos_pressed)
	botao_perfil.pressed.connect(_on_perfil_pressed)
	botao_som_jogo.pressed.connect(_on_som_jogo_pressed)
	botao_som_tiro.pressed.connect(_on_som_tiro_pressed)
	botao_voltar.pressed.connect(_on_voltar_pressed)

	# Sons ainda não existem no jogo -- só deixa o texto do botão pronto
	# pra quando o áudio for adicionado.
	_atualizar_texto_som(botao_som_jogo, "Som do jogo")
	_atualizar_texto_som(botao_som_tiro, "Som de tiro")


func _eh_cena_principal() -> bool:
	return get_tree().current_scene == self


func _on_creditos_pressed() -> void:
	if _eh_cena_principal():
		get_tree().change_scene_to_file(CENA_CREDITOS)
		return

	if is_instance_valid(_creditos_aberto):
		return

	_creditos_aberto = load(CENA_CREDITOS).instantiate()
	_creditos_aberto.layer = layer + 1
	add_child(_creditos_aberto)
	_creditos_aberto.fechar.connect(_on_creditos_fechados)


func _on_creditos_fechados() -> void:
	_creditos_aberto = null


func _on_perfil_pressed() -> void:
	# Editar nick/idade/cor no meio de uma partida pausada não faz muito
	# sentido (o formulário ocupa a tela toda), então nesse caso também
	# despausa e troca de cena -- equivale a sair da partida pra ver o
	# perfil.
	get_tree().paused = false
	get_tree().change_scene_to_file(CENA_PERFIL_DADOS)


func _on_som_jogo_pressed() -> void:
	# Placeholder: ainda não existe áudio no jogo. Só alterna a aparência
	# do botão pra já deixar a interface pronta.
	botao_som_jogo.button_pressed = not botao_som_jogo.button_pressed
	_atualizar_texto_som(botao_som_jogo, "Som do jogo")


func _on_som_tiro_pressed() -> void:
	botao_som_tiro.button_pressed = not botao_som_tiro.button_pressed
	_atualizar_texto_som(botao_som_tiro, "Som de tiro")


func _atualizar_texto_som(botao: Button, rotulo: String) -> void:
	botao.text = "%s: %s" % [rotulo, "ligado" if botao.button_pressed else "desligado"]


func _on_voltar_pressed() -> void:
	if _eh_cena_principal():
		get_tree().change_scene_to_file(CENA_MENU)
		return

	fechar.emit()
	queue_free()
