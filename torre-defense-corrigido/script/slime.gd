extends Node2D

# ============================================================
# TIPOS DE INIMIGO
# ============================================================

enum TipoInimigo {
	SLIME_COMUM,
	BOSS_VERMELHO,
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

# Impede a animação de movimento de substituir
# uma animação especial.
var _tocando_animacao_unica: bool = false

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

		tempo_habilidade_atual += delta

		if tempo_habilidade_atual >= tempo_habilidade:

			tempo_habilidade_atual = 0.0

			usar_habilidade_especial()


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

		TipoInimigo.RIMURU:

			predador()


		TipoInimigo.EXPLOSIVO:

			# A explosão acontece somente na morte.
			pass


# ============================================================
# PREDADOR - RIMURU
# ============================================================

func predador():

	if tipo_inimigo != TipoInimigo.RIMURU:
		return


	if not multiplayer.is_server():
		return


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


			NetworkManager.aplicar_predador.rpc(
				get_path(),
				bala.get_path()
			)


			return


# ============================================================
# ANIMAÇÃO DE ENGOLIR
# ============================================================

func tocar_engolir() -> void:

	if _morrendo:
		return


	_tocar_animacao_unica("swallow")


# ============================================================
# RECUPERAR VIDA
# ============================================================

func recuperar_vida(valor: int):

	if _morrendo:
		return


	vida += valor

	vida = min(vida, 150)

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
