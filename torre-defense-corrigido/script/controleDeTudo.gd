extends CanvasLayer

const AVISO_INVALIDO = preload("uid://ix8tss3yf4ao")
const MENU_MORTE = preload("uid://cec6h86860yf")

var coin = 30
signal invalido
signal theEnd
var vida = 5
var jogo_acabou: bool = false
var cenaAtual: String

# ------------------------------------------------------------
# ÁGUA (recurso com limite, evoluível permanentemente em Progresso).
# Gasta pelas torres a cada disparo (ver atiradores.gd), a partir do nível 2.
# ------------------------------------------------------------
var agua_maxima: int = 100
var agua_atual: int = 100


# ------------------------------------------------------------
# REGRAS DO GDD (rodadas / níveis da campanha)
# ------------------------------------------------------------
# Nível 1: só Mangueira, sem gasto de água. Nível 2: água começa a ser
# gasta a cada disparo. Nível 3: Irrigador. Nível 6: Mangueira Prime.
# Nível 7: Irrigador Prime. Nos modos fora da campanha, tudo já vem
# liberado.
const NIVEL_INICIO_AGUA := 2

const NIVEL_QUE_LIBERA_TORRE := {
	"mangueira": 1,
	"irrigador": 3,
	"mangueira_prime": 6,
	"irrigador_prime": 7,
}

# Compra de água (moeda de ouro -> litros). O GDD não fixa o preço,
# então ajuste aqui.
const AGUA_LITROS_POR_COMPRA := 20
const AGUA_CUSTO_COMPRA := 2

# Limiar do upgrade permanente "água automática" (ver Progresso.gd) --
# quando a água chega nesse valor ou menos, compra sozinha (gastando
# ouro), uma vez por "mergulho" abaixo do limiar.
const LIMIAR_AGUA_AUTOMATICA := 20

var _auto_agua_disparada: bool = false


func _ready() -> void:
	invalido.connect(criarfilhoInvalido)


func _process(_delta: float) -> void:
	_verificar_agua_automatica()


# Upgrade permanente comprado na tela de evolução (Progresso.gd). Fica de
# olho na água toda partida; sempre que ela cai a LIMIAR_AGUA_AUTOMATICA ou
# menos, compra um tanque sozinha (gastando ouro). Só volta a disparar na
# PRÓXIMA vez que a água cair de novo (não fica comprando toda hora).
func _verificar_agua_automatica() -> void:
	if jogo_acabou or not Progresso.agua_automatica_desbloqueada or not agua_ativa():
		return

	if agua_atual > LIMIAR_AGUA_AUTOMATICA:
		_auto_agua_disparada = false
		return

	if _auto_agua_disparada:
		return

	if comprar_agua():
		_auto_agua_disparada = true


func _em_campanha() -> bool:
	return NetworkManager.modo_de_jogo == "campanha"


# Água só é gasta (e só aparece no HUD) a partir do nível 2 da campanha.
func agua_ativa() -> bool:
	if _em_campanha():
		return Progresso.nivel_atual >= NIVEL_INICIO_AGUA
	return true


func nivel_que_libera(tipo: String) -> int:
	return int(NIVEL_QUE_LIBERA_TORRE.get(tipo, 1))


func torre_liberada(tipo: String) -> bool:
	if _em_campanha():
		return Progresso.nivel_atual >= nivel_que_libera(tipo)
	return true


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


# Compra AGUA_LITROS_POR_COMPRA litros com ouro (falha se já está cheio
# ou se não tem dinheiro).
func comprar_agua() -> bool:
	if not agua_ativa() or agua_atual >= agua_maxima:
		return false
	if not gastar_coin(AGUA_CUSTO_COMPRA):
		return false
	repor_agua(AGUA_LITROS_POR_COMPRA)
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
	vida = 5 + Progresso.vida_bonus()
	jogo_acabou = false
	coin = moeda_inicial + Progresso.moeda_inicial_bonus()
	_aplicar_limite_de_agua()
	_auto_agua_disparada = false

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
	vida = 5 + Progresso.vida_bonus()
	jogo_acabou = false
	coin = 30 + Progresso.moeda_inicial_bonus()
	_aplicar_limite_de_agua()
	_auto_agua_disparada = false


func criarfilhoInvalido():
	add_child(AVISO_INVALIDO.instantiate())
