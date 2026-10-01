extends Node2D

# ============================================================
# CONFIGURAÇÃO BÁSICA
# ============================================================

# tipo_torre/custo são preenchidos pela loja (lojaScripit.gd) quando o
# jogador compra essa torre. dano_base e os outros exports já vêm prontos
# de cada cena de torre (cenas/torres/mangueira.tscn, irrigador.tscn).

@export var tipo_torre: String = "mangueira"
@export var custo: int = 10
# Preço alternativo em moeda lunar (só as torres Prime usam). Se o jogador
# não tiver ouro suficiente mas tiver moeda lunar, paga com ela.
@export var custo_lunar: int = 0
@export var dano_base: int = 10

@export var projetil_scene: PackedScene
@export var cadencia: float = 1.0
@export var velocidade_projetil: float = 400.0
@export var life: int = 30  # vestigial -- torres não tomam mais dano, ver tomar_dano()
@export var alcance: float = 187.8

# Litros gastos a CADA disparo (mangueira: 1 tiro = 1 L; irrigador: 2 tiros
# de 500 mL = 1 L por rajada). Só gasta a partir do nível 2 -- ver
# ControleDeTudo.agua_ativa().
@export var agua_por_disparo: int = 1


# ============================================================
# LENTIDÃO
# ============================================================

@export var causa_lentidao: bool = false
@export var percentual_lentidao: float = 0.18
@export var duracao_lentidao: float = 3.0


# ============================================================
# DANO CONTÍNUO (irrigadores)
# ============================================================
# A cada 1s o slime toma "percentual_dot" do dano da torre, durante
# "duracao_dot" segundos (não empilha, só renova).

@export var causa_dano_continuo: bool = false
@export var percentual_dot: float = 0.08
@export var duracao_dot: float = 5.0

# Quanto o debuff (lentidão ou dano contínuo) ganha a cada 8 níveis de evolução.
const BONUS_DEBUFF_A_CADA_8_NIVEIS: float = 0.08
const LIMITE_LENTIDAO: float = 0.9


# ============================================================
# MODO DE ATAQUE
# ============================================================

@export_enum("mira", "giratorio") var modo_ataque: String = "mira"
@export var velocidade_rotacao: float = 3.0

# Irrigador: os tiros saem atravessando os slimes (não somem no primeiro).
@export var atravessa_inimigos: bool = false
# Irrigador Prime: o ângulo do disparo é sorteado a cada rajada.
@export var disparo_aleatorio: bool = false

# Mangueira: distância da "boca" até o centro da cabeça, na direção que
# ela está olhando.
@export var offset_boca: float = 28.0


const PAINEL_INFO_SCENE: PackedScene = preload(
	"res://cenas/torres/PainelInfoTorre.tscn"
)


var arrastando: bool = true
var pronto_para_fixar: bool = false

# Depois que o jogador clica pra posicionar
var aguardando_confirmacao: bool = false

# Fica true enquanto o painel de EVOLUÇÃO (não o de colocação) está aberto.
var _painel_evolucao_aberto: bool = false

var _painel_atual: Node = null


# ============================================================
# EVOLUÇÃO
# ============================================================

var nivel_evolucao: int = 0

# Total gasto nessa torre (colocação + evoluções), separado por moeda --
# usado só pra calcular o reembolso quando ela é vendida/removida.
var _gasto_coin: int = 0
var _gasto_lunar: int = 0


# ============================================================
# NÓS
# ============================================================

@onready var area_alcance: Area2D = $are
@onready var ponto_de_tiro: Marker2D = $PontoDeTiro
@onready var area_de_receber_b_: Area2D = $"areaDeReceberB="
@onready var collision_shape_2d: CollisionShape2D = $are/CollisionShape2D
@onready var node_2d: Node2D = $"."

# Só a Mangueira tem cabeça móvel (4 animações: cima/baixo/esquerda/direita).
@onready var cabeca: AnimatedSprite2D = get_node_or_null("cabeçaMovel")

const DIRECOES_CABECA := {
	"direita": Vector2.RIGHT,
	"esquerda": Vector2.LEFT,
	"cima": Vector2.UP,
	"baixo": Vector2.DOWN,
}

const COR_SEM_AGUA := Color(0.55, 0.6, 0.75, 1.0)

var mostrar_alcance: bool = false
var _mouse_dentro: bool = false

