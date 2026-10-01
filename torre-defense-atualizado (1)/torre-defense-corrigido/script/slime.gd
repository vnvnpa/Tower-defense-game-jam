extends Node2D

# ============================================================
# TIPOS DE INIMIGO
# ============================================================

enum TipoInimigo {
	SLIME_COMUM,
	BOSS,
	RIMURU,
	EXPLOSIVO
}


# ============================================================
# CONFIGURAÇÃO
# ============================================================

@export_category("Configuração do Inimigo")

@export var tipo_inimigo: TipoInimigo = TipoInimigo.SLIME_COMUM

# Esses valores podem ser alterados normalmente pelo Inspetor.
@export var vida: int = 25
@export var velocidade: float = 90.0


@export_category("Habilidade Especial")

@export var usar_habilidade: bool = false
@export var tempo_habilidade: float = 8.0


@export_category("Explosivo")

@export var dano_explosao: int = 30
@export var raio_explosao: float = 100.0


# ============================================================
# NÓS
# ============================================================

@onready var vida_label: Label = $ColorRect/vida
@onready var color_rect: ColorRect = $ColorRect
@onready var slime: AnimatedSprite2D = $slime


# ============================================================
# VARIÁVEIS
# ============================================================

var posicao_anterior: Vector2 = Vector2.ZERO
var tempo_habilidade_atual: float = 0.0

# ------------------------------------------------------------
# LENTIDÃO
# ------------------------------------------------------------
# Quem realmente anda é o PathFollow2D pai (ver path_follow_2d.gd), então
# a lentidão mexe na velocidade DELE, não na desse nó. _velocidade_base_path
# guarda a velocidade "cheia" original pra não ir diminuindo a cada acerto.
var _velocidade_base_path: float = -1.0
var _lentidao_token: int = 0

# DANO CONTÍNUO (irrigadores): a cada 1s toma "_dot_dano" até acabar o
# tempo. Feito no _process (sem await) pra não dar erro se o slime morrer
# no meio. Não empilha: um novo acerto só renova o tempo.
var _dot_restante: float = 0.0
var _dot_dano: int = 0
var _dot_acumulado: float = 0.0

# Impede a animação de movimento de substituir
# uma animação especial.
var _tocando_animacao_unica: bool = false

# Cooldown do Rimuru DEPOIS de engolir um projétil (só ele usa isso --
# ver _processar_predador()). Enquanto for 0, ele fica de olho o tempo
# todo em qualquer projétil vindo na direção dele.
var _cooldown_predador_atual: float = 0.0

# Vida com que esse inimigo nasceu (antes de qualquer cura). Usado só
# pelo Rimuru, pra saber até onde a cura dele pode passar -- ver
# recuperar_vida().
var _vida_inicial: int = 0

# Velocidade que o Rimuru tinha bem antes de parar pra comer (ver
# tocar_engolir()/_retomar_andar()). Guardada à parte da lentidão
# (_velocidade_base_path) pra não bagunçar um efeito de lentidão que
# esteja rolando ao mesmo tempo.
var _velocidade_antes_de_comer: float = -1.0

# Impede que o inimigo receba dano depois de morrer.
var _morrendo: bool = false

# Evita chamar a remoção mais de uma vez.
var _remocao_iniciada: bool = false


# ============================================================
# READY
# ============================================================

func _ready():

	posicao_anterior = global_position

	color_rect.position.y = -50

	vida_label.text = str(vida)

	_vida_inicial = vida

	# Conecta o sinal da animação.
	if not slime.animation_finished.is_connected(_on_animacao_terminou):
		slime.animation_finished.connect(_on_animacao_terminou)


# ============================================================
# PROCESS
# ============================================================

func _process(delta):

	# Se morreu, não executa mais o comportamento normal.
	if _morrendo:
		return


	_processar_dano_continuo(delta)

	if _morrendo:
		return


	# ========================================================
	# MOVIMENTO
	# ========================================================

	var delta_pos = global_position - posicao_anterior

	posicao_anterior = global_position


	# ========================================================
	# ANIMAÇÃO DE MOVIMENTO
	# ========================================================

	if not _tocando_animacao_unica and delta_pos.length() > 0.01:

		if abs(delta_pos.x) > abs(delta_pos.y):

			if slime.animation != "andarLado":
				slime.play("andarLado")

			slime.flip_h = delta_pos.x < 0

		else:

			if slime.animation != "andarFrente":
				slime.play("andarFrente")

			slime.flip_v = delta_pos.y < 0


	# ========================================================
	# HABILIDADE
	# ========================================================

	if usar_habilidade:

		if tipo_inimigo == TipoInimigo.RIMURU:

			# O Rimuru NÃO espera 8 segundos pra checar se tem projétil
			# vindo -- ele fica de olho TODO frame. O cooldown de
			# tempo_habilidade só entra em ação DEPOIS que ele engole um
			# projétil, pra não ficar comendo bala toda hora sem parar.
			if _cooldown_predador_atual > 0.0:

				_cooldown_predador_atual -= delta

			elif predador():

				_cooldown_predador_atual = tempo_habilidade

		else:

			tempo_habilidade_atual += delta

			if tempo_habilidade_atual >= tempo_habilidade:

				tempo_habilidade_atual = 0.0

				usar_habilidade_especial()


