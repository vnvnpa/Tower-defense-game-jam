extends CanvasLayer

const AVISO_INVALIDO = preload("uid://ix8tss3yf4ao")
const MENU_MORTE = preload("uid://cec6h86860yf")

var coin = 30
var esmeralda
signal invalido
signal theEnd
var vida = 5
var jogo_acabou: bool = false
var cenaAtual: String


func _ready() -> void:
	invalido.connect(criarfilhoInvalido)


func perder_vida(dano):
	vida -= dano
	if vida <= 0 and not jogo_acabou:
		fim_de_jogo()


func fim_de_jogo():
	jogo_acabou = true
	theEnd.emit()
	cenaAtual = get_tree().current_scene.scene_file_path
	get_tree().paused = true
	add_child(MENU_MORTE.instantiate())


# ------------------------------------------------------------
# COIN
# ------------------------------------------------------------
func gastar_coin(valor: int) -> bool:
	if coin < valor:
		return false
	coin -= valor
	return true


func ganhar_coin(valor: int) -> void:
	coin += valor


func resetar_estado(moeda_inicial: int = 30):
	# FIX: despausa a árvore ao resetar o estado, senão o jogo fica travado
	# pra sempre depois de um Game Over (input não chega em nenhum nó
	# porque a SceneTree inteira está pausada).
	get_tree().paused = false
	vida = 5
	jogo_acabou = false
	coin = moeda_inicial

	for filho in get_children():
		if filho.is_in_group("menu_morte"):
			filho.queue_free()

	if cenaAtual != "":
		get_tree().change_scene_to_file(cenaAtual)


# Reset "local" -- usado quando o jogador sai pra o menu principal em vez
# de reiniciar a partida (não precisa recarregar a cenaAtual).
func resetar_estado_local() -> void:
	get_tree().paused = false
	vida = 5
	jogo_acabou = false
	coin = 30


func criarfilhoInvalido():
	add_child(AVISO_INVALIDO.instantiate())
