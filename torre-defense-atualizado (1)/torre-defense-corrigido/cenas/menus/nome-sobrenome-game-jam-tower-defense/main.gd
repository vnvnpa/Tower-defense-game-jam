extends Node2D
# Controle do jogo: caminho, ondas, construcao de torres, HUD e fim de jogo.

const EnemyScript = preload("res://enemy.gd")
const TowerScript = preload("res://tower.gd")

const MAX_WAVES := 10
const PATH_WIDTH := 44.0
const PATH_POINTS := [
	Vector2(-30, 120), Vector2(250, 120), Vector2(250, 400), Vector2(550, 400),
	Vector2(550, 180), Vector2(850, 180), Vector2(850, 520), Vector2(1060, 520)]
const ORDER := ["bleed", "burn", "freeze", "poison"]

var path: Path2D
var money := 150
var lives := 20
var wave := 0
var wave_total := 0
var to_spawn := 0
var wave_active := false
var game_over := false
var won := false
var selected := "bleed"
var toast := ""
var toast_t := 0.0

var spawn_timer: Timer
var info_label: Label
var msg_label: Label
var tower_buttons := {}

func _ready() -> void:
	# Caminho dos inimigos (Path2D + Curve2D)
	path = Path2D.new()
	var curve := Curve2D.new()
	for p in PATH_POINTS:
		curve.add_point(p)
	path.curve = curve
	add_child(path)
	# Timer que solta um inimigo por vez durante a onda
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 0.9
	spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(spawn_timer)
	_build_ui()
	select_kind("bleed")

# ---------------- HUD ----------------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var row := HBoxContainer.new()
	row.position = Vector2(10, 8)
	layer.add_child(row)
	for i in ORDER.size():
		var k: String = ORDER[i]
		var d: Dictionary = TowerScript.DATA[k]
		var b := Button.new()
		b.text = "%d %s $%d" % [i + 1, d["name"], d["cost"]]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(select_kind.bind(k))
		row.add_child(b)
		tower_buttons[k] = b
	var start := Button.new()
	start.text = "Iniciar Onda (Espaco)"
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(start_wave)
	row.add_child(start)

	info_label = Label.new()
	info_label.position = Vector2(10, 596)
	layer.add_child(info_label)

	msg_label = Label.new()
	msg_label.position = Vector2(0, 56)
	msg_label.size = Vector2(1152, 40)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 22)
	msg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	msg_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(msg_label)

func select_kind(k: String) -> void:
	selected = k
	for kk in tower_buttons:
		tower_buttons[kk].set_pressed_no_signal(kk == selected)

func show_toast(text: String) -> void:
	toast = text
	toast_t = 1.5

# ---------------- Ondas ----------------
func start_wave() -> void:
	if wave_active or game_over:
		return
	wave += 1
	wave_total = 6 + wave * 3
	to_spawn = wave_total
	wave_active = true
	spawn_timer.start()

func _on_spawn_timer() -> void:
	if to_spawn <= 0:
		spawn_timer.stop()
		return
	var idx := wave_total - to_spawn
	var k := "normal"
	if wave >= 2 and idx % 4 == 3: k = "fast"
	if wave >= 3 and idx % 6 == 5: k = "tank"
	to_spawn -= 1
	var e := EnemyScript.new()
	e.setup(k, wave)
	e.reached_base.connect(_on_reached_base)
	e.died.connect(_on_enemy_died)
	path.add_child(e)

func _on_enemy_died(reward: int) -> void:
	money += reward

func _on_reached_base(damage: int) -> void:
	lives -= damage
	if lives <= 0 and not game_over:
		lives = 0
		game_over = true
		wave_active = false
		spawn_timer.stop()

func _check_wave_end() -> void:
	if wave_active and to_spawn <= 0 and get_tree().get_nodes_in_group("enemies").is_empty():
		wave_active = false
		if wave >= MAX_WAVES:
			won = true
			game_over = true
		else:
			var bonus := 40 + wave * 5
			money += bonus
			show_toast("Onda %d concluida! Bonus: $%d" % [wave, bonus])

