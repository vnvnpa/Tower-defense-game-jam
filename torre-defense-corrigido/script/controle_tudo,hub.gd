extends CanvasLayer

@onready var coin_label: Label = $MarginContainer/VBoxContainer/coinLabel
@onready var vida_label: Label = $MarginContainer/VBoxContainer/vidaLabel


func _ready() -> void:
	pass
	

func _physics_process(delta: float) -> void:
	coin_label.text = str(ControleDeTudo.coin)
	vida_label.text = str(ControleDeTudo.vida)
