extends CanvasLayer

@onready var coin_label: Label = $MarginContainer/VBoxContainer/coinLabel
@onready var vida_label: Label = $MarginContainer/VBoxContainer/vidaLabel

# Barra de água (limite evoluível permanentemente -- ver Progresso.gd e
# ControleDeTudo.gd). Por enquanto só mostra o valor; ainda não é gasta
# em nenhum lugar do jogo.
@onready var agua_barra: ProgressBar = $MarginContainer/VBoxContainer/AguaContainer/AguaBarra
@onready var agua_label: Label = $MarginContainer/VBoxContainer/AguaContainer/AguaLabel


func _ready() -> void:
	pass
	

func _physics_process(delta: float) -> void:
	coin_label.text = str(ControleDeTudo.coin)
	vida_label.text = str(ControleDeTudo.vida)

	agua_barra.max_value = ControleDeTudo.agua_maxima
	agua_barra.value = ControleDeTudo.agua_atual
	agua_label.text = "%d/%d" % [ControleDeTudo.agua_atual, ControleDeTudo.agua_maxima]
