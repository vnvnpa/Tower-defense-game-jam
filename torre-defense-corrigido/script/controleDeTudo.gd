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
	if not multiplayer.is_server():
		return  # só o host processa dano de verdade
	vida -= dano
	_sincronizar_vida.rpc(vida)  # replica o valor pra todo mundo (e pra ele mesmo)
	if vida <= 0 and not jogo_acabou:
		fim_de_jogo()


@rpc("authority", "call_local", "reliable")
func _sincronizar_vida(nova_vida: int) -> void:
	vida = nova_vida


func fim_de_jogo():
	if not multiplayer.is_server():
		return  # só o host decide que o jogo acabou
	_executar_fim_de_jogo.rpc()  # avisa todos os peers pra mostrar o menu


@rpc("authority", "call_local", "reliable")
func _executar_fim_de_jogo() -> void:
	jogo_acabou = true
	theEnd.emit()
	cenaAtual = get_tree().current_scene.scene_file_path
	get_tree().paused = true
	add_child(MENU_MORTE.instantiate())


# ------------------------------------------------------------
# COIN (autoritativo)
# ------------------------------------------------------------
func gastar_coin(valor: int) -> bool:
	if not multiplayer.is_server():
		return false  # só o host valida gasto de verdade
	if coin < valor:
		return false
	coin -= valor
	_sincronizar_coin.rpc(coin)
	return true


func ganhar_coin(valor: int) -> void:
	if not multiplayer.is_server():
		return  # só o host processa ganho de verdade
	coin += valor
	_sincronizar_coin.rpc(coin)


@rpc("authority", "call_local", "reliable")
func _sincronizar_coin(novo_coin: int) -> void:
	coin = novo_coin


func resetar_estado():
	if not multiplayer.is_server():
		return
	# FIX: despausa a árvore ao resetar o estado, senão o jogo
	# fica travado pra sempre depois de um Game Over (input não
	# chega em nenhum nó porque a SceneTree inteira está pausada).
	get_tree().paused = false
	vida = 5
	jogo_acabou = false
	coin = 30
	_sincronizar_reset.rpc(vida, coin)


@rpc("authority", "call_local", "reliable")
func _sincronizar_reset(nova_vida: int, novo_coin: int) -> void:
	get_tree().paused = false
	vida = nova_vida
	coin = novo_coin
	jogo_acabou = false


func criarfilhoInvalido():
	add_child(AVISO_INVALIDO.instantiate())
