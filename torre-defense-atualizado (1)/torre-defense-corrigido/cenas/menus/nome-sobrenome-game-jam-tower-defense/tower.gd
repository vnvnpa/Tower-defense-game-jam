extends Node2D
# Torre: detecta inimigos com Area2D e dispara com um Timer.

const DATA := {
    "bleed": {"name": "Sangramento", "cost": 50, "range": 150.0, "rate": 0.8, "dmg": 10.0,
        "color": Color(0.85, 0.1, 0.1), "desc": "Perfurante: causa sangramento (DOT) por 4s."},
    "burn": {"name": "Fogo", "cost": 80, "range": 120.0, "rate": 1.2, "dmg": 5.0,
        "color": Color(1.0, 0.5, 0.0), "desc": "Queimadura alta (DOT) e o fogo se espalha para inimigos proximos."},
    "freeze": {"name": "Gelo", "cost": 60, "range": 130.0, "rate": 1.0, "dmg": 4.0,
        "color": Color(0.4, 0.85, 1.0), "desc": "Dano leve, mas reduz a velocidade do inimigo em 60%."},
    "poison": {"name": "Veneno", "cost": 70, "range": 140.0, "rate": 1.1, "dmg": 3.0,
        "color": Color(0.3, 0.85, 0.2), "desc": "Drena vida (DOT) e reduz a defesa: +30% de dano recebido."},
}
const ProjectileScript = preload("res://projectile.gd")

var kind := "bleed"        # definido pelo main antes do add_child
var cost := 0
var damage := 5.0
var color := Color.WHITE
var targets: Array = []
var aim := Vector2.RIGHT

func _ready() -> void:
    var d: Dictionary = DATA[kind]
    cost = d["cost"]; damage = d["dmg"]; color = d["color"]
    add_to_group("towers")
    # Area2D de alcance. Mascara 2 = enxerga apenas inimigos.
    var area := Area2D.new()
    area.collision_layer = 0
    area.collision_mask = 2
    var cs := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = d["range"]
    cs.shape = shape
    area.add_child(cs)
    add_child(area)
    area.area_entered.connect(_on_area_entered)
    area.area_exited.connect(_on_area_exited)
    # Timer de disparo
    var t := Timer.new()
    t.wait_time = 1.0 / d["rate"]
    t.timeout.connect(_fire)
    add_child(t)
    t.start()
    queue_redraw()

func _on_area_entered(area: Area2D) -> void:
    var e := area.get_parent()
    if e.is_in_group("enemies") and not targets.has(e):
        targets.append(e)

func _on_area_exited(area: Area2D) -> void:
    targets.erase(area.get_parent())

func _fire() -> void:
    targets = targets.filter(func(e): return is_instance_valid(e) and not e.dead)
    if targets.is_empty():
        return
    # alvo = inimigo mais adiantado no caminho
    var best = targets[0]
    for e in targets:
        if e.progress > best.progress:
            best = e
    aim = (best.global_position - global_position).normalized()
    var p := ProjectileScript.new()
    p.target = best
    p.kind = kind
    p.damage = damage
    p.color = color
    p.position = global_position
    get_tree().current_scene.add_child(p)
    queue_redraw()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 17.0, Color(0.15, 0.15, 0.15))
    draw_circle(Vector2.ZERO, 13.0, color)
    draw_line(Vector2.ZERO, aim * 22.0, Color.WHITE, 4.0)