# Raio/ângulo iniciais do PontoDeTiro em relação ao centro da torre --
# usados pelo modo giratório pra fazer o marker orbitar sem girar o
# corpo/sprite da torre (ver _processar_modo_giratorio).
var _raio_ponto_de_tiro: float = 0.0
var _angulo_ponto_de_tiro: float = 0.0


# ============================================================
# DESENHO DO ALCANCE
# ============================================================

func _draw():

	if mostrar_alcance:

		draw_arc(
			Vector2.ZERO,
			alcance,
			0.0,
			TAU,
			64,
			Color(0, 1, 0, 0.5),
			2.0
		)


func mostrar():

	mostrar_alcance = true

	queue_redraw()


func esconder():

	mostrar_alcance = false

	queue_redraw()


# O alcance agora fica visível se o mouse está em cima da torre OU se
# qualquer painel dela está aberto (colocação, evolução ou remoção --
# remoção usa o mesmo painel de evolução).
func _atualizar_exibicao_alcance() -> void:

	if _mouse_dentro or aguardando_confirmacao or _painel_evolucao_aberto:

		mostrar()

	else:

		esconder()


# ============================================================
# ATAQUE
# ============================================================

var inimigos_no_alcance: Array = []

# Segundos que faltam pro próximo disparo (0 = pronta).
var _cooldown: float = 0.0


# ============================================================
# READY
# ============================================================

func _ready():

	await get_tree().process_frame

	pronto_para_fixar = true

	area_alcance.area_entered.connect(_on_inimigo_entrou)
	area_alcance.area_exited.connect(_on_inimigo_saiu)

	# Se já chegou fixada, pode ser alvo de ataque.
	area_de_receber_b_.monitorable = not arrastando

	area_alcance.input_pickable = true

	area_de_receber_b_.mouse_entered.connect(_on_mouse_entered)
	area_de_receber_b_.mouse_exited.connect(_on_mouse_exited)

	# Clique na torre abre o painel de evolução.
	area_de_receber_b_.input_pickable = true
	area_de_receber_b_.input_event.connect(_on_area_input_event)

	# Guarda a posição original do PontoDeTiro pra o modo giratório poder
	# orbitá-lo sem depender da rotação do Node2D inteiro.
	_raio_ponto_de_tiro = ponto_de_tiro.position.length()
	_angulo_ponto_de_tiro = ponto_de_tiro.position.angle()


func _on_mouse_entered():

	_mouse_dentro = true

	_atualizar_exibicao_alcance()


func _on_mouse_exited():

	_mouse_dentro = false

	_atualizar_exibicao_alcance()


# ============================================================
# PROCESS
# ============================================================

func _process(delta):

	if arrastando:

		global_position = get_global_mouse_position()

		return


	# Travada esperando confirmação.
	if aguardando_confirmacao:

		return


	_cooldown = maxf(0.0, _cooldown - delta)

	_atualizar_cor_sem_agua()


	match modo_ataque:

		"giratorio":

			_processar_modo_giratorio(delta)

		_:

			_processar_modo_mira(delta)


# Escurece a torre quando o tanque não dá pro próximo disparo.
func _atualizar_cor_sem_agua() -> void:

	var sem_agua: bool = (
		ControleDeTudo.agua_ativa()
		and ControleDeTudo.agua_atual < agua_por_disparo
	)

	modulate = COR_SEM_AGUA if sem_agua else Color.WHITE


# ============================================================
# ÁGUA
# ============================================================

# Cobra a água do disparo. Nível 1 (ou modos sem água) não cobra nada.
func _pagar_agua() -> bool:

	if not ControleDeTudo.agua_ativa():

		return true

	return ControleDeTudo.gastar_agua(agua_por_disparo)


# ============================================================
# ALVOS
# ============================================================

func _limpar_inimigos_invalidos() -> void:

	for area in inimigos_no_alcance.duplicate():

		if not is_instance_valid(area):

			inimigos_no_alcance.erase(area)

			continue


		var inimigo: Node = area.get_parent()

		if not is_instance_valid(inimigo):

			inimigos_no_alcance.erase(area)

			continue


		if inimigo.has_method("esta_morrendo") and inimigo.esta_morrendo():

			inimigos_no_alcance.erase(area)

			continue


		if "vida" in inimigo and inimigo.vida <= 0:

			inimigos_no_alcance.erase(area)


