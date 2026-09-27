extends Node2D

# ============================================================
# CONFIGURAÇÃO BÁSICA
# ============================================================

# tipo_torre/custo são preenchidos pela loja (lojaScripit.gd) quando o
# jogador compra essa torre. dano_base e os outros exports já vêm prontos
# de cada cena de torre (cenas/torres/mangueira.tscn, irrigador.tscn).

@export var tipo_torre: String = "basica"
@export var custo: int = 10
@export var dano_base: int = 10

@export var projetil_scene: PackedScene
@export var cadencia: float = 1.0
@export var velocidade_projetil: float = 400.0
@export var life: int = 30  # vestigial -- torres não tomam mais dano, ver tomar_dano()
@export var alcance: float = 200.0


# ============================================================
# LENTIDÃO
# ============================================================

@export var causa_lentidao: bool = false
@export var percentual_lentidao: float = 0.18
@export var duracao_lentidao: float = 3.0


# ============================================================
# MODO DE ATAQUE
# ============================================================

@export_enum("mira", "giratorio") var modo_ataque: String = "mira"
@export var velocidade_rotacao: float = 3.0


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


# ============================================================
# NÓS
# ============================================================

@onready var area_alcance: Area2D = $are
@onready var ponto_de_tiro: Marker2D = $PontoDeTiro
@onready var area_de_receber_b_: Area2D = $"areaDeReceberB="
@onready var collision_shape_2d: CollisionShape2D = $are/CollisionShape2D
@onready var node_2d: Node2D = $"."

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
var pode_atirar: bool = true

# Tempo acumulado desde o último disparo no modo giratório.
var _tempo_desde_ultimo_tiro: float = 0.0


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


	match modo_ataque:

		"giratorio":

			_processar_modo_giratorio(delta)

		_:

			_processar_modo_mira(delta)


# ============================================================
# MODO MIRA
# ============================================================

func _processar_modo_mira(_delta: float) -> void:

	# Remove alvos inválidos ou inimigos que já estão morrendo.
	for area in inimigos_no_alcance.duplicate():

		if not is_instance_valid(area):

			inimigos_no_alcance.erase(area)

			continue


		var inimigo: Node = area.get_parent()


		if not is_instance_valid(inimigo):

			inimigos_no_alcance.erase(area)

			continue


		if inimigo.has_method("esta_morrendo"):

			if inimigo.esta_morrendo():

				inimigos_no_alcance.erase(area)


	# Não tem inimigos válidos.
	if inimigos_no_alcance.is_empty():

		return


	var alvo: Area2D = inimigos_no_alcance[0]


	if not is_instance_valid(alvo):

		inimigos_no_alcance.erase(alvo)

		return


	var inimigo: Node = alvo.get_parent()


	if not is_instance_valid(inimigo):

		inimigos_no_alcance.erase(alvo)

		return


	# NÃO atira em inimigo que está morrendo.
	if inimigo.has_method("esta_morrendo"):

		if inimigo.esta_morrendo():

			inimigos_no_alcance.erase(alvo)

			return


	rotacionar_para(alvo)


	if pode_atirar:

		atirar(alvo)


# ============================================================
# ROTACIONAR
# ============================================================

func rotacionar_para(alvo: Area2D):

	var direcao: Vector2 = alvo.global_position - global_position

	rotation = direcao.angle()


# ============================================================
# ATIRAR (MODO MIRA)
# ============================================================

func atirar(alvo: Area2D):

	if not is_instance_valid(alvo):

		return


	# O script do inimigo está no pai da Area2D.
	var inimigo: Node = alvo.get_parent()


	if not is_instance_valid(inimigo):

		return


	# Verifica se o inimigo já está morrendo.
	if inimigo.has_method("esta_morrendo"):

		if inimigo.esta_morrendo():

			inimigos_no_alcance.erase(alvo)

			return


	# Segurança extra.
	if "vida" in inimigo:

		if inimigo.vida <= 0:

			inimigos_no_alcance.erase(alvo)

			return


	# Só depois de todas as verificações bloqueia o próximo tiro.
	pode_atirar = false


	var direcao: Vector2 = (
		alvo.global_position -
		ponto_de_tiro.global_position
	).normalized()


	_criar_projetil(ponto_de_tiro.global_position, direcao)


	await get_tree().create_timer(cadencia).timeout


	# A torre pode ter sido destruída durante o await.
	if is_instance_valid(self):

		pode_atirar = true


# ============================================================
# MODO GIRATÓRIO
# ============================================================

# Só o Marker2D (PontoDeTiro) orbita a torre -- o corpo/sprite não gira
# mais. O ângulo dele também é usado pra decidir de onde saem os tiros.
func _processar_modo_giratorio(delta: float) -> void:

	_angulo_ponto_de_tiro += velocidade_rotacao * delta

	var offset: Vector2 = Vector2.RIGHT.rotated(_angulo_ponto_de_tiro) * _raio_ponto_de_tiro

	ponto_de_tiro.position = offset
	ponto_de_tiro.rotation = _angulo_ponto_de_tiro


	if not pode_atirar:

		return


	_tempo_desde_ultimo_tiro += delta


	if _tempo_desde_ultimo_tiro >= cadencia:

		_tempo_desde_ultimo_tiro = 0.0

		atirar_sem_mira()


