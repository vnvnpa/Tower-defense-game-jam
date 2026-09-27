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

# ------------------------------------------------------------
# ÁGUA (recurso com limite, evoluível permanentemente em Progresso).
# Por enquanto só é exibida no hub (ver controle_tudo,hub.gd) -- ainda
# não é gasta em nenhum lugar do jogo.
# ------------------------------------------------------------
var agua_maxima: int = 100
var agua_atual: int = 100


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


# ------------------------------------------------------------
# ÁGUA
# ------------------------------------------------------------
func gastar_agua(valor: int) -> bool:
	if agua_atual < valor:
		return false
	agua_atual -= valor
	return true


func repor_agua(valor: int) -> void:
	agua_atual = min(agua_maxima, agua_atual + valor)


func _aplicar_limite_de_agua() -> void:
	agua_maxima = Progresso.agua_maxima_total()
	agua_atual = agua_maxima


func resetar_estado(moeda_inicial: int = 30):
	# FIX: despausa a árvore ao resetar o estado, senão o jogo fica travado
	# pra sempre depois de um Game Over (input não chega em nenhum nó
	# porque a SceneTree inteira está pausada).
	get_tree().paused = false
	vida = 5
	jogo_acabou = false
	coin = moeda_inicial + Progresso.moeda_inicial_bonus()
	_aplicar_limite_de_agua()

	for filho in get_children():
		if filho.is_in_group("menu_morte"):
			filho.queue_free()

	if cenaAtual != "":
		get_tree().change_scene_to_file(cenaAtual)


# Reset "local" -- usado quando o jogador sai pra o menu principal em vez
# de reiniciar a partida (não precisa recarregar a cenaAtual), e também
# antes de entrar em qualquer nível novo (ver niveis.gd), pra já começar
# com a moeda e a água certas, incluindo os bônus de evolução permanente.
func resetar_estado_local() -> void:
	get_tree().paused = false
	vida = 5
	jogo_acabou = false
	coin = 30 + Progresso.moeda_inicial_bonus()
	_aplicar_limite_de_agua()


func criarfilhoInvalido():
	add_child(AVISO_INVALIDO.instantiate())
