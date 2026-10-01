extends Node2D
# Projetil teleguiado: ao atingir, causa dano direto e aplica o efeito da torre.

var target = null
var kind := "bleed"
var damage := 5.0
var speed := 420.0
var color := Color.WHITE

func _process(delta: float) -> void:
    if not is_instance_valid(target) or target.dead:
        queue_free()
        return
    var to: Vector2 = target.global_position - global_position
    if to.length() < speed * delta + 6.0:
        target.take_damage(damage)
        target.apply_effect(kind)
        queue_free()
        return
    global_position += to.normalized() * speed * delta
    queue_redraw()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 4.0, color)
