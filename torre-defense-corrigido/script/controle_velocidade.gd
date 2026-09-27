extends CanvasLayer
## Controle de velocidade da partida (1x/2x), agora local.

@onready var botao: Button = $Painel/BotaoVelocidade
@onready var label: Label = $Painel/VelocidadeLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	botao.visible = true
	botao.pressed.connect(_on_botao_pressed)
	NetworkManager.velocidade_jogo_atualizada.connect(_atualizar)
	_atualizar(NetworkManager.velocidade_jogo)

func _on_botao_pressed() -> void:
	NetworkManager.alternar_velocidade_jogo()

func _atualizar(velocidade: float) -> void:
	var texto := "2x" if velocidade >= 1.5 else "1x"
	label.text = "Velocidade: " + texto
	botao.text = "Acelerar (2x)" if velocidade < 1.5 else "Velocidade normal (1x)"
