extends Node2D

# tipo_torre/cena_torre são preenchidos pela loja (lojaScripit.gd) quando o
# jogador compra essa torre. São usados só na hora de pedir o spawn de
# verdade pro host (NetworkManager.pedir_spawn_torre).
@export var tipo_torre: String = "basica"
var cena_torre: String = ""

var arrastando: bool = true
var pronto_para_fixar: bool = false

@export var projetil_scene: PackedScene
@export var cadencia: float = 1.0
@export var velocidade_projetil: float = 400.0
@export var life: int = 30


@onready var area_alcance: Area2D = $are
@onready var ponto_de_tiro: Marker2D = $PontoDeTiro

@onready var area_de_receber_b_: Area2D = $"areaDeReceberB="

@onready var collision_shape_2d: CollisionShape2D = $are/CollisionShape2D


@onready var node_2d: Node2D = $"."
@export var alcance := 200.0
var mostrar_alcance := false

func _draw():
	if mostrar_alcance:
		draw_arc(
			Vector2.ZERO,
			alcance,
			0,
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

var inimigos_no_alcance: Array = []
var pode_atirar: bool = true

func _ready():
	await get_tree().process_frame
	pronto_para_fixar = true
	area_alcance.area_entered.connect(_on_inimigo_entrou)
	area_alcance.area_exited.connect(_on_inimigo_saiu)
	# Se já chegou "fixada" (torre real, instanciada em rede pelo host com
	# arrastando = false antes do add_child), ela já pode ser alvo de ataque.
	# Se ainda é só o preview seguindo o mouse, continua não-monitorável.
	area_de_receber_b_.monitorable = not arrastando

	area_alcance.input_pickable = true
	area_de_receber_b_.mouse_entered.connect(_on_mouse_entered)
	area_de_receber_b_.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	mostrar()

func _on_mouse_exited():
	esconder()

func _process(_delta):
	if arrastando:
		global_position = get_global_mouse_position()
		return

	# Remove alvos inválidos ou inimigos que já estão morrendo
	for area in inimigos_no_alcance.duplicate():
		if not is_instance_valid(area):
			inimigos_no_alcance.erase(area)
			continue

		var inimigo = area.get_parent()

		if not is_instance_valid(inimigo):
			inimigos_no_alcance.erase(area)
			continue

		if inimigo.has_method("esta_morrendo"):
			if inimigo.esta_morrendo():
				inimigos_no_alcance.erase(area)

	# Não tem inimigos válidos
	if inimigos_no_alcance.is_empty():
		return

	var alvo: Area2D = inimigos_no_alcance[0]

	if not is_instance_valid(alvo):
		inimigos_no_alcance.erase(alvo)
		return

	var inimigo = alvo.get_parent()

	if not is_instance_valid(inimigo):
		inimigos_no_alcance.erase(alvo)
		return

	# NÃO atira em inimigo que está morrendo
	if inimigo.has_method("esta_morrendo"):
		if inimigo.esta_morrendo():
			inimigos_no_alcance.erase(alvo)
			return

	rotacionar_para(alvo)

	if pode_atirar:
		atirar(alvo)
func rotacionar_para(alvo: Area2D):
	var direcao = alvo.global_position - global_position
	rotation = direcao.angle()

func atirar(alvo: Area2D):
	if not is_instance_valid(alvo):
		return

	# O script do inimigo está no pai da Area2D
	var inimigo = alvo.get_parent()

	if not is_instance_valid(inimigo):
		return

	# Verifica se o inimigo já está morrendo
	if inimigo.has_method("esta_morrendo"):
		if inimigo.esta_morrendo():
			inimigos_no_alcance.erase(alvo)
			return

	# Segurança extra
	if "vida" in inimigo:
		if inimigo.vida <= 0:
			inimigos_no_alcance.erase(alvo)
			return

	# Só depois de todas as verificações bloqueia o próximo tiro
	pode_atirar = false

	var direcao = (
		alvo.global_position -
		ponto_de_tiro.global_position
	).normalized()

	var projetil = projetil_scene.instantiate()

	get_tree().current_scene.add_child(projetil)

	projetil.global_position = ponto_de_tiro.global_position
	projetil.rotation = direcao.angle()

	projetil.setup(
		direcao,
		velocidade_projetil
	)

	await get_tree().create_timer(cadencia).timeout

	# A torre pode ter sido destruída durante o await
	if is_instance_valid(self):
		pode_atirar = true

func _on_inimigo_entrou(area):
	if area.is_in_group("inimigos"):
		inimigos_no_alcance.append(area)

func _on_inimigo_saiu(area):
	inimigos_no_alcance.erase(area)

func tomar_dano(dano: int):
	life -= dano
	if life <= 0:
		queue_free()

func _unhandled_input(event):
	if not arrastando or not pronto_para_fixar:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			colocar()
	elif event is InputEventScreenTouch:
		if event.pressed:
			global_position = event.position
			colocar()

func colocar():
	# FIX: antes descontava a moeda direto aqui (ControleDeTudo.coin -= 10),
	# sem passar pelo host nem validar saldo -- cada peer via um valor
	# diferente de moeda. Agora esse nó é só o PREVIEW que seguiu o mouse:
	# ele pede o spawn de verdade pro host (que valida o custo) e se destrói.
	# A torre "oficial" chega pra todo mundo (inclusive quem pediu) através
	# de NetworkManager.spawnar_torre.
	if cena_torre == "":
		cena_torre = scene_file_path
	NetworkManager.pedir_spawn_torre.rpc_id(1, tipo_torre, cena_torre, global_position)
	queue_free()
