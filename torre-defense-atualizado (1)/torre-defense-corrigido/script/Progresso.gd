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

# Upgrade avulso (não tem "nível", é sim/não): desbloqueia a compra
# automática de água -- ver ControleDeTudo._verificar_agua_automatica().
const CUSTO_AGUA_AUTOMATICA := 5
var agua_automatica_desbloqueada: bool = false

# Vida permanente: +1 vida por nível, custo FIXO de 30 moeda lunar em
# todos os níveis (não cresce como as outras evoluções).
const VIDA_POR_NIVEL := 1
const CUSTO_EVOLUCAO_VIDA := 30
var nivel_evolucao_vida: int = 0


# ============================================================
# ESTATÍSTICAS (tela de perfil)
# ============================================================
# "Raro" agrupa bosses e inimigos explosivos -- os tipos de inimigo mais
# incomuns que não são nem o slime comum nem o Rimuru.

var slimes_comuns_derrotados: int = 0
var slimes_raros_derrotados: int = 0
var rimurus_derrotados: int = 0


func _ready() -> void:
	carregar()


func nivel_desbloqueado(nivel: int) -> bool:
	return nivel <= nivel_maximo_desbloqueado


# ============================================================
# VELOCIDADES 6x / 8x -- desbloqueadas nos níveis que NÃO liberam
# nenhuma torre nem nenhum outro upgrade (ver NIVEL_QUE_LIBERA_TORRE em
# controleDeTudo.gd: os níveis 4, 5 e 8 não liberam nada disso). Chegar
# no nível 5 (ou seja, ter batido o 4) libera 6x; chegar no nível 8 (ter
# batido o 7, a campanha inteira) libera 8x.
# ============================================================

const NIVEL_DESBLOQUEIA_6X := 5
const NIVEL_DESBLOQUEIA_8X := 8

func velocidade_6x_desbloqueada() -> bool:
	return nivel_maximo_desbloqueado >= NIVEL_DESBLOQUEIA_6X


func velocidade_8x_desbloqueada() -> bool:
	return nivel_maximo_desbloqueado >= NIVEL_DESBLOQUEIA_8X


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


func gastar_moeda_lunar(quantidade: int) -> bool:
	if quantidade <= 0 or moeda_lunar < quantidade:
		return false

	moeda_lunar -= quantidade

	moeda_lunar_atualizada.emit(moeda_lunar)

	salvar()

	return true


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
## EVOLUÇÃO -- ÁGUA AUTOMÁTICA (upgrade único, sem níveis)
## ============================================================

func desbloquear_agua_automatica() -> bool:
	if agua_automatica_desbloqueada:
		return false

	if moeda_lunar < CUSTO_AGUA_AUTOMATICA:
		return false

	moeda_lunar -= CUSTO_AGUA_AUTOMATICA
	agua_automatica_desbloqueada = true

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


## ============================================================
## EVOLUÇÃO -- VIDA PERMANENTE
## ============================================================
# +1 vida por nível, custo fixo (não cresce) de CUSTO_EVOLUCAO_VIDA a
# cada nível, até MAX_NIVEL_EVOLUCAO.

func vida_bonus() -> int:
	return nivel_evolucao_vida * VIDA_POR_NIVEL


func custo_evolucao_vida() -> int:
	return CUSTO_EVOLUCAO_VIDA


func evoluir_vida() -> bool:
	if nivel_evolucao_vida >= MAX_NIVEL_EVOLUCAO:
		return false

	if moeda_lunar < CUSTO_EVOLUCAO_VIDA:
		return false

	moeda_lunar -= CUSTO_EVOLUCAO_VIDA
	nivel_evolucao_vida += 1

	moeda_lunar_atualizada.emit(moeda_lunar)
	salvar()
	return true


## ============================================================
## ESTATÍSTICAS -- ABATES
## ============================================================
# Chamadas por slime.gd, em morrer(), pra cada tipo de inimigo.

func registrar_abate_comum() -> void:
	slimes_comuns_derrotados += 1
	salvar()


func registrar_abate_raro() -> void:
	slimes_raros_derrotados += 1
	salvar()


func registrar_abate_rimuru() -> void:
	rimurus_derrotados += 1
	salvar()


## ============================================================
## RESETAR TUDO
## ============================================================
# Apaga TODO o progresso salvo (níveis liberados, moeda lunar, evoluções
# permanentes e estatísticas) e volta pro estado de jogo zero-hora. NÃO
# mexe no perfil (nick/idade/cor) -- isso é identidade, não progresso.

func resetar_tudo() -> void:
	nivel_maximo_desbloqueado = 1
	nivel_atual = 1
	moeda_lunar = 0

	nivel_evolucao_moeda_inicial = 0
	nivel_evolucao_agua_maxima = 0
	agua_automatica_desbloqueada = false
	nivel_evolucao_vida = 0

	slimes_comuns_derrotados = 0
	slimes_raros_derrotados = 0
	rimurus_derrotados = 0

	salvar()
	moeda_lunar_atualizada.emit(moeda_lunar)


func salvar() -> void:
	var dados := {
		"nivel_maximo_desbloqueado": nivel_maximo_desbloqueado,
		"moeda_lunar": moeda_lunar,
		"nivel_evolucao_moeda_inicial": nivel_evolucao_moeda_inicial,
		"nivel_evolucao_agua_maxima": nivel_evolucao_agua_maxima,
		"agua_automatica_desbloqueada": agua_automatica_desbloqueada,
		"nivel_evolucao_vida": nivel_evolucao_vida,
		"slimes_comuns_derrotados": slimes_comuns_derrotados,
		"slimes_raros_derrotados": slimes_raros_derrotados,
		"rimurus_derrotados": rimurus_derrotados,
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

	agua_automatica_desbloqueada = bool(resultado.get("agua_automatica_desbloqueada", false))

	nivel_evolucao_vida = clampi(
		int(resultado.get("nivel_evolucao_vida", 0)),
		0,
		MAX_NIVEL_EVOLUCAO
	)

	slimes_comuns_derrotados = max(0, int(resultado.get("slimes_comuns_derrotados", 0)))
	slimes_raros_derrotados = max(0, int(resultado.get("slimes_raros_derrotados", 0)))
	rimurus_derrotados = max(0, int(resultado.get("rimurus_derrotados", 0)))

