extends Node
## Progresso de níveis do modo campanha (solo). Guarda até onde o jogador já
## desbloqueou e salva isso em disco, igual ao perfil do jogador (PerfilJogador),
## pra não se perder quando o jogo for fechado.
##
## Também guarda a "moeda lunar" -- moeda permanente dropada só por bosses e
## pelo Rimuru (ver slime.gd), que serve pra evoluções permanentes (sistema
## ainda não implementado, mas o valor já fica salvo desde já).

signal moeda_lunar_atualizada(quantidade: int)

const CAMINHO_SAVE := "user://progresso.save"
const TOTAL_NIVEIS := 8

# Nível 1 já vem liberado. "nivel_maximo_desbloqueado" é o maior nível que o
# jogador já pode jogar (não necessariamente o que ele já venceu).
var nivel_maximo_desbloqueado: int = 1

# Qual nível está sendo jogado agora (definido pela tela de níveis antes de
# entrar na partida). Não precisa ser salvo -- só interessa durante a partida.
var nivel_atual: int = 1

# Moeda permanente (persiste entre partidas), diferente do "coin" de
# ControleDeTudo, que reseta a cada partida.
var moeda_lunar: int = 0


# ============================================================
# EVOLUÇÃO PERMANENTE
# ============================================================
# Comprada só com moeda lunar (dropada por bosses e pelo Rimuru). Cada
# evolução tem um número limitado de níveis e cada nível fica mais caro
# que o anterior. O efeito de cada uma é sempre um bônus SOMADO em cima
# do valor normal do modo/partida (não substitui o dinheiro inicial de
# cada modo, por exemplo).

const MAX_NIVEL_EVOLUCAO := 5

const MOEDA_INICIAL_POR_NIVEL := 5
const CUSTO_BASE_EVOLUCAO_MOEDA := 8

const AGUA_BASE := 100
const AGUA_POR_NIVEL := 20
const CUSTO_BASE_EVOLUCAO_AGUA := 8

var nivel_evolucao_moeda_inicial: int = 0
var nivel_evolucao_agua_maxima: int = 0


func _ready() -> void:
	carregar()


func nivel_desbloqueado(nivel: int) -> bool:
	return nivel <= nivel_maximo_desbloqueado


func completar_nivel(nivel: int) -> void:
	# Só avança o progresso se o nível concluído for o mais avançado que o
	# jogador tinha liberado (evita "voltar" o progresso ao rejogar uma fase
	# antiga) e se ainda não bateu no fim da campanha.
	if nivel == nivel_maximo_desbloqueado and nivel_maximo_desbloqueado < TOTAL_NIVEIS:
		nivel_maximo_desbloqueado += 1
		salvar()


func adicionar_moeda_lunar(quantidade: int) -> void:
	if quantidade <= 0:
		return

	moeda_lunar += quantidade

	moeda_lunar_atualizada.emit(moeda_lunar)

	salvar()


## ============================================================
## EVOLUÇÃO -- MOEDA INICIAL
## ============================================================

func moeda_inicial_bonus() -> int:
	return nivel_evolucao_moeda_inicial * MOEDA_INICIAL_POR_NIVEL


func custo_evolucao_moeda_inicial() -> int:
	return CUSTO_BASE_EVOLUCAO_MOEDA * (nivel_evolucao_moeda_inicial + 1)


func evoluir_moeda_inicial() -> bool:
	if nivel_evolucao_moeda_inicial >= MAX_NIVEL_EVOLUCAO:
		return false

	var custo := custo_evolucao_moeda_inicial()
	if moeda_lunar < custo:
		return false

	moeda_lunar -= custo
	nivel_evolucao_moeda_inicial += 1

	moeda_lunar_atualizada.emit(moeda_lunar)
	salvar()
	return true


## ============================================================
## EVOLUÇÃO -- LIMITE DE ÁGUA
## ============================================================

func agua_maxima_total() -> int:
	return AGUA_BASE + nivel_evolucao_agua_maxima * AGUA_POR_NIVEL


func custo_evolucao_agua_maxima() -> int:
	return CUSTO_BASE_EVOLUCAO_AGUA * (nivel_evolucao_agua_maxima + 1)


func evoluir_agua_maxima() -> bool:
	if nivel_evolucao_agua_maxima >= MAX_NIVEL_EVOLUCAO:
		return false

	var custo := custo_evolucao_agua_maxima()
	if moeda_lunar < custo:
		return false

	moeda_lunar -= custo
	nivel_evolucao_agua_maxima += 1

	moeda_lunar_atualizada.emit(moeda_lunar)
	salvar()
	return true


func salvar() -> void:
	var dados := {
		"nivel_maximo_desbloqueado": nivel_maximo_desbloqueado,
		"moeda_lunar": moeda_lunar,
		"nivel_evolucao_moeda_inicial": nivel_evolucao_moeda_inicial,
		"nivel_evolucao_agua_maxima": nivel_evolucao_agua_maxima,
	}
	var arquivo := FileAccess.open(CAMINHO_SAVE, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível salvar o progresso: %s" % FileAccess.get_open_error())
		return
	arquivo.store_string(JSON.stringify(dados))
	arquivo.close()


func carregar() -> void:
	if not FileAccess.file_exists(CAMINHO_SAVE):
		return

	var arquivo := FileAccess.open(CAMINHO_SAVE, FileAccess.READ)
	if arquivo == null:
		return

	var texto := arquivo.get_as_text()
	arquivo.close()

	var resultado = JSON.parse_string(texto)
	if typeof(resultado) != TYPE_DICTIONARY:
		return

	nivel_maximo_desbloqueado = clampi(
		int(resultado.get("nivel_maximo_desbloqueado", 1)),
		1,
		TOTAL_NIVEIS
	)

	moeda_lunar = max(0, int(resultado.get("moeda_lunar", 0)))

	nivel_evolucao_moeda_inicial = clampi(
		int(resultado.get("nivel_evolucao_moeda_inicial", 0)),
		0,
		MAX_NIVEL_EVOLUCAO
	)

	nivel_evolucao_agua_maxima = clampi(
		int(resultado.get("nivel_evolucao_agua_maxima", 0)),
		0,
		MAX_NIVEL_EVOLUCAO
	)