# ---------------- Construcao ----------------
func can_place(pos: Vector2) -> bool:
	if pos.y < 60 or pos.y > 570 or pos.x < 20 or pos.x > 1132:
		return false
	var closest: Vector2 = path.curve.get_closest_point(pos)
	if closest.distance_to(pos) < PATH_WIDTH / 2.0 + 18.0:
		return false
	for t in get_tree().get_nodes_in_group("towers"):
		if t.position.distance_to(pos) < 40.0:
			return false
	return true

func try_build(pos: Vector2) -> void:
	var cost: int = TowerScript.DATA[selected]["cost"]
	if money < cost:
		show_toast("Dinheiro insuficiente!")
		return
	if not can_place(pos):
		return
	money -= cost
	var t := TowerScript.new()
	t.kind = selected
	t.position = pos
	add_child(t)

func try_sell(pos: Vector2) -> void:
	for t in get_tree().get_nodes_in_group("towers"):
		if t.position.distance_to(pos) < 20.0:
			money += int(t.cost * 0.6)
			t.queue_free()
			show_toast("Torre vendida (60%)")
			return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: select_kind("bleed")
			KEY_2: select_kind("burn")
			KEY_3: select_kind("freeze")
			KEY_4: select_kind("poison")
			KEY_SPACE: start_wave()
			KEY_R: get_tree().reload_current_scene()
	elif event is InputEventMouseButton and event.pressed and not game_over:
		var pos := get_global_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			try_build(pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			try_sell(pos)

# ---------------- Loop / desenho ----------------
func _process(delta: float) -> void:
	_check_wave_end()
	toast_t -= delta
	var d: Dictionary = TowerScript.DATA[selected]
	info_label.text = "Dinheiro: $%d   |   Vidas da Base: %d   |   Onda: %d/%d\n%s: %s   [Clique esq.: construir | Clique dir.: vender | R: reiniciar]" % [
		money, lives, wave, MAX_WAVES, d["name"], d["desc"]]
	if game_over:
		msg_label.text = "VITORIA! Base defendida! (R para jogar de novo)" if won else "DERROTA! A base caiu. (R para tentar de novo)"
	elif toast_t > 0.0:
		msg_label.text = toast
	elif not wave_active:
		msg_label.text = "Posicione suas torres e aperte ESPACO para iniciar a Onda %d" % (wave + 1)
	else:
		msg_label.text = ""
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.16, 0.35, 0.2))
	var road := Color(0.55, 0.42, 0.28)
	draw_polyline(PackedVector2Array(PATH_POINTS), road, PATH_WIDTH)
	for p in PATH_POINTS:
		draw_circle(p, PATH_WIDTH / 2.0, road)
	# Base do jogador (fim do caminho)
	var b: Vector2 = PATH_POINTS[PATH_POINTS.size() - 1]
	draw_rect(Rect2(b.x - 26, b.y - 26, 52, 52), Color(0.2, 0.4, 0.9))
	draw_rect(Rect2(b.x - 26, b.y - 26, 52, 52), Color.WHITE, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(b.x - 26, b.y + 5), "BASE", HORIZONTAL_ALIGNMENT_CENTER, 52, 14)
	# Previa da torre sob o mouse
	if not game_over:
		var m := get_global_mouse_position()
		if m.y > 60:
			var ok: bool = can_place(m) and money >= TowerScript.DATA[selected]["cost"]
			var d: Dictionary = TowerScript.DATA[selected]
			draw_arc(m, d["range"], 0, TAU, 48, Color(1, 1, 1, 0.5) if ok else Color(1, 0, 0, 0.5), 2.0)
			draw_circle(m, 16.0, Color(d["color"], 0.6) if ok else Color(1, 0, 0, 0.6))
