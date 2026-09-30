extends CanvasLayer

## Tela de créditos. Igual à de opções, funciona tanto como cena cheia
## (aberta pelo menu de opções principal) quanto como camada por cima
## de outra cena (aberta pelo menu de opções durante uma pausa).

signal fechar

const CENA_OPCOES := "res://cenas/menus/opcoes.tscn"

@onready var botao_voltar: Button = $Painel/VBoxContainer/Voltar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	botao_voltar.pressed.connect(_on_voltar_pressed)


func _eh_cena_principal() -> bool:
	return get_tree().current_scene == self


func _on_voltar_pressed() -> void:
	if _eh_cena_principal():
		get_tree().change_scene_to_file(CENA_OPCOES)
		return

	fechar.emit()
	queue_free()