# ============================================================
# LENTIDÃO
# ============================================================
# Chamada pela bala da Mangueira (projetil.gd) quando acerta esse slime.
# Reduz a velocidade em "percentual" por "duracao" segundos. Se o slime
# já está lento e é atingido de novo, o efeito NÃO empilha (não fica
# cada vez mais lento) -- só renova o tempo, partindo sempre da
# velocidade original.
func aplicar_lentidao(percentual: float, duracao: float) -> void:

	if _morrendo:
		return

	var pai = get_parent()

	if not is_instance_valid(pai) or not ("velocidade" in pai):
		return

	if _velocidade_base_path < 0.0:
		_velocidade_base_path = pai.velocidade

	pai.velocidade = _velocidade_base_path * (1.0 - percentual)

	_lentidao_token += 1
	var meu_token = _lentidao_token

	await get_tree().create_timer(duracao).timeout

	# Uma lentidão mais nova já assumiu o controle -- deixa ela decidir
	# quando a velocidade volta ao normal.
	if meu_token != _lentidao_token:
		return

	if is_instance_valid(pai):
		pai.velocidade = _velocidade_base_path


# ============================================================
# DANO CONTÍNUO
# ============================================================
# Chamada pela bala do Irrigador (projetil.gd). Renova o efeito se o slime
# já estiver sofrendo dele.
func aplicar_dano_continuo(dano_por_tick: int, duracao: float) -> void:

	if _morrendo:
		return

	_dot_dano = dano_por_tick
	_dot_restante = duracao
	_dot_acumulado = 0.0


func _processar_dano_continuo(delta: float) -> void:

	if _dot_restante <= 0.0:
		return

	_dot_restante -= delta
	_dot_acumulado += delta

	while _dot_acumulado >= 1.0 and not _morrendo:

		_dot_acumulado -= 1.0
		tomar_dano(_dot_dano)

	if _dot_restante <= 0.0:
		_dot_acumulado = 0.0


# ============================================================
# TOMAR DANO
# ============================================================

func tomar_dano(dano: int):

	# Já morreu? Ignora qualquer dano.
	if _morrendo:
		return


	vida -= dano


	# Impede vida negativa.
	if vida < 0:
		vida = 0


	vida_label.text = str(vida)


	# ========================================================
	# MORTE
	# ========================================================

	if vida <= 0:

		morrer()

	else:

		_tocar_animacao_unica("hit")


# ============================================================
# ANIMAÇÃO ÚNICA
# ============================================================

func _tocar_animacao_unica(nome_animacao: String):

	if not slime.sprite_frames.has_animation(nome_animacao):
		return

	_tocando_animacao_unica = true

	slime.play(nome_animacao)


# ============================================================
# MORTE
# ============================================================
func esta_morrendo() -> bool:
	return _morrendo

func morrer():

	if _morrendo:
		return


	_morrendo = true


	# Vida fica definitivamente em 0.
	vida = 0
	vida_label.text = "0"


	# ========================================================
	# EXPLOSIVO
	# ========================================================

	if tipo_inimigo == TipoInimigo.EXPLOSIVO:

		explodir()


	# ========================================================
	# MOEDA
	# ========================================================

	ControleDeTudo.ganhar_coin(1)


	# ========================================================
	# MOEDA LUNAR (só bosses e o Rimuru dropam)
	# ========================================================

	match tipo_inimigo:

		TipoInimigo.RIMURU:

			Progresso.adicionar_moeda_lunar(5)

		TipoInimigo.BOSS:

			Progresso.adicionar_moeda_lunar(1)


	# ========================================================
	# ESTATÍSTICAS (tela de perfil)
	# ========================================================

	match tipo_inimigo:

		TipoInimigo.SLIME_COMUM:

			Progresso.registrar_abate_comum()

		TipoInimigo.BOSS, TipoInimigo.EXPLOSIVO:

			Progresso.registrar_abate_raro()

		TipoInimigo.RIMURU:

			Progresso.registrar_abate_rimuru()


	# ========================================================
	# PARA O PATHFOLLOW2D
	# ========================================================

	var pai = get_parent()

	if is_instance_valid(pai):

		pai.set_process(false)


	# ========================================================
	# DESATIVA COLISÃO
	# ========================================================

	if has_node("Area2D"):

		var area = $Area2D

		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)


	# ========================================================
	# ANIMAÇÃO DE MORTE
	# ========================================================

	if slime.sprite_frames.has_animation("die"):

		_tocando_animacao_unica = true


		# ----------------------------------------------------
		# IMPORTANTE:
		# Força a animação de morte a NÃO ficar em loop.
		# ----------------------------------------------------

		slime.sprite_frames.set_animation_loop("die", false)


		# Começa a animação.
		slime.play("die")


	else:

		# Se não existe "die", remove imediatamente.
		_remover_inimigo()