# ============================================================
# MODO MIRA (Mangueira)
# ============================================================

# O corpo NÃO gira. Só a cabeça troca de animação pra direção do alvo, e
# a boca (PontoDeTiro) acompanha a cabeça. O projétil sai mirado no alvo.
func _processar_modo_mira(_delta: float) -> void:

	_limpar_inimigos_invalidos()


	# Sem inimigo no alcance: não faz nada e não gasta água.
	if inimigos_no_alcance.is_empty():

		return


	var alvo: Area2D = inimigos_no_alcance[0]


	_apontar_cabeca(alvo.global_position - global_position)


	if _cooldown > 0.0:

		return


	if not _pagar_agua():

		return


	atirar(alvo)


# Escolhe a animação pelo eixo dominante e move a boca pra frente da cabeça.
func _apontar_cabeca(direcao: Vector2) -> void:

	var nome: String = _nome_direcao(direcao)


	if cabeca != null:

		if cabeca.animation != nome:

			cabeca.play(nome)

		ponto_de_tiro.position = (
			cabeca.position + DIRECOES_CABECA[nome] * offset_boca
		)

	else:

		ponto_de_tiro.position = DIRECOES_CABECA[nome] * offset_boca


func _nome_direcao(direcao: Vector2) -> String:

	if absf(direcao.x) > absf(direcao.y):

		return "direita" if direcao.x > 0.0 else "esquerda"

	return "baixo" if direcao.y > 0.0 else "cima"


# ============================================================
# ATIRAR (MODO MIRA)
# ============================================================

func atirar(alvo: Area2D):

	if not is_instance_valid(alvo):

		return


	_cooldown = cadencia


	var direcao: Vector2 = (
		alvo.global_position -
		ponto_de_tiro.global_position
	).normalized()


	# Alcance máximo do tiro: se errar, a bala some em vez de voar pra sempre.
	_criar_projetil(
		ponto_de_tiro.global_position,
		direcao,
		alcance * 1.5
	)


# ============================================================
# MODO GIRATÓRIO (Irrigador)
# ============================================================

# Só o Marker2D (PontoDeTiro) orbita a torre -- o corpo/sprite não gira.
# Ele fica girando o tempo todo, mas só DISPARA (e só gasta água) quando
# tem inimigo dentro do alcance.
func _processar_modo_giratorio(delta: float) -> void:

	_angulo_ponto_de_tiro += velocidade_rotacao * delta

	_posicionar_marker()


	_limpar_inimigos_invalidos()


	if inimigos_no_alcance.is_empty():

		return


	if _cooldown > 0.0:

		return


	if not _pagar_agua():

		return


	_cooldown = cadencia


	# Prime: sorteia o ângulo da rajada.
	if disparo_aleatorio:

		_angulo_ponto_de_tiro = randf() * TAU

		_posicionar_marker()


	atirar_sem_mira()


func _posicionar_marker() -> void:

	ponto_de_tiro.position = (
		Vector2.RIGHT.rotated(_angulo_ponto_de_tiro) * _raio_ponto_de_tiro
	)

	ponto_de_tiro.rotation = _angulo_ponto_de_tiro


# Dois tiros de 500 mL ao mesmo tempo, em lados opostos do círculo.
func atirar_sem_mira() -> void:

	var offset: Vector2 = ponto_de_tiro.position

	var direcao: Vector2 = offset.normalized()

	# O tiro percorre só até a borda do alcance.
	var distancia: float = maxf(alcance - _raio_ponto_de_tiro, 40.0)

	_criar_projetil(global_position + offset, direcao, distancia)

	_criar_projetil(global_position - offset, -direcao, distancia)


# ============================================================
# DISPARO (compartilhado pelos dois modos)
# ============================================================

func _criar_projetil(
	pos_global: Vector2,
	direcao: Vector2,
	distancia_max: float = 0.0
) -> void:

	if projetil_scene == null:

		return


	var projetil: Node = projetil_scene.instantiate()


	get_tree().current_scene.add_child(projetil)

	projetil.global_position = pos_global
	projetil.rotation = direcao.angle()


	projetil.setup(
		direcao,
		velocidade_projetil
	)


	projetil.dano = _dano_efetivo()

	projetil.atravessa = atravessa_inimigos

	projetil.distancia_max = distancia_max


	if causa_lentidao:

		projetil.causa_lentidao = true

		projetil.percentual_lentidao = percentual_lentidao

		projetil.duracao_lentidao = duracao_lentidao


	if causa_dano_continuo:

		projetil.causa_dano_continuo = true

		projetil.dano_continuo_por_tick = maxi(
			1,
			roundi(_dano_efetivo() * percentual_dot)
		)

		projetil.duracao_dano_continuo = duracao_dot


