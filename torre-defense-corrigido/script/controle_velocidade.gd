extends CanvasLayer
## Controle de velocidade da partida (1x/2x), agora local.

const CENA_PAUSE := preload("res://cenas/menus/pause.tscn")

@onready var botao: Button = $Painel/BotaoVelocidade
@onready var label: Label = $Painel/VelocidadeLabel
@onready var botao_pause: Button = $BotaoPause

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	botao.visible = true
	botao.pressed.connect(_on_botao_pressed)
	botao_pause.pressed.connect(_on_botao_pause_pressed)
	NetworkManager.velocidade_jogo_atualizada.connect(_atualizar)
	_atualizar(NetworkManager.velocidade_jogo)

func _on_botao_pressed() -> void:
	NetworkManager.alternar_velocidade_jogo()

func _on_botao_pause_pressed() -> void:
	# Evita abrir dois menus de pause em cima um do outro se o jogador
	# clicar de novo enquanto já está tudo pausado.
	if get_tree().paused:
		return
	add_child(CENA_PAUSE.instantiate())

func _atualizar(velocidade: float) -> void:
	var texto := "2x" if velocidade >= 1.5 else "1x"
	label.text = "Velocidade: " + texto
	botao.text = "Acelerar (2x)" if velocidade < 1.5 else "Velocidade normal (1x)"