# ============================================================
# ANIMAÇÃO TERMINOU
# ============================================================

func _on_animacao_terminou():

	# Só nos interessa o final da animação de morte.
	if slime.animation == "die":

		_remover_inimigo()

		return


	# Terminou de "comer" -- volta a andar normalmente.
	if slime.animation == "swallow":

		_retomar_andar()


	# Hit / swallow.
	if not _morrendo:

		_tocando_animacao_unica = false


# ============================================================
# REMOVER INIMIGO
# ============================================================

func _remover_inimigo():

	# Evita remoção duplicada.
	if _remocao_iniciada:
		return


	_remocao_iniciada = true


	# ========================================================
	# PEGA O PAI
	# ========================================================

	var pai = get_parent()


	# ========================================================
	# REMOVE O PATHFOLLOW2D
	# ========================================================

	if is_instance_valid(pai):

		pai.queue_free()

	else:

		queue_free()


# ============================================================
# HABILIDADES
# ============================================================

func usar_habilidade_especial():

	if _morrendo:
		return


	match tipo_inimigo:

		TipoInimigo.EXPLOSIVO:

			# A explosão acontece somente na morte.
			pass

		# TipoInimigo.RIMURU não passa por aqui -- ele tem seu próprio
		# gatilho por frame em _process() (ver _cooldown_predador_atual),
		# porque a habilidade dele depende de ter um projétil vindo, não
		# só de o tempo passar.


# ============================================================
# PREDADOR - RIMURU
# ============================================================
# Devora o PRIMEIRO projétil de água que esteja vindo em direção a ele.
# Chamado a cada frame (ver _process()) enquanto não estiver em cooldown.
# Retorna true se comeu algum projétil (aí sim entra em cooldown de
# tempo_habilidade segundos); false se não achou nada pra comer (nesse
# caso continua checando no próximo frame, sem gastar cooldown nenhum).

func predador() -> bool:

	if tipo_inimigo != TipoInimigo.RIMURU or _morrendo:
		return false


	var balas = get_tree().get_nodes_in_group("projetil_agua")


	for bala in balas:

		if not is_instance_valid(bala):
			continue


		var direcao_ate_rimuru = (
			global_position - bala.global_position
		).normalized()


		var esta_vindo_para_rimuru = (
			bala.direcao.dot(direcao_ate_rimuru) > 0.5
		)


		if esta_vindo_para_rimuru:

			print("Rimuru devorou um projétil de água!")

			bala.queue_free()
			tocar_engolir()
			recuperar_vida(80)

			return true


	return false


# ============================================================
# ANIMAÇÃO DE ENGOLIR
# ============================================================

func tocar_engolir() -> void:

	if _morrendo:
		return


	_parar_para_comer()

	_tocar_animacao_unica("swallow")


# Fica parado (velocidade 0) enquanto a animação de devorar toca, pra dar
# pra ver o Rimuru comendo em vez dele continuar andando por cima da
# animação. Guarda a velocidade que ele tinha ANTES de parar (pode já
# estar lento por causa de aplicar_lentidao()) pra devolver exatamente
# ela depois -- ver _retomar_andar(), chamada quando a animação acaba.
func _parar_para_comer() -> void:

	var pai = get_parent()

	if not is_instance_valid(pai) or not ("velocidade" in pai):
		return

	_velocidade_antes_de_comer = pai.velocidade
	pai.velocidade = 0.0


func _retomar_andar() -> void:

	if _velocidade_antes_de_comer < 0.0:
		return

	var pai = get_parent()

	if is_instance_valid(pai) and ("velocidade" in pai):
		pai.velocidade = _velocidade_antes_de_comer

	_velocidade_antes_de_comer = -1.0


# ============================================================
# RECUPERAR VIDA
# ============================================================

func recuperar_vida(valor: int):

	if _morrendo:
		return


	vida += valor

	# Cura pode passar da vida inicial (o Rimuru "engorda" com cada
	# projétil que devora), só não deixa isso virar infinito: o teto é
	# o dobro da vida com que ele nasceu.
	var teto := _vida_inicial * 2 if _vida_inicial > 0 else vida
	vida = min(vida, teto)

	vida_label.text = str(vida)

	print(
		"Rimuru recuperou ",
		valor,
		" de vida. Vida: ",
		vida
	)


# ============================================================
# EXPLOSÃO
# ============================================================

func explodir():

	print("Inimigo explosivo explodiu!")


	var objetos = get_tree().get_nodes_in_group("torres")


	for objeto in objetos:

		if not is_instance_valid(objeto):
			continue


		var distancia = global_position.distance_to(
			objeto.global_position
		)


		if distancia <= raio_explosao:

			if objeto.has_method("tomar_dano"):

				objeto.tomar_dano(dano_explosao)


			if objeto.has_method("anestesiar"):

				objeto.anestesiar()
