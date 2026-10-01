extends CanvasLayer
## Controle de velocidade da partida: 1x/2x/4x sempre livres. 6x e 8x só
## depois de desbloqueados (ver Progresso.velocidade_6x/8x_desbloqueada(),
## nos níveis que não liberam mais nada -- 4 e 8 da campanha).

const CENA_PAUSE := preload("res://cenas/menus/pause.tscn")

@onready var label: Label = $Painel/VBox/VelocidadeLabel
@onready var botao_pause: Button = $BotaoPause

@onready var botoes_velocidade: Dictionary = {
	1.0: $Painel/VBox/LinhaVelocidades/Botao1x,
	2.0: $Painel/VBox/LinhaVelocidades/Botao2x,
	4.0: $Painel/VBox/LinhaVelocidades/Botao4x,
	6.0: $Painel/VBox/LinhaVelocidades/Botao6x,
	8.0: $Painel/VBox/LinhaVelocidades/Botao8x,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	botao_pause.pressed.connect(_on_botao_pause_pressed)

	for velocidade in botoes_velocidade:
		var botao: Button = botoes_velocidade[velocidade]
		botao.pressed.connect(_on_velocidade_pressed.bind(velocidade))

	NetworkManager.velocidade_jogo_atualizada.connect(_atualizar)

	_atualizar_bloqueios()
	_atualizar(NetworkManager.velocidade_jogo)


func _on_velocidade_pressed(velocidade: float) -> void:
	NetworkManager.definir_velocidade_local(velocidade)


# Tranca 6x/8x enquanto não desbloqueados, com um tooltip explicando onde
# desbloquear (não precisa reabrir a cena depois de liberar -- ela é
# recarregada toda vez que você entra num nível, então já chega atualizada).
func _atualizar_bloqueios() -> void:
	var botao_6x: Button = botoes_velocidade[6.0]
	var botao_8x: Button = botoes_velocidade[8.0]

	var liberado_6x := Progresso.velocidade_6x_desbloqueada()
	var liberado_8x := Progresso.velocidade_8x_desbloqueada()

	botao_6x.disabled = not liberado_6x
	botao_8x.disabled = not liberado_8x

	botao_6x.tooltip_text = (
		"" if liberado_6x
		else "Desbloqueia ao chegar no nível %d" % Progresso.NIVEL_DESBLOQUEIA_6X
	)
	botao_8x.tooltip_text = (
		"" if liberado_8x
		else "Desbloqueia ao chegar no nível %d" % Progresso.NIVEL_DESBLOQUEIA_8X
	)


func _atualizar(velocidade: float) -> void:
	label.text = "Velocidade: %sx" % _texto_numero(velocidade)

	for v in botoes_velocidade:
		var botao: Button = botoes_velocidade[v]
		botao.button_pressed = is_equal_approx(v, velocidade)


func _texto_numero(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, floor(v)) else str(v)


func _on_botao_pause_pressed() -> void:
	# Evita abrir dois menus de pause em cima um do outro se o jogador
	# clicar de novo enquanto já está tudo pausado.
	if get_tree().paused:
		return
	add_child(CENA_PAUSE.instantiate())
