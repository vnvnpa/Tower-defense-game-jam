extends PathFollow2D
# Inimigo: segue o Path2D, tem barra de vida e reage aos efeitos DOT
# (Bleed, Burn, Poison) e ao Freeze (lentidao).

signal reached_base(damage: int)   # chegou ao fim do caminho
signal died(reward: int)           # morreu (da dinheiro ao jogador)

const TICK := 0.5                  # intervalo do Timer que aplica o DOT
const DOT_DPS := {"bleed": 8.0, "burn": 12.0, "poison": 6.0}
const DURATION := {"bleed": 4.0, "burn": 3.0, "poison": 5.0, "freeze": 2.0}
const EFFECT_COLORS := {
    "bleed": Color(0.9, 0.1, 0.1), "burn": Color(1.0, 0.55, 0.0),
    "poison": Color(0.3, 0.9, 0.2), "freeze": Color(0.4, 0.9, 1.0)}
const FREEZE_SLOW := 0.4           # multiplicador de velocidade congelado
const POISON_VULN := 1.3           # veneno reduz a defesa: +30% de dano recebido
const BURN_SPREAD_RANGE := 60.0    # raio em que o fogo se espalha

var kind := "normal"
var max_hp := 45.0
var hp := 45.0
var base_speed := 70.0
var base_armor := 0.0
var reward := 10
var base_damage := 1
var radius := 12.0
var color := Color(0.9, 0.85, 0.3)
var effects := {}                  # nome do efeito -> tempo restante
var dead := false

func setup(k: String, wave: int) -> void:
    kind = k
    var scale_hp := 1.0 + 0.3 * (wave - 1)
    match k:
        "fast":
            max_hp = 30.0; base_speed = 115.0; reward = 8
            radius = 9.0; color = Color(0.95, 0.5, 0.8)
        "tank":
            max_hp = 130.0; base_speed = 45.0; base_armor = 0.25; reward = 25
            radius = 16.0; color = Color(0.5, 0.5, 0.6); base_damage = 3
        _:
            max_hp = 45.0; base_speed = 70.0; reward = 10
    max_hp *= scale_hp
    hp = max_hp

func _ready() -> void:
    loop = false
    rotates = false
    add_to_group("enemies")
    # Hitbox (Area2D) que a torre detecta. Layer 2 = inimigos.
    var hitbox := Area2D.new()
    hitbox.collision_layer = 2
    hitbox.collision_mask = 0
    var cs := CollisionShape2D.new()
    var shape := CircleShape2D.new()
    shape.radius = radius
    cs.shape = shape
    hitbox.add_child(cs)
    add_child(hitbox)
    # Timer que aplica o dano ao longo do tempo
    var t := Timer.new()
    t.wait_time = TICK
    t.timeout.connect(_on_tick)
    add_child(t)
    t.start()

func _process(delta: float) -> void:
    if dead:
        return
    for e in effects.keys():
        effects[e] -= delta
        if effects[e] <= 0.0:
            effects.erase(e)
    var mult := FREEZE_SLOW if effects.has("freeze") else 1.0
    progress += base_speed * mult * delta
    if progress_ratio >= 0.999:
        dead = true
        reached_base.emit(base_damage)
        queue_free()
        return
    queue_redraw()

func _on_tick() -> void:
    if dead:
        return
    var dmg := 0.0
    for e in DOT_DPS:
        if effects.has(e):
            dmg += DOT_DPS[e] * TICK
    if dmg > 0.0:
        hurt(dmg)
    # Burn: inimigo em chamas incendeia vizinhos
    if effects.has("burn"):
        for other in get_tree().get_nodes_in_group("enemies"):
            if other != self and not other.dead and not other.effects.has("burn"):
                if global_position.distance_to(other.global_position) < BURN_SPREAD_RANGE and randf() < 0.35:
                    other.apply_effect("burn")

func apply_effect(name: String) -> void:
    if DURATION.has(name):
        effects[name] = DURATION[name]   # reaplicar renova a duracao

# Dano direto (projetil): considera armadura e vulnerabilidade do veneno
func take_damage(amount: float) -> void:
    var mult := 1.0 - base_armor
    if effects.has("poison"):
        mult *= POISON_VULN
    hurt(amount * mult)

func hurt(amount: float) -> void:
    if dead:
        return
    hp -= amount
    if hp <= 0.0:
        dead = true
        died.emit(reward)
        queue_free()

func _draw() -> void:
    var c := color
    if effects.has("freeze"): c = c.lerp(EFFECT_COLORS["freeze"], 0.6)
    if effects.has("burn"): c = c.lerp(EFFECT_COLORS["burn"], 0.5)
    draw_circle(Vector2.ZERO, radius, c)
    draw_arc(Vector2.ZERO, radius, 0, TAU, 20, Color.BLACK, 2.0)
    # barra de vida
    var w := 30.0
    draw_rect(Rect2(-w / 2, -radius - 10, w, 5), Color(0.25, 0, 0))
    draw_rect(Rect2(-w / 2, -radius - 10, w * clampf(hp / max_hp, 0, 1), 5), Color(0.2, 0.9, 0.2))
    # bolinhas dos status ativos
    var x := -w / 2
    for e in effects:
        draw_circle(Vector2(x + 3, radius + 8), 3.5, EFFECT_COLORS[e])
        x += 9