# ============================================================
# DETECÇÃO DE INIMIGOS
# ============================================================

func _on_inimigo_entrou(area):

	if area.is_in_group("inimigos"):

		inimigos_no_alcance.append(area)


func _on_inimigo_saiu(area):

	inimigos_no_alcance.erase(area)


# ============================================================
# DANO NA TORRE
# ============================================================

# Por decisão de design as torres não tomam mais dano (nem de inimigos
# encostando nelas, nem de explosão). A função continua existindo (em vez
# de ser removida) porque projetil.gd e slime.gd chamam "tomar_dano" via
# has_method() -- só que agora ela não faz nada.
func tomar_dano(_dano: int) -> void:

	pass


# ============================================================
# INPUT
# ============================================================

func _unhandled_input(event):

	# Clique fora do painel de EVOLUÇÃO em qualquer canto do mapa fecha ele.
	if is_instance_valid(_painel_atual) and _painel_evolucao_aberto:

		var pos = _posicao_global_do_clique(event)

		if pos != null and not (_painel_atual as Control).get_global_rect().has_point(pos):

			_fechar_painel_atual()

			return


	# Clique fora do painel de COLOCAÇÃO (confirmação) em qualquer canto
	# do mapa se comporta como "Reposicionar" -- solta a torre de novo
	# pra seguir o mouse, sem apagar ela. Pra apagar de vez é preciso usar
	# o botão "Cancelar" do próprio painel.
	if is_instance_valid(_painel_atual) and aguardando_confirmacao and not _painel_evolucao_aberto:

		var pos_colocacao = _posicao_global_do_clique(event)

		if pos_colocacao != null and not (_painel_atual as Control).get_global_rect().has_point(pos_colocacao):

			_on_reposicionar_colocacao()

			return


	if not arrastando or not pronto_para_fixar:

		return


	if event is InputEventMouseButton:

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			colocar()


	elif event is InputEventScreenTouch:

		if event.pressed:

			global_position = event.position

			colocar()


func _posicao_global_do_clique(event):

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

		return get_global_mouse_position()

	if event is InputEventScreenTouch and event.pressed:

		return event.position

	return null


# ============================================================
# COLOCAR TORRE
# ============================================================

func colocar():

	# "Ação inválida" (o efeito de erro -- som/flash) só dispara por
	# posição proibida (em cima do caminho, de uma decoração ou de outra
	# torre). Falta de dinheiro NÃO conta como posição inválida: o painel
	# de colocação abre do mesmo jeito, mostrando o preço, e o jogador
	# sempre pode reposicionar ou cancelar por ali -- o preço só é
	# conferido de verdade quando aperta "Confirmar" (ver
	# _on_confirmar_colocacao(), que já trata pagamento insuficiente).
	if not NetworkManager.posicao_torre_valida(global_position, self):

		ControleDeTudo.invalido.emit()

		return


	arrastando = false

	aguardando_confirmacao = true

	_atualizar_exibicao_alcance()

	_abrir_painel_colocacao()


# Torres Prime (custo_lunar > 0) só são colocadas com moeda lunar, sem
# opção de pagar em ouro. As básicas continuam só em ouro.
func _eh_prime() -> bool:

	return custo_lunar > 0


func _pode_pagar_colocacao() -> bool:

	if _eh_prime():

		return Progresso.moeda_lunar >= custo_lunar

	return ControleDeTudo.coin >= custo


func _pagar_colocacao() -> bool:

	if _eh_prime():

		if not Progresso.gastar_moeda_lunar(custo_lunar):

			return false

		_gasto_lunar += custo_lunar

		return true


	if not ControleDeTudo.gastar_coin(custo):

		return false

	_gasto_coin += custo

	return true


# ============================================================
# PAINEL DE CONFIRMAÇÃO
# ============================================================

