extends Control
@onready var label: Label = $Label

func _ready() -> void:
	for i in range(0, 4, 1):
		await get_tree().create_timer(0.4).timeout
		label.visible = false
		await get_tree().create_timer(0.4).timeout
		label.visible = true
	queue_free()
	