# Dispara dois tiros ao mesmo tempo: um sai do lado onde o Marker2D está
# no momento, indo pra fora do centro; o outro sai do lado oposto do
# círculo, indo na direção oposta. Os dois nascem e somem juntos.
func atirar_sem_mira() -> void:

	pode_atirar = false

	var offset: Vector2 = ponto_de_tiro.position
	var direcao: Vector2 = offset.normalized()

	_criar_projetil(global_position + offset, direcao)
	_criar_projetil(global_position - offset, -direcao)


	await get_tree().create_timer(cadencia).timeout


	if is_instance_valid(self):

		pode_atirar = true


# ============================================================
# DISPARO (compartilhado pelos dois modos)
# ============================================================

func _criar_projetil(pos_global: Vector2, direcao: Vector2) -> void:

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


	if causa_lentidao:

		projetil.causa_lentidao = true

		projetil.percentual_lentidao = percentual_lentidao

		projetil.duracao_lentidao = duracao_lentidao


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
	# (O painel de colocação continua exigindo Confirmar/Cancelar.)
	if is_instance_valid(_painel_atual) and _painel_evolucao_aberto:

		var pos = _posicao_global_do_clique(event)

		if pos != null and not (_painel_atual as Control).get_global_rect().has_point(pos):

			_fechar_painel_atual()

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

	# Não deixa confirmar posição proibida.
	if not NetworkManager.posicao_torre_valida(global_position):

		ControleDeTudo.invalido.emit()

		return


	# Só confere se dá para pagar.
	if ControleDeTudo.coin < custo:

		ControleDeTudo.invalido.emit()

		return


	# Posição válida e dinheiro suficiente.
	arrastando = false

	aguardando_confirmacao = true

	_atualizar_exibicao_alcance()

	_abrir_painel_colocacao()


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
		"Dano: %d\nAlcance: %d\nCusto: %d moedas%s" % [
			dano_base,
			int(alcance),
			custo,
			(
				"\nDeixa os inimigos lentos"
				if causa_lentidao
				else
				"\nAtira sem mirar, girando"
			)
		],
		"Confirmar",
		true
	)


	painel.confirmar_pressionado.connect(
		_on_confirmar_colocacao
	)

	painel.cancelar_pressionado.connect(
		_on_cancelar_colocacao
	)


	_painel_atual = painel


# ============================================================
# CONFIRMAR COLOCAÇÃO
# ============================================================

func _on_confirmar_colocacao() -> void:

	if not ControleDeTudo.gastar_coin(custo):

		ControleDeTudo.invalido.emit()

		_on_cancelar_colocacao()

		return


	aguardando_confirmacao = false

	area_de_receber_b_.monitorable = true

	_fechar_painel_atual()


# ============================================================
# CANCELAR COLOCAÇÃO
# ============================================================

func _on_cancelar_colocacao() -> void:

	aguardando_confirmacao = false

	arrastando = true

	_fechar_painel_atual()


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

	# 1ª evolução = metade do valor da torre.
	# Cada evolução seguinte dobra o custo anterior.

	var primeira_evolucao: int = max(
		1,
		int(round(custo / 2.0))
	)


	var multiplicador: int = int(
		pow(2, nivel_evolucao)
	)


	return primeira_evolucao * multiplicador


# ============================================================
# VALOR DE REEMBOLSO AO REMOVER
# ============================================================

func _valor_de_remocao() -> int:

	# Metade do valor da torre + o nível de evolução dela em dinheiro.
	return int(round(custo / 2.0)) + nivel_evolucao


# ============================================================
# ABRIR PAINEL DE EVOLUÇÃO
# ============================================================

func _abrir_painel_evolucao() -> void:

	if is_instance_valid(_painel_atual):

		return


	var custo_evolucao: int = _custo_proxima_evolucao()


	var texto_bonus: String = ""


	if nivel_evolucao == 7:

		texto_bonus = (
			"\nEssa evolução também deixa a lentidão 10% mais forte!"
		)


	var painel: Node = PAINEL_INFO_SCENE.instantiate()

	add_child(painel)

	painel.global_position = global_position + Vector2(-115, -140)


	painel.configurar(
		"%s -- nível %d" % [
			_nome_da_torre(),
			nivel_evolucao
		],
		"Dano atual: %d\nPróxima evolução: %d moedas\nRemover: +%d moedas%s" % [
			_dano_efetivo(),
			custo_evolucao,
			_valor_de_remocao(),
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


	if not ControleDeTudo.gastar_coin(custo_evolucao):

		ControleDeTudo.invalido.emit()

		return


	nivel_evolucao += 1


	# Só ao alcançar o nível 8 a lentidão aumenta.
	if nivel_evolucao == 8 and causa_lentidao:

		percentual_lentidao += 0.10


	_fechar_painel_atual()


# ============================================================
# REMOVER TORRE
# ============================================================

func _on_remover_torre() -> void:

	ControleDeTudo.ganhar_coin(_valor_de_remocao())

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

		_:

			return "Mangueira"