func _abrir_painel_colocacao() -> void:

	_fechar_painel_atual()


	var painel: Node = PAINEL_INFO_SCENE.instantiate()

	add_child(painel)

	painel.global_position = global_position + Vector2(-115, -140)


	painel.configurar(
		_nome_da_torre(),
		"Dano: %d\nAlcance: %d\nCusto: %s%s%s" % [
			dano_base,
			int(alcance),
			_texto_custo(),
			_texto_agua(),
			_texto_efeitos()
		],
		"Confirmar",
		true,
		"Reposicionar",
		true,
		"Cancelar"
	)


	painel.confirmar_pressionado.connect(
		_on_confirmar_colocacao
	)

	painel.cancelar_pressionado.connect(
		_on_reposicionar_colocacao
	)

	painel.remover_pressionado.connect(
		_on_cancelar_colocacao_total
	)


	_painel_atual = painel


func _texto_custo() -> String:

	if _eh_prime():

		return "%d moeda lunar" % custo_lunar

	return "%d moedas" % custo


func _texto_agua() -> String:

	if not ControleDeTudo.agua_ativa():

		return ""

	return "\nÁgua: %d L por disparo" % agua_por_disparo


func _texto_efeitos() -> String:

	var texto: String = ""


	if causa_lentidao:

		texto += "\nLentidão %d%% por %ds" % [
			roundi(percentual_lentidao * 100.0),
			roundi(duracao_lentidao)
		]


	if causa_dano_continuo:

		texto += "\nDano contínuo %d%% por %ds" % [
			roundi(percentual_dot * 100.0),
			roundi(duracao_dot)
		]


	if modo_ataque == "giratorio":

		texto += (
			"\nAtira sem mirar, atravessando os slimes"
			+ (" (ângulo aleatório)" if disparo_aleatorio else "")
		)


	return texto


# ============================================================
# CONFIRMAR COLOCAÇÃO
# ============================================================

func _on_confirmar_colocacao() -> void:

	if not _pagar_colocacao():

		ControleDeTudo.invalido.emit()

		_on_reposicionar_colocacao()

		return


	aguardando_confirmacao = false

	area_de_receber_b_.monitorable = true

	_fechar_painel_atual()


# ============================================================
# REPOSICIONAR (era "cancelar colocação" -- botão renomeado a pedido:
# solta a torre de novo pra seguir o mouse, sem apagar ela. Também é
# chamado quando o jogador clica fora desse painel -- ver
# _unhandled_input()).
# ============================================================

func _on_reposicionar_colocacao() -> void:

	aguardando_confirmacao = false

	arrastando = true

	_fechar_painel_atual()


# ============================================================
# CANCELAR DE VERDADE (apaga a torre que estava seguindo o mouse; como
# ainda não foi paga -- só se paga em _on_confirmar_colocacao() -- não
# tem reembolso nenhum aqui, só remove a torre da cena).
# ============================================================

func _on_cancelar_colocacao_total() -> void:

	_fechar_painel_atual()

	queue_free()


# ============================================================
# EVOLUÇÃO
# ============================================================

func _on_area_input_event(
	_viewport,
	event,
	_shape_idx
) -> void:

	if arrastando or aguardando_confirmacao:

		return


	var clicou: bool = false


	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):

		clicou = true


	elif event is InputEventScreenTouch:

		if event.pressed:

			clicou = true


	if clicou:

		_abrir_painel_evolucao()


# ============================================================
# DANO EFETIVO
# ============================================================

func _dano_efetivo() -> int:

	return int(
		round(
			dano_base * pow(1.5, nivel_evolucao)
		)
	)


# ============================================================
# CUSTO DA PRÓXIMA EVOLUÇÃO
# ============================================================

func _custo_proxima_evolucao() -> int:

	# GDD: a 1ª evolução custa metade do valor da torre; as seguintes,
	# metade do valor da torre * o número da evolução. Nas Prime esse
	# "valor da torre" é o preço em moeda lunar, não em ouro.
	var base: int = custo_lunar if _eh_prime() else custo

	var metade: int = max(
		1,
		int(round(base / 2.0))
	)

	return metade * (nivel_evolucao + 1)


# ============================================================
# VALOR DE REEMBOLSO AO REMOVER
# ============================================================
# Devolve metade de tudo que foi gasto nessa torre (colocação + todas as
# evoluções), na MESMA moeda em que foi gasto -- ouro nas básicas, lunar
# nas Prime.

