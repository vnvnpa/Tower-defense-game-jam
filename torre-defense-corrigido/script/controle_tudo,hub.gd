extends CanvasLayer

@onready var coin_label: Label = $MarginContainer/VBoxContainer/coinLabel
@onready var vida_label: Label = $MarginContainer/VBoxContainer/vidaLabel

# Barra de água (limite evoluível permanentemente -- ver Progresso.gd e
# ControleDeTudo.gd). Só aparece a partir do nível 2, quando as torres
# passam a gastar água.
@onready var agua_container: Control = $MarginContainer/VBoxContainer/AguaContainer
@onready var agua_barra: ProgressBar = $MarginContainer/VBoxContainer/AguaContainer/AguaBarra
@onready var agua_label: Label = $MarginContainer/VBoxContainer/AguaContainer/AguaLabel
@onready var lunar_label: Label = $MarginContainer/VBoxContainer/lunarLabel


func _ready() -> void:
	pass
	

func _physics_process(delta: float) -> void:
	coin_label.text = str(ControleDeTudo.coin)
	vida_label.text = str(ControleDeTudo.vida)
	
	lunar_label.text = "Lunar: %d" % Progresso.moeda_lunar
	
	agua_container.visible = ControleDeTudo.agua_ativa()

	agua_barra.max_value = ControleDeTudo.agua_maxima
	agua_barra.value = ControleDeTudo.agua_atual
	agua_label.text = "%d/%d" % [ControleDeTudo.agua_atual, ControleDeTudo.agua_maxima]