func _reembolso_coin() -> int:

	return int(round(_gasto_coin / 2.0))


func _reembolso_lunar() -> int:

	return int(round(_gasto_lunar / 2.0))


func _texto_reembolso() -> String:

	var lunar: int = _reembolso_lunar()

	var coin: int = _reembolso_coin()


	if lunar > 0 and coin > 0:

		return "%d lunar + %d moedas" % [lunar, coin]

	if lunar > 0:

		return "%d lunar" % lunar

	return "%d moedas" % coin


# ============================================================
# ABRIR PAINEL DE EVOLUÇÃO
# ============================================================

func _abrir_painel_evolucao() -> void:

	if is_instance_valid(_painel_atual):

		return


	var custo_evolucao: int = _custo_proxima_evolucao()


	var texto_bonus: String = ""


	# A cada 8 níveis o debuff ganha +8%.
	if (nivel_evolucao + 1) % 8 == 0 and (causa_lentidao or causa_dano_continuo):

		texto_bonus = "\nEssa evolução também deixa o debuff 8% mais forte!"


	var painel: Node = PAINEL_INFO_SCENE.instantiate()

	add_child(painel)

	painel.global_position = global_position + Vector2(-115, -140)


	var unidade_evolucao: String = "lunar" if _eh_prime() else "moedas"

	painel.configurar(
		"%s -- nível %d" % [
			_nome_da_torre(),
			nivel_evolucao
		],
		"Dano atual: %d\nPróxima evolução: %d %s\nRemover: +%s%s" % [
			_dano_efetivo(),
			custo_evolucao,
			unidade_evolucao,
			_texto_reembolso(),
			texto_bonus
		],
		"Evoluir",
		true,
		"Fechar",
		true
	)


	painel.confirmar_pressionado.connect(
		_on_confirmar_evolucao
	)

	painel.cancelar_pressionado.connect(
		_fechar_painel_atual
	)

	painel.remover_pressionado.connect(
		_on_remover_torre
	)


	_painel_atual = painel

	_painel_evolucao_aberto = true

	_atualizar_exibicao_alcance()


# ============================================================
# CONFIRMAR EVOLUÇÃO
# ============================================================

func _on_confirmar_evolucao() -> void:

	var custo_evolucao: int = _custo_proxima_evolucao()


	var pago: bool = false


	if _eh_prime():

		pago = Progresso.gastar_moeda_lunar(custo_evolucao)

		if pago:

			_gasto_lunar += custo_evolucao

	else:

		pago = ControleDeTudo.gastar_coin(custo_evolucao)

		if pago:

			_gasto_coin += custo_evolucao


	if not pago:

		ControleDeTudo.invalido.emit()

		return


	nivel_evolucao += 1


	# A cada 8 níveis (8, 16, 24...) o debuff ganha +8%.
	if nivel_evolucao % 8 == 0:

		if causa_lentidao:

			percentual_lentidao = minf(
				LIMITE_LENTIDAO,
				percentual_lentidao + BONUS_DEBUFF_A_CADA_8_NIVEIS
			)

		if causa_dano_continuo:

			percentual_dot += BONUS_DEBUFF_A_CADA_8_NIVEIS


	_fechar_painel_atual()


# ============================================================
# REMOVER TORRE
# ============================================================

func _on_remover_torre() -> void:

	var coin: int = _reembolso_coin()

	var lunar: int = _reembolso_lunar()


	if coin > 0:

		ControleDeTudo.ganhar_coin(coin)


	if lunar > 0:

		Progresso.adicionar_moeda_lunar(lunar)


	_fechar_painel_atual()

	queue_free()


# ============================================================
# FECHAR PAINEL
# ============================================================

func _fechar_painel_atual() -> void:

	if is_instance_valid(_painel_atual):

		_painel_atual.queue_free()


	_painel_atual = null

	_painel_evolucao_aberto = false

	_atualizar_exibicao_alcance()


# ============================================================
# NOME DA TORRE
# ============================================================

func _nome_da_torre() -> String:

	match tipo_torre:

		"irrigador":

			return "Irrigador Giratório"

		"irrigador_prime":

			return "Irrigador Giratório Prime"

		"mangueira_prime":

			return "Mangueira Prime"

		_:

			return "Mangueira"
